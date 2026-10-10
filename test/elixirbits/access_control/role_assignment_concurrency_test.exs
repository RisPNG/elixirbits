defmodule Elixirbits.AccessControl.RoleAssignmentConcurrencyTest do
  use ExUnit.Case, async: false

  import ElixirbitsWeb.ConnCase, only: [create_user: 1]

  alias Ecto.Adapters.SQL.Sandbox
  alias Elixirbits.AccessControl.Role
  alias Elixirbits.Accounts.User

  setup do
    assert String.starts_with?(Elixirbits.Repo.config()[:database], "elixirbits_template_test")

    on_exit(fn ->
      Sandbox.unboxed_run(Elixirbits.Repo, fn ->
        Elixirbits.Events.ClearAllRecords.clear_records!([])
      end)
    end)

    Sandbox.unboxed_run(Elixirbits.Repo, fn ->
      user = create_user(roles: [])
      code = "concurrent-#{System.unique_integer([:positive])}"
      role = Ash.create!(Role, %{code: code, name: "Concurrent role"}, actor: %{system: true})
      %{user: user, role: role}
    end)
  end

  test "an assignment that locks first prevents the assigned role from being deleted", context do
    parent = self()

    assignment =
      Task.async(fn ->
        Sandbox.unboxed_run(Elixirbits.Repo, fn ->
          context.user
          |> Ash.Changeset.for_update(:assign_roles, %{roles: [context.role.code]},
            actor: %{system: true}
          )
          |> Ash.Changeset.after_action(fn _changeset, user ->
            send(parent, :assignment_saved)

            receive do
              :commit_assignment -> {:ok, user}
            after
              5_000 -> flunk("assignment was not released")
            end
          end)
          |> Ash.update()
        end)
      end)

    assert_receive :assignment_saved, 5_000

    deletion =
      Task.async(fn ->
        Sandbox.unboxed_run(Elixirbits.Repo, fn ->
          send(parent, :deletion_started)
          result = Ash.destroy(context.role, actor: %{system: true})
          send(parent, {:deletion_finished, result})
          result
        end)
      end)

    assert_receive :deletion_started
    refute_receive {:deletion_finished, _}, 100
    send(assignment.pid, :commit_assignment)

    assert {:ok, assigned} = Task.await(assignment)
    assert assigned.roles == [context.role.code]
    assert {:error, %Ash.Error.Invalid{}} = Task.await(deletion)

    Sandbox.unboxed_run(Elixirbits.Repo, fn ->
      assert Ash.get!(Role, context.role.id, actor: %{system: true})
      assert Ash.get!(User, context.user.id, actor: %{system: true}).roles == [context.role.code]
    end)
  end

  test "a deletion that locks first rejects a later assignment of the deleted role", context do
    parent = self()

    deletion =
      Task.async(fn ->
        Sandbox.unboxed_run(Elixirbits.Repo, fn ->
          context.role
          |> Ash.Changeset.for_destroy(:destroy, %{}, actor: %{system: true})
          |> Ash.Changeset.before_action(fn changeset ->
            send(parent, :deletion_locked)

            receive do
              :commit_deletion -> changeset
            after
              5_000 -> flunk("deletion was not released")
            end
          end)
          |> Ash.destroy()
        end)
      end)

    assert_receive :deletion_locked, 5_000

    assignment =
      Task.async(fn ->
        Sandbox.unboxed_run(Elixirbits.Repo, fn ->
          send(parent, :assignment_started)

          result =
            Ash.update(context.user, %{roles: [context.role.code]},
              action: :assign_roles,
              actor: %{system: true}
            )

          send(parent, {:assignment_finished, result})
          result
        end)
      end)

    assert_receive :assignment_started
    refute_receive {:assignment_finished, _}, 100
    send(deletion.pid, :commit_deletion)

    assert :ok = Task.await(deletion)
    assert {:error, %Ash.Error.Invalid{}} = Task.await(assignment)

    Sandbox.unboxed_run(Elixirbits.Repo, fn ->
      assert {:error, %Ash.Error.Invalid{}} =
               Ash.get(Role, context.role.id, actor: %{system: true})

      assert Ash.get!(User, context.user.id, actor: %{system: true}).roles == []
    end)
  end
end

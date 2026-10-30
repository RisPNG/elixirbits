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

    Sandbox.unboxed_run(Elixirbits.Repo, fn ->
      Ash.update!(context.user, %{roles: [context.role.code]},
        action: :assign_roles,
        actor: %{system: true}
      )
    end)

    deletion =
      Task.async(fn ->
        Sandbox.unboxed_run(Elixirbits.Repo, fn ->
          context.role
          |> Ash.Changeset.for_destroy(:destroy, %{remove_assignments?: true},
            actor: %{system: true}
          )
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

  test "confirmed deletion removes an assignment that commits while deletion waits", context do
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

          result =
            context.role
            |> Ash.Changeset.for_destroy(:destroy, %{remove_assignments?: true},
              actor: %{system: true}
            )
            |> Ash.destroy()

          send(parent, {:deletion_finished, result})
          result
        end)
      end)

    assert_receive :deletion_started
    refute_receive {:deletion_finished, _}, 100
    send(assignment.pid, :commit_assignment)

    assert {:ok, assigned} = Task.await(assignment)
    assert assigned.roles == [context.role.code]
    assert :ok = Task.await(deletion)

    Sandbox.unboxed_run(Elixirbits.Repo, fn ->
      assert Ash.get!(Role, context.role.id, actor: %{system: true}, not_found_error?: false) ==
               nil

      assert Ash.get!(User, context.user.id, actor: %{system: true}).roles == []
    end)
  end

  test "concurrent confirmed role deletions preserve other memberships on a shared account",
       context do
    parent = self()

    other_role =
      Sandbox.unboxed_run(Elixirbits.Repo, fn ->
        other_role =
          Ash.create!(
            Role,
            %{code: "other-#{System.unique_integer([:positive])}", name: "Other role"},
            actor: %{system: true}
          )

        Ash.create!(Role, %{code: "retained", name: "Retained role"}, actor: %{system: true})

        Ash.update!(context.user, %{roles: [context.role.code, other_role.code, "retained"]},
          action: :assign_roles,
          actor: %{system: true}
        )

        other_role
      end)

    deletions =
      for role <- [context.role, other_role] do
        Task.async(fn ->
          Sandbox.unboxed_run(Elixirbits.Repo, fn ->
            role
            |> Ash.Changeset.for_destroy(:destroy, %{remove_assignments?: true},
              actor: %{system: true}
            )
            |> Ash.Changeset.before_action(fn changeset ->
              send(parent, {:deletion_locked, role.id})

              receive do
                :commit_deletion -> changeset
              after
                5_000 -> flunk("deletion was not released")
              end
            end)
            |> Ash.destroy()
          end)
        end)
      end

    for role <- [context.role, other_role] do
      role_id = role.id
      assert_receive {:deletion_locked, ^role_id}, 5_000
    end

    Enum.each(deletions, &send(&1.pid, :commit_deletion))
    Enum.each(deletions, fn deletion -> assert :ok = Task.await(deletion) end)

    Sandbox.unboxed_run(Elixirbits.Repo, fn ->
      assert Ash.get!(User, context.user.id, actor: %{system: true}).roles == ["retained"]

      for role <- [context.role, other_role] do
        assert Ash.get!(Role, role.id, actor: %{system: true}, not_found_error?: false) == nil
      end
    end)
  end
end

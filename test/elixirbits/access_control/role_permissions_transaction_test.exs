defmodule Elixirbits.AccessControl.RolePermissionsTransactionTest do
  use ExUnit.Case, async: false

  import ElixirbitsWeb.ConnCase, only: [create_user: 1]
  require Ash.Query

  alias Ecto.Adapters.SQL.Sandbox
  alias Elixirbits.AccessControl.Role
  alias Elixirbits.AccessControl.RolePerm
  alias Elixirbits.AccessControl.Sitenav

  setup do
    assert String.starts_with?(Elixirbits.Repo.config()[:database], "elixirbits_template_test")

    on_exit(fn ->
      Sandbox.unboxed_run(Elixirbits.Repo, fn ->
        Elixirbits.Events.ClearAllRecords.clear_records!([])
      end)
    end)

    admin =
      Sandbox.unboxed_run(Elixirbits.Repo, fn ->
        for {code, url} <- [{"ROLES", "admin/roles"}, {"USERS", "admin/users"}] do
          Ash.create!(Sitenav, %{code: code, name: code, url: url, level: 1},
            actor: %{system: true}
          )
        end

        user = create_user(roles: ["admin"])

        Ash.create!(RolePerm, %{roles_code: "admin", sitenav_code: "ROLES", level: 16},
          actor: %{system: true}
        )

        user
      end)

    %{actor: admin}
  end

  test "SU role and grant creation roll back together when any page is invalid", %{actor: actor} do
    Sandbox.unboxed_run(Elixirbits.Repo, fn ->
      assert {:error, _} =
               Ash.create(
                 Role,
                 %{
                   code: "atomic",
                   name: "Atomic",
                   permissions: [
                     %{sitenav_code: "USERS", level: 4},
                     %{sitenav_code: "missing", level: 4}
                   ]
                 },
                 actor: actor
               )

      refute Role |> Ash.Query.filter(code == "atomic") |> Ash.exists?(actor: %{system: true})

      refute RolePerm
             |> Ash.Query.filter(roles_code == "atomic")
             |> Ash.exists?(actor: %{system: true})
    end)
  end

  test "SU role updates match grants by identity and roll back every change on failure", %{
    actor: actor
  } do
    Sandbox.unboxed_run(Elixirbits.Repo, fn ->
      role =
        Ash.create!(
          Role,
          %{code: "atomic", name: "Original", permissions: [%{sitenav_code: "USERS", level: 4}]},
          actor: actor
        )

      assert {:error, _} =
               Ash.update(
                 role,
                 %{
                   name: "Changed",
                   permissions: [
                     %{sitenav_code: "USERS", level: 15},
                     %{sitenav_code: "missing", level: 4}
                   ]
                 },
                 actor: actor
               )

      saved = Ash.get!(Role, role.id, actor: %{system: true}, load: [:role_perms])
      assert saved.name == "Original"
      assert Enum.map(saved.role_perms, & &1.level) == [4]

      updated =
        Ash.update!(saved, %{permissions: [%{sitenav_code: "USERS", level: 15}]},
          actor: actor,
          load: [:role_perms]
        )

      assert Enum.map(updated.role_perms, & &1.level) == [15]

      assert {:error, %Ash.Error.Invalid{}} =
               Ash.update(updated, %{code: "renamed"}, actor: actor)
    end)
  end
end

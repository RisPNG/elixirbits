defmodule Elixirbits.AccessControl.InitialSchemaTest do
  use Elixirbits.DataCase, async: true

  require Ash.Query

  alias Elixirbits.AccessControl.Role
  alias Elixirbits.AccessControl.RolePerm
  alias Elixirbits.AccessControl.Sitenav
  alias Elixirbits.Events.Event

  test "the template has exactly one initial migration" do
    migrations = Path.wildcard(Path.expand("../../../priv/repo/migrations/*.exs", __DIR__))
    assert [migration] = migrations
    assert Path.basename(migration) =~ ~r/\A\d{14}_initial_schema\.exs\z/
  end

  test "current permission levels retain their values in grants, versions, and replay inputs" do
    system = %{system: true}

    page =
      Ash.create!(Sitenav, %{code: "CURRENT", name: "Current", url: "current", level: 1},
        actor: system
      )

    version_resource = AshPaperTrail.Resource.Info.version_resource(RolePerm)

    for level <- [0, 4, 5, 6, 7, 12, 13, 14, 15, 16] do
      role =
        Ash.create!(
          Role,
          %{
            code: "level_#{level}",
            name: "Current level",
            permissions: [%{"sitenav_code" => page.code, "level" => to_string(level)}]
          },
          actor: system,
          load: [:role_perms]
        )

      assert [grant] = role.role_perms
      assert grant.level == level

      versions =
        version_resource
        |> Ash.Query.filter(version_source_id == ^grant.id)
        |> Ash.read!(actor: system)

      assert Enum.any?(versions, &(&1.changes["level"] == level))

      grant_events = Event |> Ash.Query.filter(record_id == ^grant.id) |> Ash.read!(actor: system)
      assert grant_events != []
      assert Enum.all?(grant_events, &(&1.data["level"] in [level, to_string(level)]))

      role_events = Event |> Ash.Query.filter(record_id == ^role.id) |> Ash.read!(actor: system)

      assert Enum.any?(role_events, fn event ->
               case event.data["permissions"] do
                 [%{"level" => input}] -> input in [level, to_string(level)]
                 _ -> false
               end
             end)
    end
  end
end

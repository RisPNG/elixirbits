# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Elixirbits.Repo.insert!(%Elixirbits.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias Elixirbits.AccessControl
alias Elixirbits.AccessControl.Sitenav

import Ash.Query

[
  %{
    code: "DP",
    name: "Developer-Admin Panel Homepage",
    description: "Lists other dev-admin pages.",
    level: 1,
    parent: nil,
    url: "dev_panel",
    sequence: 1000,
    state: :ENABLED,
    roles_bypass: [],
    users_bypass: []
  },
  %{
    code: "DUM",
    name: "Developer-Admin User Management Page",
    description: "Lists all of the users unrestricted.",
    level: 2,
    parent: "DP",
    url: "dev_panel/users",
    sequence: 2000,
    state: :ENABLED,
    roles_bypass: [],
    users_bypass: []
  },
  %{
    code: "LT",
    name: "Layout Test",
    description: "Showcases most, if not all front-end components.",
    level: 2,
    parent: "DP",
    url: "dev_panel/layout_test",
    sequence: 3000,
    state: :ENABLED,
    roles_bypass: [],
    users_bypass: []
  }
]
|> Enum.each(fn attrs ->
  code = Map.fetch!(attrs, :code)

  sitenav =
    Sitenav
    |> filter(code == ^code)
    |> Ash.read_one!(domain: AccessControl)

  sitenav =
    if sitenav do
      sitenav
      |> Ash.Changeset.for_update(:update, Map.delete(attrs, :state))
      |> Ash.update!(domain: AccessControl)
    else
      Sitenav
      |> Ash.Changeset.for_create(:create, attrs)
      |> Ash.create!(domain: AccessControl)
    end

  if Map.fetch!(attrs, :state) == :ENABLED and sitenav.state != :ENABLED do
    sitenav
    |> Ash.Changeset.for_update(:enable, %{})
    |> Ash.update!(domain: AccessControl)
  end

  if Map.fetch!(attrs, :state) == :DISABLED and sitenav.state != :DISABLED do
    sitenav
    |> Ash.Changeset.for_update(:disable, %{})
    |> Ash.update!(domain: AccessControl)
  end
end)

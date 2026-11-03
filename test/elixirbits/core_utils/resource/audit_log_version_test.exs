defmodule Elixirbits.CoreUtils.Resource.AuditLogVersionTest do
  use Elixirbits.DataCase, async: false

  import ElixirbitsWeb.ConnCase, only: [create_user: 1]
  require Ash.Query

  alias Elixirbits.AccessControl.Role
  alias Elixirbits.AccessControl.RolePerm
  alias Elixirbits.AccessControl.Sitenav
  alias Elixirbits.Accounts.User
  alias Elixirbits.Address
  alias Elixirbits.Organizations.OrganizationService
  alias Elixirbits.Organizations.Organization

  @system %{system: true}

  setup do
    for {code, url} <- [
          {"ROLES", "admin/roles"},
          {"USERS", "admin/users"},
          {"ORG", "admin/organization"}
        ] do
      Ash.create!(Sitenav, %{code: code, name: code, url: url, level: 1}, actor: @system)
    end

    :ok
  end

  test "versions preserve complete fields and the author's name at the time of the save" do
    author = create_user(roles: ["superuser"], display_name: "Original author")

    role =
      Ash.create!(Role, %{code: "audited", name: "Original", description: "Keep this"},
        actor: author
      )

    role = Ash.update!(role, %{name: "Updated"}, actor: author)

    version =
      Role.Version
      |> Ash.Query.filter(version_source_id == ^role.id and version_action_type == :update)
      |> Ash.read_one!(actor: author)

    assert version.changes["name"] == "Updated"
    assert version.changes["code"] == "audited"
    assert version.changes["description"] == "Keep this"
    assert version.actor_id == author.id
    assert version.actor_name == "Original author"
    assert version.operation_id

    Ash.update!(author, %{display_name: "Renamed author"}, actor: @system)
    assert Ash.get!(Role.Version, version.id, actor: author).actor_name == "Original author"
  end

  test "a single save groups parent and address versions, including address-only saves" do
    author = create_user(roles: ["superuser"])

    organization =
      OrganizationService.create_organization!(
        %{name: "Company", addresses: [%{line_1: "First office"}]},
        actor: author
      )
      |> Ash.load!(:addresses, actor: author)

    [address] = organization.addresses

    initial =
      Organization.Version
      |> Ash.Query.filter(version_source_id == ^organization.id)
      |> Ash.read_one!(actor: author)

    address_version =
      Address.Version
      |> Ash.Query.filter(version_source_id == ^address.id)
      |> Ash.read_one!(actor: author)

    assert initial.operation_id == address_version.operation_id
    assert address_version.organization_id == organization.id
    assert address_version.actor_id == author.id

    OrganizationService.update_organization!(
      organization,
      %{addresses: [%{id: address.id, line_1: "New office"}]},
      actor: author
    )

    saved =
      Organization.Version
      |> Ash.Query.filter(
        version_source_id == ^organization.id and version_action_type == :update
      )
      |> Ash.read_one!(actor: author)

    changed_address =
      Address.Version
      |> Ash.Query.filter(version_source_id == ^address.id and version_action_type == :update)
      |> Ash.read_one!(actor: author)

    assert saved.operation_id == changed_address.operation_id
    assert saved.operation_id != initial.operation_id
    assert saved.changes["name"] == "Company"
    assert changed_address.changes["line_1"] == "New office"
  end

  test "role permission changes belong to the same save as their role" do
    author = create_user(roles: ["superuser"])

    role =
      Ash.create!(
        Role,
        %{
          code: "audited-grants",
          name: "Staff",
          permissions: [%{sitenav_code: "USERS", level: 4}]
        },
        actor: author
      )

    parent =
      Role.Version
      |> Ash.Query.filter(version_source_id == ^role.id)
      |> Ash.read_one!(actor: author)

    child =
      RolePerm.Version
      |> Ash.Query.filter(roles_code == ^role.code)
      |> Ash.read_one!(actor: author)

    assert child.operation_id == parent.operation_id
    assert child.roles_code == role.code
    assert child.sitenav_code == "USERS"
    assert child.changes["level"] == 4
  end

  test "reading records does not grant access to their history" do
    reader = actor(%{"USERS" => 4, "ROLES" => 4, "ORG" => 4})
    user = create_user(roles: [])
    role = Ash.create!(Role, %{code: "private-history", name: "Private history"}, actor: @system)

    organization =
      OrganizationService.create_organization!(%{name: "Private settings"}, actor: @system)

    navigation = Ash.get!(Sitenav, %{code: "ROLES"}, actor: @system)

    for {resource, id, version_resource} <- [
          {User, user.id, User.Version},
          {Role, role.id, Role.Version},
          {Organization, organization.id, Organization.Version},
          {Sitenav, navigation.id, Sitenav.Version}
        ] do
      assert Ash.get!(resource, id, actor: reader)
      assert {:ok, []} = Ash.read(version_resource, actor: reader)
    end
  end

  test "address history follows its owner page, including after the address is deleted" do
    users_editor = actor(%{"USERS" => 5})
    organization_editor = actor(%{"ORG" => 5})
    both_editor = actor(%{"USERS" => 5, "ORG" => 5})

    user =
      create_user(roles: [], addresses: [%{line_1: "Private home"}])
      |> Ash.load!(:addresses, actor: @system)

    organization =
      OrganizationService.create_organization!(
        %{name: "Company", addresses: [%{line_1: "Private office"}]},
        actor: @system
      )

    Ash.update!(user, %{addresses: []}, actor: @system)

    user_versions = Ash.read!(Address.Version, actor: users_editor)
    assert length(user_versions) == 2
    assert Enum.all?(user_versions, &(&1.user_id == user.id and is_nil(&1.organization_id)))
    assert Enum.any?(user_versions, &(&1.version_action_type == :destroy))

    assert [organization_version] = Ash.read!(Address.Version, actor: organization_editor)
    assert organization_version.organization_id == organization.id
    assert is_nil(organization_version.user_id)

    assert length(Ash.read!(Address.Version, actor: both_editor)) == 3
  end

  test "audit versions cannot be created directly or updated, including by system actors" do
    author = create_user(roles: ["superuser"])
    role = Ash.create!(Role, %{code: "append-only", name: "Original"}, actor: author)

    version =
      Role.Version
      |> Ash.Query.filter(version_source_id == ^role.id)
      |> Ash.read_one!(actor: author)

    for actor <- [author, @system] do
      assert {:error, %Ash.Error.Forbidden{}} =
               Ash.update(version, %{changes: %{"name" => "Forged"}}, actor: actor)

      assert {:error, %Ash.Error.Forbidden{}} =
               Ash.create(
                 Role.Version,
                 %{
                   version_source_id: role.id,
                   version_action_type: :update,
                   version_action_name: :update,
                   changes: %{"name" => "Forged"}
                 },
                 actor: actor
               )
    end

    assert Ash.get!(Role.Version, version.id, actor: author).changes["name"] == "Original"
  end

  test "restoration metadata reaches parent and child versions" do
    author = create_user(roles: ["superuser"])

    organization =
      OrganizationService.create_organization!(
        %{name: "Company", addresses: [%{line_1: "Office"}]},
        actor: author
      )
      |> Ash.load!(:addresses, actor: author)

    [address] = organization.addresses

    initial =
      Organization.Version
      |> Ash.Query.filter(version_source_id == ^organization.id)
      |> Ash.read_one!(actor: author)

    OrganizationService.update_organization!(
      organization,
      %{addresses: [%{id: address.id, line_1: "Restored office"}]},
      actor: author,
      context: %{shared: %{paper_trail_metadata: %{restored_from_version_id: initial.id}}}
    )

    for {resource, id} <- [{Organization.Version, organization.id}, {Address.Version, address.id}] do
      restored =
        resource
        |> Ash.Query.filter(version_source_id == ^id and version_action_type == :update)
        |> Ash.read_one!(actor: author)

      assert restored.restored_from_version_id == initial.id
    end
  end

  defp actor(levels) do
    code = "audit-editor-#{System.unique_integer([:positive])}"
    user = create_user(roles: [code])

    for {page, level} <- levels do
      Ash.create!(RolePerm, %{roles_code: code, sitenav_code: page, level: level}, actor: @system)
    end

    user
  end
end

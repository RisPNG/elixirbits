defmodule Elixirbits.AccessControl.ResourcePolicyTest do
  use Elixirbits.DataCase, async: false

  import ElixirbitsWeb.ConnCase, only: [create_user: 1]
  require Ash.Query

  alias Elixirbits.AccessControl.Role
  alias Elixirbits.AccessControl.RolePerm
  alias Elixirbits.AccessControl.Sitenav
  alias Elixirbits.Accounts
  alias Elixirbits.Accounts.User
  alias Elixirbits.Address
  alias Elixirbits.Organizations.Organization

  setup do
    for {code, url} <- [
          {"ROLES", "admin/roles"},
          {"USERS", "admin/users"},
          {"ORG", "admin/organization"}
        ] do
      Ash.create!(Sitenav, %{code: code, name: code, url: url, level: 1}, actor: %{system: true})
    end

    :ok
  end

  defp actor(levels) do
    role = "actor-#{System.unique_integer([:positive])}"
    user = create_user(roles: [role])

    for {code, level} <- levels do
      Ash.create!(RolePerm, %{roles_code: role, sitenav_code: code, level: level},
        actor: %{system: true}
      )
    end

    user
  end

  test "direct resource CRUD requires independent create, update, and delete flags" do
    assert {:error, %Ash.Error.Forbidden{}} = Ash.read(Role, actor: actor(%{"ROLES" => 0}))
    assert {:ok, _} = Ash.read(Role, actor: actor(%{"ROLES" => 4}))

    for {level, create?, update?, delete?} <- [
          {4, false, false, false},
          {5, false, true, false},
          {6, true, false, false},
          {12, false, false, true},
          {15, true, true, true},
          {16, true, true, true}
        ] do
      user = actor(%{"ROLES" => level})
      role = Ash.create!(Role, %{code: "target-#{level}", name: "Target"}, actor: %{system: true})

      assert {:ok, _} = Ash.read(Role, actor: user)

      case Ash.create(Role, %{code: "created-#{level}", name: "Created"}, actor: user) do
        {:ok, _created} -> assert create?
        {:error, %Ash.Error.Forbidden{}} -> refute create?
      end

      case Ash.update(role, %{name: "Updated"}, actor: user) do
        {:ok, _updated} -> assert update?
        {:error, %Ash.Error.Forbidden{}} -> refute update?
      end

      case Ash.destroy(role, actor: user) do
        :ok -> assert delete?
        {:error, %Ash.Error.Forbidden{}} -> refute delete?
      end
    end
  end

  test "profile updates cannot change roles and role assignments require SU authority" do
    updater = actor(%{"USERS" => 15, "ROLES" => 15})
    target = create_user(roles: [])
    Ash.create!(Role, %{code: "superuser", name: "Superuser"}, actor: %{system: true})

    assert {:ok, _} =
             Ash.update(target, %{display_name: "Updated"}, action: :update, actor: updater)

    assert {:error, %Ash.Error.Invalid{}} =
             Ash.update(target, %{roles: ["superuser"]}, action: :update, actor: updater)

    assert {:error, %Ash.Error.Forbidden{}} =
             Ash.update(target, %{roles: ["superuser"]}, action: :assign_roles, actor: updater)

    assert Ash.get!(User, target.id, actor: %{system: true}).roles == []

    admin = actor(%{"USERS" => 5, "ROLES" => 16})

    assert {:ok, updated} =
             Ash.update(target, %{roles: ["superuser"]}, action: :assign_roles, actor: admin)

    assert updated.roles == ["superuser"]
  end

  test "nested user addresses require their own create, update, and delete permissions" do
    target =
      create_user(addresses: [%{line_1: "Original home"}])
      |> Ash.load!(:addresses, actor: %{system: true})

    [address] = target.addresses
    updater = actor(%{"USERS" => 5, "ORG" => 16})

    assert [%{id: id}] = Ash.load!(target, :addresses, actor: updater).addresses
    assert id == address.id

    assert {:ok, target} =
             Ash.update(target, %{addresses: [%{id: address.id, line_1: "Updated home"}]},
               actor: updater
             )

    assert Ash.get!(Address, address.id, actor: %{system: true}).line_1 == "Updated home"

    assert {:error, %Ash.Error.Forbidden{}} =
             Ash.update(
               target,
               %{addresses: [%{id: address.id}, %{line_1: "New home"}]},
               actor: updater
             )

    assert {:error, %Ash.Error.Forbidden{}} =
             Ash.update(target, %{addresses: []}, actor: updater)

    creator = actor(%{"USERS" => 7})

    assert {:ok, target} =
             Ash.update(target, %{addresses: [%{id: address.id}, %{line_1: "New home"}]},
               actor: creator
             )

    target = Ash.load!(target, :addresses, actor: creator)
    assert length(target.addresses) == 2

    assert {:error, %Ash.Error.Forbidden{}} =
             Ash.update(target, %{addresses: [%{id: address.id}]}, actor: creator)

    assert {:ok, target} = Ash.update(target, %{addresses: []}, actor: actor(%{"USERS" => 15}))
    assert Ash.load!(target, :addresses, actor: %{system: true}).addresses == []
  end

  test "nested organization addresses cannot borrow user administration permissions" do
    organization =
      Ash.create!(Organization, %{name: "Office", addresses: [%{line_1: "Original office"}]},
        action: :create,
        actor: %{system: true}
      )
      |> Ash.load!(:addresses, actor: %{system: true})

    [address] = organization.addresses
    updater = actor(%{"ORG" => 5, "USERS" => 16})

    assert [%{id: id}] = Ash.load!(organization, :addresses, actor: updater).addresses
    assert id == address.id

    assert {:ok, organization} =
             Ash.update(organization, %{addresses: [%{id: address.id, line_1: "Updated office"}]},
               action: :update,
               actor: updater
             )

    assert Ash.get!(Address, address.id, actor: %{system: true}).line_1 == "Updated office"

    assert {:error, %Ash.Error.Forbidden{}} =
             Ash.update(
               organization,
               %{addresses: [%{id: address.id}, %{line_1: "New office"}]},
               action: :update,
               actor: updater
             )

    assert {:error, %Ash.Error.Forbidden{}} =
             Ash.update(organization, %{addresses: []}, action: :update, actor: updater)

    assert {:ok, organization} =
             Ash.update(organization, %{addresses: [%{id: address.id}, %{line_1: "New office"}]},
               action: :update,
               actor: actor(%{"ORG" => 7})
             )

    assert length(Ash.load!(organization, :addresses, actor: %{system: true}).addresses) == 2

    assert {:ok, organization} =
             Ash.update(organization, %{addresses: []},
               action: :update,
               actor: actor(%{"ORG" => 13})
             )

    assert Ash.load!(organization, :addresses, actor: %{system: true}).addresses == []
  end

  test "organization creation can create nested addresses without update permission" do
    creator = actor(%{"ORG" => 6})

    assert {:ok, organization} =
             Ash.create(Organization, %{name: "Office", addresses: [%{line_1: "New office"}]},
               action: :create,
               actor: creator
             )

    assert [%{line_1: "New office"}] =
             Ash.load!(organization, :addresses, actor: creator).addresses
  end

  test "accounts can save a validated timezone without profile administration" do
    user = create_user(display_name: "Original", dob: ~D[1990-01-01])

    assert {:ok, updated} =
             Accounts.update_user_timezone(user, %{timezone: "America/New_York"}, actor: user)

    assert updated.timezone == "America/New_York"
    assert updated.dob == ~D[1990-01-01]
    assert updated.display_name == user.display_name
    assert updated.roles == user.roles
    assert updated.confirmed_at == user.confirmed_at
    assert updated.inserted_at == user.inserted_at
    assert updated.updated_at.time_zone == "Etc/UTC"

    assert {:error, %Ash.Error.Invalid{}} =
             Ash.update(updated, %{dob: "not-a-date"}, action: :update, actor: %{system: true})

    assert {:error, %Ash.Error.Invalid{}} =
             Accounts.update_user_timezone(updated, %{timezone: "Unknown/Zone"}, actor: updated)

    assert Ash.get!(User, user.id, actor: %{system: true}).timezone == "America/New_York"

    for attrs <- [%{display_name: "Forged"}, %{roles: ["superuser"]}] do
      assert {:error, %Ash.Error.Invalid{}} =
               Accounts.update_user_timezone(updated, attrs, actor: updated)
    end

    assert {:ok, automatic} =
             Accounts.update_user_timezone(updated, %{timezone: nil}, actor: updated)

    assert automatic.timezone == nil
    assert automatic.dob == ~D[1990-01-01]

    id = user.id

    history =
      User
      |> AshPaperTrail.Resource.Info.version_resource()
      |> Ash.Query.filter(version_source_id == ^id and version_action_name == :update_timezone)
      |> Ash.read!(actor: %{system: true})

    assert length(history) == 2
  end

  test "timezone self-service cannot target another account or allow anonymous writes" do
    user = create_user([])
    target = create_user(timezone: "Asia/Kuala_Lumpur")

    for actor <- [nil, user, actor(%{"USERS" => 15})] do
      assert {:error, %Ash.Error.Forbidden{}} =
               Accounts.update_user_timezone(target, %{timezone: "Europe/London"}, actor: actor)
    end

    assert Ash.get!(User, target.id, actor: %{system: true}).timezone == "Asia/Kuala_Lumpur"

    assert {:ok, target} =
             Accounts.update_user_timezone(target, %{timezone: "Europe/London"},
               actor: %{system: true}
             )

    assert target.timezone == "Europe/London"
  end

  test "a stale account snapshot cannot save timezone after archival" do
    user = create_user(timezone: "Europe/London")

    user
    |> Ash.Changeset.for_update(:update, %{}, actor: %{system: true})
    |> Ash.Changeset.force_change_attribute(:archived_at, DateTime.utc_now())
    |> Ash.update!(actor: %{system: true})

    assert is_nil(user.archived_at)

    assert {:error, _error} =
             Accounts.update_user_timezone(user, %{timezone: "America/New_York"}, actor: user)

    assert Ash.get!(User, user.id, actor: %{system: true}, not_found_error?: false) == nil
    id = user.id

    events =
      Elixirbits.Events.Event
      |> Ash.Query.filter(record_id == ^id and action == :update_timezone)
      |> Ash.read!(actor: %{system: true})

    assert events == []
  end

  test "full CRUD grants cannot elevate themselves through nested actions or direct resources" do
    updater = actor(%{"USERS" => 15, "ROLES" => 15})
    code = hd(updater.roles)
    role = Ash.get!(Role, %{code: code}, actor: %{system: true})
    grant = Ash.get!(RolePerm, %{roles_code: code, sitenav_code: "ROLES"}, actor: %{system: true})
    page = Ash.get!(Sitenav, %{code: "ROLES"}, actor: %{system: true})

    assert {:ok, _} = Ash.update(role, %{name: "Metadata update"}, actor: updater)
    assert {:ok, target} = Ash.create(Role, %{code: "metadata", name: "Metadata"}, actor: updater)

    assert {:error, %Ash.Error.Forbidden{}} =
             Ash.update(role, %{permissions: [%{sitenav_code: "ROLES", level: 16}]},
               actor: updater
             )

    assert {:error, %Ash.Error.Forbidden{}} =
             Ash.create(
               Role,
               %{
                 code: "forged",
                 name: "Forged",
                 permissions: [%{sitenav_code: "ROLES", level: 16}]
               },
               actor: updater
             )

    assert {:error, %Ash.Error.Forbidden{}} = Ash.update(grant, %{level: 16}, actor: updater)
    assert {:error, %Ash.Error.Forbidden{}} = Ash.destroy(grant, actor: updater)

    assert {:error, %Ash.Error.Forbidden{}} =
             Ash.create(RolePerm, %{roles_code: target.code, sitenav_code: "ROLES", level: 16},
               actor: updater
             )

    assert {:error, %Ash.Error.Forbidden{}} =
             Ash.update(page, %{roles_bypass: [code]}, actor: updater)

    assert {:error, %Ash.Error.Forbidden{}} =
             Ash.update(page, %{users_bypass: [updater.id]}, actor: updater)

    assert {:error, %Ash.Error.Forbidden{}} =
             Ash.update(page, %{}, action: :disable, actor: updater)

    assert {:error, %Ash.Error.Forbidden{}} =
             Ash.update(page, %{}, action: :enable, actor: updater)

    assert {:error, %Ash.Error.Forbidden{}} = Ash.destroy(page, actor: updater)

    assert {:error, %Ash.Error.Forbidden{}} =
             Ash.create(
               Sitenav,
               %{
                 code: "BYPASS",
                 name: "Bypass",
                 url: "admin/bypass",
                 level: 1,
                 roles_bypass: [code]
               },
               actor: updater
             )

    assert Ash.get!(RolePerm, grant.id, actor: %{system: true}).level == 15
    assert Ash.get!(Sitenav, page.id, actor: %{system: true}).roles_bypass == []
    refute Elixirbits.AccessControl.Permissions.can?(updater, "/admin/roles", :su)
  end

  test "SU authority can atomically administer grants and navigation" do
    admin = actor(%{"ROLES" => 16})

    role =
      Ash.create!(
        Role,
        %{code: "managed", name: "Managed", permissions: [%{sitenav_code: "USERS", level: 4}]},
        actor: admin,
        load: [:role_perms]
      )

    assert Enum.map(role.role_perms, & &1.level) == [4]

    role =
      Ash.update!(role, %{name: "Changed", permissions: [%{sitenav_code: "USERS", level: 15}]},
        actor: admin,
        load: [:role_perms]
      )

    assert Enum.map(role.role_perms, & &1.level) == [15]

    page =
      Ash.create!(Sitenav, %{code: "MANAGED", name: "Managed", url: "managed", level: 1},
        actor: admin
      )

    page = Ash.update!(page, %{roles_bypass: [role.code]}, actor: admin)

    grant =
      Ash.create!(RolePerm, %{roles_code: role.code, sitenav_code: page.code, level: 4},
        actor: admin
      )

    assert {:ok, grant} = Ash.update(grant, %{level: 5}, actor: admin)
    assert :ok = Ash.destroy(grant, actor: admin)
    assert :ok = Ash.destroy(page, actor: admin)
  end

  test "unknown roles are rejected and assigned roles cannot be deleted" do
    target = create_user(roles: ["assigned"])

    assert {:error, %Ash.Error.Invalid{}} =
             Ash.update(target, %{roles: ["missing"]},
               action: :assign_roles,
               actor: %{system: true}
             )

    role = Ash.get!(Role, %{code: "assigned"}, actor: %{system: true})
    assert {:error, %Ash.Error.Invalid{}} = Ash.destroy(role, actor: %{system: true})
  end

  test "hard-deleted access-control records retain creation and deletion history" do
    role = Ash.create!(Role, %{code: "deletable", name: "Deletable"}, actor: %{system: true})

    page =
      Ash.create!(Sitenav, %{code: "DELETABLE", name: "Deletable", url: "deletable", level: 1},
        actor: %{system: true}
      )

    grant =
      Ash.create!(RolePerm, %{roles_code: role.code, sitenav_code: page.code, level: 4},
        actor: %{system: true}
      )

    for {resource, record} <- [{RolePerm, grant}, {Role, role}, {Sitenav, page}] do
      assert :ok = Ash.destroy(record, actor: %{system: true})
      assert Ash.get!(resource, record.id, actor: %{system: true}, not_found_error?: false) == nil
      id = record.id

      history =
        resource
        |> AshPaperTrail.Resource.Info.version_resource()
        |> Ash.Query.filter(version_source_id == ^id)
        |> Ash.read!(actor: %{system: true})

      assert MapSet.new(history, & &1.version_action_type) == MapSet.new([:create, :destroy])
    end
  end

  test "disabled pages deny direct access even to superusers" do
    page = Ash.get!(Sitenav, %{code: "ROLES"}, actor: %{system: true})
    Ash.update!(page, %{}, action: :disable, actor: %{system: true})
    superuser = create_user(roles: ["superuser"])

    assert {:error, %Ash.Error.Forbidden{}} = Ash.read(RolePerm, actor: superuser)

    assert {:error, %Ash.Error.Forbidden{}} =
             Ash.create(Role, %{code: "blocked", name: "Blocked"}, actor: superuser)
  end
end

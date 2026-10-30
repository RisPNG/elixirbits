defmodule Elixirbits.AccessControl.ResourcePolicyTest do
  use Elixirbits.DataCase, async: false

  import ElixirbitsWeb.ConnCase, only: [create_user: 1]
  require Ash.Query

  alias Elixirbits.AccessControl.Permissions
  alias Elixirbits.AccessControl.Role
  alias Elixirbits.AccessControl.RolePerm
  alias Elixirbits.AccessControl.ResourcePolicy
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

  test "missing actors are denied and system actors bypass without loading permissions" do
    handler = "resource-policy-#{System.unique_integer([:positive])}"
    test_pid = self()

    :telemetry.attach(
      handler,
      [:elixirbits, :repo, :query],
      fn _, _, _, _ -> if self() == test_pid, do: send(test_pid, :query) end,
      nil
    )

    on_exit(fn -> :telemetry.detach(handler) end)

    opts = [paths: ["/admin/roles"], capability: :read]

    refute ResourcePolicy.match?(nil, %{}, opts)
    assert ResourcePolicy.match?(%{system: true}, %{}, opts)
    refute_received :query
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

  test "user updates and role assignments require SU authority to change roles" do
    updater = actor(%{"USERS" => 15, "ROLES" => 15})
    target = create_user(roles: [])
    Ash.create!(Role, %{code: "superuser", name: "Superuser"}, actor: %{system: true})

    assert {:ok, _} =
             Ash.update(target, %{display_name: "Updated"}, action: :update, actor: updater)

    assert {:error, %Ash.Error.Forbidden{}} =
             Ash.update(target, %{roles: ["superuser"]}, action: :update, actor: updater)

    assert {:error, %Ash.Error.Forbidden{}} =
             Ash.update(target, %{roles: ["superuser"]}, action: :assign_roles, actor: updater)

    assert Ash.get!(User, target.id, actor: %{system: true}).roles == []

    admin = actor(%{"USERS" => 5, "ROLES" => 16})

    assert {:error, %Ash.Error.Forbidden{}} =
             Ash.update(target, %{roles: ["superuser"]}, action: :assign_roles, actor: admin)

    Ash.create!(Role, %{code: "member", name: "Member"}, actor: %{system: true})

    assert {:ok, updated} =
             Ash.update(target, %{roles: ["member"]}, action: :assign_roles, actor: admin)

    assert updated.roles == ["member"]

    superuser = create_user(roles: ["superuser"])

    assert {:ok, updated} =
             Ash.update(updated, %{roles: ["superuser"]}, action: :update, actor: superuser)

    assert updated.roles == ["superuser"]
  end

  test "profile, address, and role changes succeed or fail together in one user update" do
    updater = actor(%{"USERS" => 15, "ROLES" => 15})
    role_admin = actor(%{"USERS" => 15, "ROLES" => 16})

    target =
      create_user(display_name: "Original profile", addresses: [%{line_1: "Original home"}])
      |> Ash.load!(:addresses, actor: %{system: true})

    [address] = target.addresses
    Ash.create!(Role, %{code: "member", name: "Member"}, actor: %{system: true})
    Ash.create!(Role, %{code: "superuser", name: "Superuser"}, actor: %{system: true})

    attrs = %{
      display_name: "Updated profile",
      addresses: [%{id: address.id, line_1: "Updated home"}, %{line_1: "New office"}]
    }

    for {roles, admin, error_type} <- [
          {["member"], updater, Ash.Error.Forbidden},
          {["superuser"], role_admin, Ash.Error.Forbidden},
          {["missing"], role_admin, Ash.Error.Invalid}
        ] do
      assert {:error, error} =
               Ash.update(target, Map.put(attrs, :roles, roles), action: :update, actor: admin)

      assert is_struct(error, error_type)
      stored = Ash.get!(User, target.id, actor: %{system: true}, load: [:addresses])
      assert stored.display_name == "Original profile"
      assert stored.roles == []
      assert [%{id: address_id, line_1: "Original home"}] = stored.addresses
      assert address_id == address.id
    end

    assert {:ok, updated} =
             Ash.update(target, Map.put(attrs, :roles, ["member"]),
               action: :update,
               actor: role_admin,
               load: [:addresses]
             )

    assert updated.display_name == "Updated profile"
    assert updated.roles == ["member"]
    assert Enum.sort(Enum.map(updated.addresses, & &1.line_1)) == ["New office", "Updated home"]

    assert {:error, %Ash.Error.Forbidden{}} =
             Ash.update(updated, %{display_name: "Forbidden profile", roles: ["member"]},
               action: :update,
               actor: updater
             )

    assert Ash.get!(User, target.id, actor: %{system: true}).display_name == "Updated profile"
  end

  test "revoked global superuser authority cannot be reused through a stale actor" do
    admin = actor(%{"USERS" => 5, "ROLES" => 16})
    normal_roles = admin.roles
    Ash.create!(Role, %{code: "superuser", name: "Superuser"}, actor: %{system: true})

    admin =
      Ash.update!(admin, %{roles: ["superuser" | normal_roles]},
        action: :assign_roles,
        actor: %{system: true}
      )

    assert "superuser" in admin.roles

    Ash.update!(admin, %{roles: normal_roles}, action: :assign_roles, actor: %{system: true})
    assert Permissions.can?(admin, "/admin/roles", :su)

    target = create_user(roles: [])

    for action <- [:update, :assign_roles] do
      assert {:error, %Ash.Error.Forbidden{}} =
               Ash.update(target, %{roles: ["superuser"]}, action: action, actor: admin)
    end

    assert Ash.get!(User, target.id, actor: %{system: true}).roles == []
  end

  test "page SU editors may retain and remove an existing global superuser assignment" do
    admin = actor(%{"USERS" => 5, "ROLES" => 16})
    Ash.create!(Role, %{code: "member", name: "Member"}, actor: %{system: true})

    for action <- [:update, :assign_roles] do
      target = create_user(roles: ["superuser"])

      assert {:ok, target} =
               Ash.update(target, %{roles: ["superuser", "member"]},
                 action: action,
                 actor: admin
               )

      assert target.roles == ["superuser", "member"]

      assert {:ok, target} =
               Ash.update(target, %{roles: ["member"]}, action: action, actor: admin)

      assert target.roles == ["member"]
    end
  end

  test "a stale target cannot restore a global superuser assignment removed from storage" do
    admin = actor(%{"USERS" => 5, "ROLES" => 16})
    target = create_user(roles: [])
    Ash.create!(Role, %{code: "superuser", name: "Superuser"}, actor: %{system: true})

    target =
      Ash.update!(target, %{roles: ["superuser"]},
        action: :assign_roles,
        actor: %{system: true}
      )

    assert target.roles == ["superuser"]
    Ash.update!(target, %{roles: []}, action: :assign_roles, actor: %{system: true})

    for action <- [:update, :assign_roles] do
      assert {:error, %Ash.Error.Forbidden{}} =
               Ash.update(target, %{roles: ["superuser"]}, action: action, actor: admin)
    end

    assert Ash.get!(User, target.id, actor: %{system: true}).roles == []
  end

  test "user creation and deletion require independent capabilities without page SU" do
    for {level, create?, delete?} <- [
          {5, false, false},
          {6, true, false},
          {12, false, true},
          {15, true, true}
        ] do
      admin = actor(%{"USERS" => level})

      attrs = %{
        email: "managed-#{level}@example.com",
        password: "password1234",
        password_confirmation: "password1234",
        display_name: "Managed #{level}",
        first_name: "Managed",
        timezone: "Asia/Singapore"
      }

      case Ash.create(User, attrs, action: :create, actor: admin) do
        {:ok, user} ->
          assert create?
          assert user.display_name == attrs.display_name
          assert user.first_name == attrs.first_name
          assert user.timezone == attrs.timezone
          assert user.roles == []
          assert AshAuthentication.BcryptProvider.valid?(attrs.password, user.hashed_password)
          refute Ash.Resource.get_metadata(user, :token)

        {:error, %Ash.Error.Forbidden{}} ->
          refute create?
      end

      target = create_user(roles: [])

      case Ash.destroy(target, actor: admin) do
        :ok ->
          assert delete?

          assert Ash.get!(User, target.id, actor: %{system: true}, not_found_error?: false) == nil

        {:error, %Ash.Error.Forbidden{}} ->
          refute delete?
          assert Ash.get!(User, target.id, actor: %{system: true})
      end
    end
  end

  test "administrative user creation validates credentials and cannot inject role membership" do
    admin = actor(%{"USERS" => 6})

    attrs = %{
      email: "rejected-create@example.com",
      password: "password1234",
      password_confirmation: "password1234"
    }

    for overrides <- [
          %{roles: ["superuser"]},
          %{password: "short", password_confirmation: "short"},
          %{password_confirmation: "different-password"}
        ] do
      assert {:error, %Ash.Error.Invalid{}} =
               Ash.create(User, Map.merge(attrs, overrides), action: :create, actor: admin)
    end

    assert Ash.get!(User, %{email: attrs.email}, actor: %{system: true}, not_found_error?: false) ==
             nil
  end

  test "archiving a user denies sign-in while retaining its profile, addresses, and audit history" do
    admin = actor(%{"USERS" => 12})

    target =
      Ash.create!(
        User,
        %{
          email: "archived-account@example.com",
          password: "password1234",
          password_confirmation: "password1234"
        },
        action: :seed_with_password,
        actor: %{system: true}
      )
      |> Ash.update!(%{display_name: "Historical account", addresses: [%{line_1: "Saved home"}]},
        action: :update,
        actor: %{system: true},
        load: [:addresses]
      )

    [address] = target.addresses
    id = target.id

    query =
      Ash.Query.for_read(
        User,
        :sign_in_with_password,
        %{email: to_string(target.email), password: "password1234"},
        context: %{private: %{ash_authentication?: true}}
      )

    assert {:ok, signed_in} = Ash.read_one(query)
    assert signed_in.id == id

    assert {:ok, archived} = Ash.destroy(target, actor: admin, return_destroyed?: true)
    assert %DateTime{} = archived.archived_at
    assert archived.display_name == "Historical account"
    assert Ash.get!(User, id, actor: %{system: true}, not_found_error?: false) == nil
    assert {:error, _error} = Ash.read_one(query)

    saved_address = Ash.get!(Address, address.id, actor: %{system: true})
    assert saved_address.user_id == id
    assert saved_address.line_1 == "Saved home"

    history =
      User
      |> AshPaperTrail.Resource.Info.version_resource()
      |> Ash.Query.filter(version_source_id == ^id)
      |> Ash.read!(actor: %{system: true})

    assert Enum.any?(history, &(&1.version_action_name == :seed_with_password))
    assert Enum.any?(history, &(&1.version_action_name == :update))
    assert Enum.any?(history, &(&1.version_action_name == :destroy))

    events =
      Elixirbits.Events.Event
      |> Ash.Query.filter(record_id == ^id and action == :destroy)
      |> Ash.read!(actor: %{system: true})

    assert [_event] = events
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
    Ash.destroy!(user, actor: %{system: true})

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

  test "unknown roles are rejected and assigned role deletion requires confirmation" do
    target = create_user(roles: ["assigned"])

    assert {:error, %Ash.Error.Invalid{}} =
             Ash.update(target, %{roles: ["missing"]},
               action: :assign_roles,
               actor: %{system: true}
             )

    role = Ash.get!(Role, %{code: "assigned"}, actor: %{system: true})

    assert {:error, %Ash.Error.Invalid{errors: errors}} =
             Ash.destroy(role, actor: %{system: true})

    assert Enum.any?(errors, fn error ->
             match?(%Ash.Error.Changes.InvalidArgument{field: :remove_assignments?}, error)
           end)

    assert Ash.get!(Role, role.id, actor: %{system: true})
    assert Ash.get!(User, target.id, actor: %{system: true}).roles == ["assigned"]
  end

  test "roles assigned only to archived accounts still require removal confirmation" do
    target = create_user(roles: ["archived-only"])
    Ash.destroy!(target, actor: %{system: true})
    role = Ash.get!(Role, %{code: "archived-only"}, actor: %{system: true})

    assert {:error, %Ash.Error.Invalid{errors: errors}} =
             Ash.destroy(role, actor: %{system: true})

    assert Enum.any?(errors, fn error ->
             match?(%Ash.Error.Changes.InvalidArgument{field: :remove_assignments?}, error)
           end)

    assert Ash.get!(Role, role.id, actor: %{system: true})
  end

  test "confirmed role deletion removes active and archived memberships and records the editor" do
    admin = actor(%{"ROLES" => 12})

    active = create_user(roles: ["assigned", "retained"], display_name: "Active account")
    archived = create_user(roles: ["assigned", "retained"], display_name: "Archived account")
    unrelated = create_user(roles: ["retained"])

    assert {:ok, archived} =
             Ash.destroy(archived, actor: %{system: true}, return_destroyed?: true)

    role = Ash.get!(Role, %{code: "assigned"}, actor: %{system: true})

    grant =
      Ash.create!(RolePerm, %{roles_code: role.code, sitenav_code: "USERS", level: 4},
        actor: %{system: true}
      )

    refute Permissions.can?(admin, "/admin/users", :update)
    refute Permissions.can?(admin, "/admin/roles", :su)

    changeset =
      Ash.Changeset.for_destroy(role, :destroy, %{remove_assignments?: true}, actor: admin)

    assert {:ok, notifications} = Ash.destroy(changeset, return_notifications?: true)
    assert Ash.get!(Role, role.id, actor: %{system: true}, not_found_error?: false) == nil
    assert Ash.get!(RolePerm, grant.id, actor: %{system: true}, not_found_error?: false) == nil

    active_after = Ash.get!(User, active.id, actor: %{system: true})
    assert active_after.roles == ["retained"]
    assert active_after.display_name == active.display_name
    assert Ash.get!(User, unrelated.id, actor: %{system: true}).roles == ["retained"]

    archived_id = archived.id

    archived_after =
      User
      |> Ash.Query.new(base_filter?: false)
      |> Ash.Query.filter(id == ^archived_id)
      |> Ash.read_one!(actor: %{system: true})

    assert archived_after.roles == ["retained"]
    assert archived_after.archived_at == archived.archived_at
    assert archived_after.display_name == archived.display_name
    assert Ash.get!(User, archived_id, actor: %{system: true}, not_found_error?: false) == nil

    user_ids = [active.id, archived.id]

    events =
      Elixirbits.Events.Event
      |> Ash.Query.filter(record_id in ^user_ids and action == :remove_deleted_role)
      |> Ash.read!(actor: %{system: true})

    assert Enum.sort(Enum.map(events, & &1.record_id)) == Enum.sort(user_ids)
    assert Enum.all?(events, &(&1.user_id == admin.id))

    role_id = role.id

    assert [deletion_event] =
             Elixirbits.Events.Event
             |> Ash.Query.filter(record_id == ^role_id and action == :destroy)
             |> Ash.read!(actor: %{system: true})

    assert deletion_event.user_id == admin.id

    history =
      User
      |> AshPaperTrail.Resource.Info.version_resource()
      |> Ash.Query.filter(
        version_source_id in ^user_ids and version_action_name == :remove_deleted_role
      )
      |> Ash.read!(actor: %{system: true})

    assert Enum.sort(Enum.map(history, & &1.version_source_id)) == Enum.sort(user_ids)

    notified_user_ids =
      for notification <- notifications,
          notification.resource == User,
          notification.action.name == :remove_deleted_role,
          do: notification.data.id

    assert Enum.sort(notified_user_ids) == Enum.sort(user_ids)
  end

  test "a role editor can delete its own permission-granting role without losing cleanup authority" do
    admin = actor(%{"ROLES" => 12})
    code = hd(admin.roles)
    target = create_user(roles: [code, "retained"])
    role = Ash.get!(Role, %{code: code}, actor: %{system: true})

    changeset =
      Ash.Changeset.for_destroy(role, :destroy, %{remove_assignments?: true}, actor: admin)

    assert :ok = Ash.destroy(changeset)
    assert Ash.get!(User, admin.id, actor: %{system: true}).roles == []
    assert Ash.get!(User, target.id, actor: %{system: true}).roles == ["retained"]
    assert Ash.get!(Role, role.id, actor: %{system: true}, not_found_error?: false) == nil

    user_ids = [admin.id, target.id]

    events =
      Elixirbits.Events.Event
      |> Ash.Query.filter(record_id in ^user_ids and action == :remove_deleted_role)
      |> Ash.read!(actor: %{system: true})

    assert length(events) == 2
    assert Enum.all?(events, &(&1.user_id == admin.id))
  end

  test "confirmation cannot replace delete permission or expose the private membership cleanup" do
    target = create_user(roles: ["assigned"])
    role = Ash.get!(Role, %{code: "assigned"}, actor: %{system: true})
    reader = actor(%{"ROLES" => 4, "USERS" => 15})
    deleter = actor(%{"ROLES" => 12})

    assert {:error, %Ash.Error.Forbidden{}} =
             role
             |> Ash.Changeset.for_destroy(:destroy, %{remove_assignments?: true}, actor: reader)
             |> Ash.destroy()

    for actor <- [reader, deleter, %{system: true}] do
      assert {:error, %Ash.Error.Forbidden{}} =
               Ash.update(target, %{role_code: role.code},
                 action: :remove_deleted_role,
                 actor: actor
               )
    end

    assert {:error, %Ash.Error.Invalid{}} =
             Ash.update(target, %{role_code: "superuser"},
               action: :remove_deleted_role,
               authorize?: false
             )

    assert {:error, %Ash.Error.Invalid{}} =
             Ash.update(target, %{role_code: role.code, roles: ["superuser"]},
               action: :remove_deleted_role,
               authorize?: false
             )

    assert Ash.get!(User, target.id, actor: %{system: true}).roles == ["assigned"]
    assert Ash.get!(Role, role.id, actor: %{system: true})
  end

  test "a failed role deletion rolls back membership cleanup, grants, and audit records" do
    admin = actor(%{"ROLES" => 12})
    target = create_user(roles: ["assigned", "retained"])
    role = Ash.get!(Role, %{code: "assigned"}, actor: %{system: true})

    grant =
      Ash.create!(RolePerm, %{roles_code: role.code, sitenav_code: "USERS", level: 4},
        actor: %{system: true}
      )

    changeset =
      role
      |> Ash.Changeset.for_destroy(:destroy, %{remove_assignments?: true}, actor: admin)
      |> Ash.Changeset.after_action(fn _changeset, _role ->
        {:error, "deletion failed after membership cleanup"}
      end)

    assert {:error, _error} = Ash.destroy(changeset)
    assert Ash.get!(Role, role.id, actor: %{system: true})
    assert Ash.get!(RolePerm, grant.id, actor: %{system: true})
    assert Ash.get!(User, target.id, actor: %{system: true}).roles == ["assigned", "retained"]

    user_id = target.id

    assert [] ==
             User
             |> AshPaperTrail.Resource.Info.version_resource()
             |> Ash.Query.filter(
               version_source_id == ^user_id and version_action_name == :remove_deleted_role
             )
             |> Ash.read!(actor: %{system: true})

    assert [] ==
             Elixirbits.Events.Event
             |> Ash.Query.filter(record_id == ^user_id and action == :remove_deleted_role)
             |> Ash.read!(actor: %{system: true})

    role_id = role.id

    assert [] ==
             Elixirbits.Events.Event
             |> Ash.Query.filter(record_id == ^role_id and action == :destroy)
             |> Ash.read!(actor: %{system: true})
  end

  test "the global superuser role cannot be deleted even while unassigned" do
    role = Ash.create!(Role, %{code: "superuser", name: "Superuser"}, actor: %{system: true})
    admin = actor(%{"ROLES" => 12})

    for actor <- [admin, %{system: true}], remove_assignments? <- [false, true] do
      assert {:error, %Ash.Error.Invalid{}} =
               role
               |> Ash.Changeset.for_destroy(:destroy, %{remove_assignments?: remove_assignments?},
                 actor: actor
               )
               |> Ash.destroy()

      assert Ash.get!(Role, role.id, actor: %{system: true})
    end

    superuser = create_user(roles: ["superuser"])

    for remove_assignments? <- [false, true] do
      assert {:error, %Ash.Error.Invalid{}} =
               role
               |> Ash.Changeset.for_destroy(:destroy, %{remove_assignments?: remove_assignments?},
                 actor: superuser
               )
               |> Ash.destroy()
    end

    assert Ash.get!(Role, role.id, actor: %{system: true})
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

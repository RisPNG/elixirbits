defmodule Elixirbits.AccessControl.PermissionsTest do
  use Elixirbits.DataCase, async: false

  alias Elixirbits.AccessControl.Permissions
  alias Elixirbits.AccessControl.Role
  alias Elixirbits.AccessControl.RolePerm
  alias Elixirbits.AccessControl.Sitenav

  defp page(attrs) do
    Ash.create!(Sitenav, Map.merge(%{level: 1, state: :ENABLED}, attrs), actor: %{system: true})
  end

  test "stored permission values grant exactly their selected capabilities" do
    entry = page(%{code: "MATRIX", name: "Permission matrix", url: "matrix"})

    for {level, capabilities} <- [
          {0, []},
          {4, [:read]},
          {5, [:read, :update]},
          {6, [:read, :create]},
          {7, [:read, :create, :update]},
          {12, [:read, :delete]},
          {13, [:read, :update, :delete]},
          {14, [:read, :create, :delete]},
          {15, [:read, :create, :update, :delete]},
          {16, [:read, :create, :update, :delete, :su]}
        ] do
      role_code = "matrix_#{level}"
      Ash.create!(Role, %{code: role_code, name: "Permission #{level}"}, actor: %{system: true})

      Ash.create!(RolePerm, %{roles_code: role_code, sitenav_code: entry.code, level: level},
        actor: %{system: true}
      )

      permissions = Permissions.load(%{id: Ash.UUID.generate(), roles: [role_code]})
      assert permissions.levels[entry.code] == level
      assert Permissions.perm_level(permissions, "/matrix") == level
      assert Permissions.can_access_path?(permissions, "/matrix") == :read in capabilities

      for capability <- [:read, :create, :update, :delete, :su] do
        assert Permissions.can?(permissions, "/matrix", capability) ==
                 capability in capabilities,
               "permission #{level} has incorrect #{capability} access"
      end
    end
  end

  test "role grants combine independent capabilities and SU remains the dominant value" do
    entry = page(%{code: "UNION", name: "Combined permissions", url: "union"})

    for {role_code, level} <- [
          {"reader", 4},
          {"updater", 5},
          {"creator", 6},
          {"deleter", 12},
          {"crud", 15},
          {"special", 16}
        ] do
      Ash.create!(Role, %{code: role_code, name: role_code}, actor: %{system: true})

      Ash.create!(RolePerm, %{roles_code: role_code, sitenav_code: entry.code, level: level},
        actor: %{system: true}
      )
    end

    for {roles, expected, capabilities} <- [
          {[], 0, []},
          {["reader", "updater"], 5, [:read, :update]},
          {["updater", "creator"], 7, [:read, :create, :update]},
          {["deleter", "updater"], 13, [:read, :update, :delete]},
          {["deleter", "creator"], 14, [:read, :create, :delete]},
          {["deleter", "updater", "creator"], 15, [:read, :create, :update, :delete]},
          {["crud", "creator"], 15, [:read, :create, :update, :delete]},
          {["special", "updater"], 16, [:read, :create, :update, :delete, :su]},
          {["deleter", "creator", "updater", "special"], 16,
           [:read, :create, :update, :delete, :su]}
        ] do
      permissions = Permissions.load(%{id: Ash.UUID.generate(), roles: roles})
      assert Permissions.perm_level(permissions, "/union") == expected

      for capability <- [:read, :create, :update, :delete, :su] do
        assert Permissions.can?(permissions, "/union", capability) ==
                 capability in capabilities
      end
    end
  end

  test "invalid cached permission values deny all capabilities" do
    entry = page(%{code: "INVALID", name: "Invalid permissions", url: "invalid"})
    permissions = Permissions.load(%{id: Ash.UUID.generate(), roles: []})

    for level <- [-1, 1, 2, 3, 8, 9, 10, 11, 17, 20, 32] do
      invalid = %{permissions | levels: %{entry.code => level}}
      assert Permissions.perm_level(invalid, "/invalid") == 0
      refute Permissions.can_access_path?(invalid, "/invalid")

      for capability <- [:read, :create, :update, :delete, :su] do
        refute Permissions.can?(invalid, "/invalid", capability)
      end
    end
  end

  test "public read baseline does not turn invalid cached values into create capabilities" do
    entry =
      page(%{
        code: "INVALID_PUBLIC",
        name: "Public",
        url: "invalid-public",
        roles_bypass: ["public"]
      })

    permissions = Permissions.load(%{id: Ash.UUID.generate(), roles: []})

    for level <- [1, 2, 3, 8, 9, 10, 11, 17, 20, 32] do
      invalid = %{permissions | levels: %{entry.code => level}}
      assert Permissions.perm_level(invalid, "/invalid-public") == 4
      assert Permissions.can?(invalid, "/invalid-public", :read)

      for capability <- [:create, :update, :delete, :su] do
        refute Permissions.can?(invalid, "/invalid-public", capability)
      end
    end
  end

  test "RolePerm rejects unsupported permission values without changing a valid grant" do
    entry = page(%{code: "VALID", name: "Validated permissions", url: "valid"})
    role = Ash.create!(Role, %{code: "validated", name: "Validated"}, actor: %{system: true})

    invalid_role =
      Ash.create!(Role, %{code: "invalid_grants", name: "Invalid grants"}, actor: %{system: true})

    grant =
      Ash.create!(RolePerm, %{roles_code: role.code, sitenav_code: entry.code, level: 4},
        actor: %{system: true}
      )

    for level <- [-1, 1, 2, 3, 8, 9, 10, 11, 17, 20, 32] do
      assert {:error, %Ash.Error.Invalid{}} =
               Ash.create(
                 RolePerm,
                 %{roles_code: invalid_role.code, sitenav_code: entry.code, level: level},
                 actor: %{system: true}
               )

      assert {:error, %Ash.Error.Invalid{}} =
               Ash.update(grant, %{level: level}, actor: %{system: true})
    end

    assert Ash.get!(RolePerm, grant.id, actor: %{system: true}).level == 4
  end

  test "public pages grant read access and disabled pages deny every capability" do
    entry = page(%{code: "PUB", name: "Public", url: "public", roles_bypass: ["public"]})
    permissions = Permissions.load(nil)

    assert Permissions.public_path?(permissions, "/public")
    assert Permissions.can?(permissions, "/public", :read)
    assert Permissions.perm_level(permissions, "/public") == 4

    for capability <- [:create, :update, :delete, :su] do
      refute Permissions.can?(permissions, "/public", capability)
    end

    Ash.update!(entry, %{}, action: :disable, actor: %{system: true})
    permissions = Permissions.load(%{id: Ash.UUID.generate(), roles: ["superuser"]})

    refute Permissions.public_path?(permissions, "/public")
    refute Permissions.can_access_path?(permissions, "/public")
    assert Permissions.perm_level(permissions, "/public") == 0

    for capability <- [:read, :create, :update, :delete, :su] do
      refute Permissions.can?(permissions, "/public", capability)
    end
  end

  test "public read access preserves additional role capabilities" do
    entry = page(%{code: "PUB", name: "Public", url: "public", roles_bypass: ["public"]})
    Ash.create!(Role, %{code: "public", name: "Public"}, actor: %{system: true})
    public_role = Permissions.load(%{id: Ash.UUID.generate(), roles: ["public"]})
    assert Permissions.perm_level(public_role, "/public") == 4
    refute Permissions.can?(public_role, "/public", :su)

    for level <- [0, 5, 6, 7, 12, 13, 14, 15, 16] do
      role_code = "public_#{level}"
      Ash.create!(Role, %{code: role_code, name: role_code}, actor: %{system: true})

      Ash.create!(RolePerm, %{roles_code: role_code, sitenav_code: entry.code, level: level},
        actor: %{system: true}
      )

      permissions = Permissions.load(%{id: Ash.UUID.generate(), roles: ["public", role_code]})
      assert Permissions.public_path?(permissions, "/public")
      assert Permissions.can?(permissions, "/public", :read)
      assert Permissions.perm_level(permissions, "/public") == if(level == 0, do: 4, else: level)
      assert Permissions.can?(permissions, "/public", :create) == level in [6, 7, 14, 15, 16]
      assert Permissions.can?(permissions, "/public", :update) == level in [5, 7, 13, 15, 16]
      assert Permissions.can?(permissions, "/public", :delete) == level in [12, 13, 14, 15, 16]
      assert Permissions.can?(permissions, "/public", :su) == (level == 16)
    end
  end

  test "global superuser and explicit role or user bypasses grant SU" do
    bypassed_user_id = Ash.UUID.generate()

    page(%{
      code: "BYPASS",
      name: "Bypass",
      url: "bypass",
      roles_bypass: ["manager"],
      users_bypass: [bypassed_user_id]
    })

    for user <- [
          %{id: Ash.UUID.generate(), roles: ["superuser"]},
          %{id: Ash.UUID.generate(), roles: ["manager"]},
          %{id: bypassed_user_id, roles: []}
        ] do
      permissions = Permissions.load(user)
      assert Permissions.perm_level(permissions, "/bypass") == 16

      for capability <- [:read, :create, :update, :delete, :su] do
        assert Permissions.can?(permissions, "/bypass", capability)
      end
    end
  end

  test "unknown paths deny even a superuser and root public access does not cover descendants" do
    page(%{code: "HOME", name: "Home", url: "", roles_bypass: ["public"]})
    permissions = Permissions.load(%{id: Ash.UUID.generate(), roles: ["superuser"]})

    assert Permissions.can_access_path?(permissions, "/")
    refute Permissions.can_access_path?(permissions, "/admin/unregistered")
    assert Permissions.perm_level(permissions, "/admin/unregistered") == 0

    for capability <- [:read, :create, :update, :delete, :su] do
      refute Permissions.can?(permissions, "/admin/unregistered", capability)
    end

    refute Permissions.can?(permissions.user, "/admin/unregistered", :read)
  end

  test "longest matching path and role grant levels determine access" do
    page(%{code: "ADMIN", name: "Admin", url: "admin", roles_bypass: ["public"]})
    page(%{code: "USERS", name: "Users", url: "admin/users"})
    Ash.create!(Role, %{code: "viewer", name: "Viewer"}, actor: %{system: true})

    Ash.create!(RolePerm, %{roles_code: "viewer", sitenav_code: "USERS", level: 4},
      actor: %{system: true}
    )

    permissions = Permissions.load(%{id: Ash.UUID.generate(), roles: ["viewer"]})

    assert Permissions.can?(permissions, "/admin/users/123/update", :read)
    refute Permissions.public_path?(permissions, "/admin/users/123/update")
    refute Permissions.can?(permissions, "/admin/users/123/update", :update)
    assert Permissions.public_path?(permissions, "/admin/users-other")
  end

  test "navigation retains ancestors and branch state without querying per check" do
    page(%{code: "GROUP", name: "Group", url: nil, sequence: 1})

    page(%{
      code: "CHILD",
      name: "Child",
      url: "child",
      parent: "GROUP",
      sequence: 2,
      roles_bypass: ["manager"]
    })

    permissions = Permissions.load(%{id: Ash.UUID.generate(), roles: ["manager"]})
    handler = "permissions-#{System.unique_integer([:positive])}"
    test_pid = self()

    :telemetry.attach(
      handler,
      [:elixirbits, :repo, :query],
      fn _, _, _, _ -> if self() == test_pid, do: send(test_pid, :query) end,
      nil
    )

    on_exit(fn -> :telemetry.detach(handler) end)

    assert Enum.map(Permissions.visible_sitenav(permissions), & &1.code) == ["GROUP", "CHILD"]
    assert Permissions.active_branch_codes(permissions, "/child/123") == ["CHILD", "GROUP"]
    assert Permissions.perm_level(permissions, "/child") == 16

    for capability <- [:read, :create, :update, :delete, :su] do
      assert Permissions.can?(permissions, "/child", capability)
    end

    refute_received :query
  end

  test "loaded grants remain a query-free snapshot until explicitly reloaded" do
    entry = page(%{code: "CACHED", name: "Cached", url: "cached"})
    Ash.create!(Role, %{code: "cached", name: "Cached"}, actor: %{system: true})

    grant =
      Ash.create!(RolePerm, %{roles_code: "cached", sitenav_code: entry.code, level: 5},
        actor: %{system: true}
      )

    user = %{id: Ash.UUID.generate(), roles: ["cached"]}
    original = Permissions.load(user)
    Ash.update!(grant, %{level: 6}, actor: %{system: true})
    refreshed = Permissions.load(user)
    handler = "permissions-cache-#{System.unique_integer([:positive])}"
    test_pid = self()

    :telemetry.attach(
      handler,
      [:elixirbits, :repo, :query],
      fn _, _, _, _ -> if self() == test_pid, do: send(test_pid, :query) end,
      nil
    )

    on_exit(fn -> :telemetry.detach(handler) end)
    Ash.read!(Sitenav, authorize?: false)
    assert_received :query

    assert Permissions.perm_level(original, "/cached") == 5
    assert Permissions.can?(original, "/cached", :update)
    refute Permissions.can?(original, "/cached", :create)
    assert Permissions.perm_level(refreshed, "/cached") == 6
    assert Permissions.can?(refreshed, "/cached", :create)
    refute Permissions.can?(refreshed, "/cached", :update)
    assert Enum.map(Permissions.visible_sitenav(original), & &1.code) == [entry.code]
    assert Permissions.active_branch_codes(original, "/cached/123") == [entry.code]
    assert Permissions.can_access_path?(original, "/cached/123")
    refute Permissions.public_path?(original, "/cached")
    refute_received :query
  end

  test "disabled structural ancestors deny their enabled public descendants" do
    group = page(%{code: "GROUP", name: "Group", url: nil})
    page(%{code: "CHILD", name: "Child", url: "child", parent: "GROUP", roles_bypass: ["public"]})

    bypassed_user_id = Ash.UUID.generate()

    leaf =
      page(%{
        code: "LEAF",
        name: "Leaf",
        url: "child/leaf",
        parent: "CHILD",
        roles_bypass: ["public", "manager"],
        users_bypass: [bypassed_user_id]
      })

    Ash.create!(Role, %{code: "special", name: "Special"}, actor: %{system: true})

    Ash.create!(RolePerm, %{roles_code: "special", sitenav_code: leaf.code, level: 16},
      actor: %{system: true}
    )

    assert Permissions.public_path?(Permissions.load(nil), "/child/leaf")

    Ash.update!(group, %{}, action: :disable, actor: %{system: true})

    for user <- [
          nil,
          %{id: Ash.UUID.generate(), roles: ["superuser"]},
          %{id: Ash.UUID.generate(), roles: ["manager"]},
          %{id: bypassed_user_id, roles: []},
          %{id: Ash.UUID.generate(), roles: ["special"]}
        ] do
      permissions = Permissions.load(user)
      refute Permissions.public_path?(permissions, "/child")
      refute Permissions.can_access_path?(permissions, "/child/leaf")
      assert Permissions.perm_level(permissions, "/child/leaf") == 0

      for capability <- [:read, :create, :update, :delete, :su] do
        refute Permissions.can?(permissions, "/child/leaf", capability)
      end

      assert Permissions.visible_sitenav(permissions) == []
    end
  end
end

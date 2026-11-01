defmodule Elixirbits.AuditLogTest do
  use Elixirbits.DataCase, async: false

  import ElixirbitsWeb.ConnCase, only: [create_user: 1]

  alias Elixirbits.AccessControl.Role
  alias Elixirbits.AccessControl.RolePerm
  alias Elixirbits.AccessControl.Sitenav
  alias Elixirbits.Accounts.User
  alias Elixirbits.AuditLog
  alias Elixirbits.Ledger.Account
  alias Elixirbits.Organizations
  alias Elixirbits.Organizations.Organization

  @system %{system: true}

  setup do
    for {code, url} <- [
          {"USERS", "admin/users"},
          {"ROLES", "admin/roles"},
          {"ORG", "admin/organization"}
        ] do
      Ash.create!(Sitenav, %{code: code, name: code, url: url, level: 1}, actor: @system)
    end

    :ok
  end

  defp editor(levels) do
    code = "audit-editor-#{System.unique_integer([:positive])}"
    user = create_user(roles: [code], display_name: "Audit editor")

    for {page, level} <- levels do
      Ash.create!(RolePerm, %{roles_code: code, sitenav_code: page, level: level}, actor: @system)
    end

    user
  end

  test "navigation history restores an existing tracked resource through its own actions" do
    author = editor(%{"ROLES" => 16})

    entry =
      Ash.create!(
        Sitenav,
        %{
          code: "GENERIC_AUDIT",
          name: "Original navigation",
          description: "Original description",
          level: 1
        },
        actor: author
      )

    assert {:ok, initial_history} = AuditLog.history(Sitenav, entry.id, author)
    original = hd(initial_history.revisions)
    assert original.author == "Audit editor"

    grant =
      Ash.create!(RolePerm, %{roles_code: hd(author.roles), sitenav_code: entry.code, level: 4},
        actor: @system
      )

    entry =
      Ash.update!(entry, %{name: "Current navigation", description: "Current description"},
        actor: author
      )

    Ash.update!(entry, %{}, action: :disable, actor: author)
    Ash.update!(grant, %{level: 5}, actor: @system)

    assert {:ok, history} = AuditLog.history(Sitenav, entry.id, author)
    assert history.can_restore?
    saved = Enum.find(history.revisions, &(&1.id == original.id))
    previous = AuditLog.revision_record(history.record, saved)
    current = AuditLog.revision_record(history.record, saved, :current)
    assert previous.name == "Original navigation"
    assert previous.state == :ENABLED
    assert current.name == "Current navigation"
    assert current.state == :DISABLED

    assert Enum.any?(saved.current_fields, fn field ->
             field.key == "state" and field.status == :changed and not field.restorable?
           end)

    assert {:ok, _} = AuditLog.restore(Sitenav, entry.id, original.id, author)
    restored = Ash.get!(Sitenav, entry.id, actor: @system)
    assert restored.name == "Original navigation"
    assert restored.description == "Original description"
    assert restored.state == :DISABLED
    assert Ash.get!(RolePerm, grant.id, actor: @system).level == 5
    assert {:ok, restored_history} = AuditLog.history(Sitenav, entry.id, author)
    assert hd(restored_history.revisions).restored_from_version_id == original.id
    assert hd(restored_history.revisions).author == "Audit editor"
  end

  test "permission history follows identity changes and role moves without exposing another role's earlier changes" do
    author = create_user(roles: ["superuser"])

    first_role =
      Ash.create!(
        Role,
        %{
          code: "original-grant-owner",
          name: "Original owner",
          permissions: [%{sitenav_code: "USERS", level: 4}]
        },
        actor: author,
        load: [:role_perms]
      )

    second_role = Ash.create!(Role, %{code: "new-grant-owner", name: "New owner"}, actor: author)
    assert {:ok, original_history} = AuditLog.history(Role, first_role.id, author)
    original = hd(original_history.revisions)
    assert {:ok, second_initial_history} = AuditLog.history(Role, second_role.id, author)
    second_creation = hd(second_initial_history.revisions)
    [grant] = first_role.role_perms
    renamed_grant = Ash.update!(grant, %{sitenav_code: "ORG"}, actor: author)

    assert {:ok, renamed_history} = AuditLog.history(Role, first_role.id, author)
    renamed = AuditLog.revision_record(renamed_history.record, hd(renamed_history.revisions))
    assert [%{sitenav_code: "ORG", level: 4}] = renamed.role_perms
    earlier_first_ids = MapSet.new(renamed_history.revisions, & &1.id)
    Ash.update!(renamed_grant, %{roles_code: second_role.code}, actor: author)

    assert {:ok, first_history} = AuditLog.history(Role, first_role.id, author)
    first_latest = hd(first_history.revisions)
    assert AuditLog.revision_record(first_history.record, first_latest).role_perms == []
    refute Enum.any?(first_latest.current_fields, &(&1.status == :changed))

    original_revision = Enum.find(first_history.revisions, &(&1.id == original.id))
    original_record = AuditLog.revision_record(first_history.record, original_revision)
    assert [%{sitenav_code: "USERS", level: 4}] = original_record.role_perms

    assert {:ok, second_history} = AuditLog.history(Role, second_role.id, author)
    assert [incoming, creation] = second_history.revisions
    assert creation.id == second_creation.id
    refute MapSet.member?(earlier_first_ids, incoming.id)
    moved_record = AuditLog.revision_record(second_history.record, incoming)
    assert [%{sitenav_code: "ORG", roles_code: owner, level: 4}] = moved_record.role_perms
    assert owner == second_role.code
  end

  test "an unrelated page path cannot grant audit viewing or full CRUD restoration" do
    reader = editor(%{"ROLES" => 4, "USERS" => 15})

    entry =
      Ash.create!(Sitenav, %{code: "PRIVATE_AUDIT", name: "Private navigation", level: 1},
        actor: @system
      )

    assert {:error, _} = AuditLog.history(Sitenav, entry.id, reader, path: "/admin/users")

    updater = editor(%{"ROLES" => 5, "USERS" => 15})
    role = Ash.create!(Role, %{code: "path-protected", name: "Original role"}, actor: @system)
    assert {:ok, history} = AuditLog.history(Role, role.id, updater)
    original = hd(history.revisions)
    Ash.update!(role, %{name: "Current role"}, actor: @system)

    assert {:error, _} =
             AuditLog.preview(Role, role.id, original.id, updater, path: "/admin/users")

    assert {:error, _} =
             AuditLog.restore(Role, role.id, original.id, updater, path: "/admin/users")

    assert Ash.get!(Role, role.id, actor: @system).name == "Current role"
  end

  test "a tracked resource without an update action still has readable history" do
    account =
      Ash.create!(Account, %{identifier: "generic-audit-account", currency: "MYR"},
        action: :open,
        actor: @system
      )

    assert {:ok, history} = AuditLog.history(Account, account.id, @system)
    refute history.can_restore?
    creation = hd(history.revisions)
    assert creation.author == "System"

    assert AuditLog.revision_record(history.record, creation).identifier ==
             "generic-audit-account"

    assert {:error, _} = AuditLog.restore(Account, account.id, creation.id, @system)
  end

  test "profile history identifies the editor and distinguishes changed, unchanged, and unrecorded fields" do
    actor = editor(%{"USERS" => 5})
    target = create_user(display_name: "Original profile", first_name: "Unchanged first name")

    updated =
      Ash.update!(target, %{display_name: "Updated profile"}, action: :update, actor: actor)

    assert {:ok, edited_history} = AuditLog.history(User, target.id, actor)
    edited_id = hd(edited_history.revisions).id
    Ash.update!(updated, %{display_name: "Current profile"}, action: :update, actor: @system)

    assert {:ok, history} = AuditLog.history(User, target.id, actor)
    revision = Enum.find(history.revisions, &(&1.id == edited_id))
    assert revision.author == "Audit editor"
    assert revision.at
    refute history.can_restore?

    assert Enum.any?(revision.fields, fn field ->
             field.before == "Original profile" and field.after == "Updated profile" and
               field.status == :changed and field.restorable?
           end)

    assert Enum.any?(revision.fields, fn field ->
             field.before == "Unchanged first name" and field.after == "Unchanged first name" and
               field.status == :unchanged
           end)

    assert Enum.any?(revision.fields, &(&1.status == :unknown and not &1.restorable?))

    assert Enum.any?(revision.current_fields, fn field ->
             field.before == "Updated profile" and field.after == "Current profile" and
               field.status == :changed
           end)

    assert Enum.any?(hd(history.revisions).fields, &(&1.status == :changed))
    refute Enum.any?(hd(history.revisions).current_fields, &(&1.status == :changed))
    refute inspect(revision.fields) =~ target.hashed_password
    refute inspect(revision.fields) =~ "password1234"
  end

  test "audit viewing requires update and restoring requires every CRUD capability" do
    role = Ash.create!(Role, %{code: "audited-role", name: "Original role"}, actor: @system)
    role = Ash.update!(role, %{name: "Current role"}, actor: @system)

    for level <- [0, 4, 6, 12, 14] do
      assert {:error, _} = AuditLog.history(Role, role.id, editor(%{"ROLES" => level}))
    end

    for level <- [5, 7, 13] do
      actor = editor(%{"ROLES" => level})
      assert {:ok, history} = AuditLog.history(Role, role.id, actor)
      refute history.can_restore?
      assert {:error, _} = AuditLog.restore(Role, role.id, List.last(history.revisions).id, actor)
    end

    actor = editor(%{"ROLES" => 15})
    assert {:ok, history} = AuditLog.history(Role, role.id, actor)
    assert history.can_restore?
    revision = List.last(history.revisions)
    assert {:ok, _} = AuditLog.restore(Role, role.id, revision.id, actor)
    assert Ash.get!(Role, role.id, actor: @system).name == "Original role"
  end

  test "restore uses combined role grants and rejects permissions revoked after viewing" do
    actor = editor(%{"ROLES" => 7})
    extra_code = "audit-delete-#{System.unique_integer([:positive])}"
    Ash.create!(Role, %{code: extra_code, name: extra_code}, actor: @system)

    Ash.create!(RolePerm, %{roles_code: extra_code, sitenav_code: "ROLES", level: 12},
      actor: @system
    )

    actor =
      Ash.update!(actor, %{roles: actor.roles ++ [extra_code]},
        action: :assign_roles,
        actor: @system
      )

    role = Ash.create!(Role, %{code: "combined-role", name: "Original"}, actor: @system)
    Ash.update!(role, %{name: "Changed"}, actor: @system)

    assert {:ok, history} = AuditLog.history(Role, role.id, actor)
    assert history.can_restore?
    original = List.last(history.revisions)
    assert {:ok, _} = AuditLog.restore(Role, role.id, original.id, actor)

    Ash.update!(actor, %{roles: []}, action: :assign_roles, actor: @system)
    assert {:error, _} = AuditLog.restore(Role, role.id, original.id, actor)
    assert {:error, _} = AuditLog.history(Role, role.id, actor)
  end

  test "restoring a user restores addresses and keeps the current password and profile picture" do
    actor = create_user(roles: ["superuser"], display_name: "Restoring admin")

    target =
      create_user(
        display_name: "Original profile",
        display_pic_url: "/uploads/users/original.png",
        display_pic_name: "original.png",
        addresses: [%{line_1: "Original home"}]
      )

    assert {:ok, history} = AuditLog.history(User, target.id, actor)
    original = hd(history.revisions)

    target =
      Ash.update!(
        target,
        %{
          display_name: "Current profile",
          display_pic_url: "/uploads/users/current.png",
          display_pic_name: "current.png",
          addresses: [%{line_1: "Current office"}]
        },
        action: :update,
        actor: actor
      )

    target =
      Ash.update!(
        target,
        %{
          current_password: "password1234",
          password: "replacement-password",
          password_confirmation: "replacement-password"
        },
        action: :change_password,
        actor: @system
      )

    assert {:ok, changed_history} = AuditLog.history(User, target.id, actor)

    assert Enum.any?(changed_history.revisions, fn revision ->
             Enum.any?(revision.fields, fn field ->
               field.status == :changed and not field.restorable? and
                 (field.after == "/uploads/users/current.png" or field.after == "current.png")
             end)
           end)

    assert {:ok, preview} = AuditLog.preview(User, target.id, original.id, actor)

    assert Enum.any?(preview, fn field ->
             field.before == "Current profile" and field.after == "Original profile" and
               field.status == :changed
           end)

    previous_ids = MapSet.new(changed_history.revisions, & &1.id)
    assert {:ok, _} = AuditLog.restore(User, target.id, original.id, actor)
    restored = Ash.get!(User, target.id, actor: @system, load: [:addresses])
    assert restored.display_name == "Original profile"
    assert Enum.map(restored.addresses, & &1.line_1) == ["Original home"]
    assert restored.display_pic_url == "/uploads/users/current.png"
    assert restored.display_pic_name == "current.png"
    assert restored.hashed_password == target.hashed_password

    assert {:ok, restored_history} = AuditLog.history(User, target.id, actor)
    assert MapSet.subset?(previous_ids, MapSet.new(restored_history.revisions, & &1.id))
    latest = hd(restored_history.revisions)
    assert latest.restored_from_version_id == original.id
    assert latest.author == "Restoring admin"
  end

  test "an address-only save appears as one organization revision and restores the complete address set" do
    actor = editor(%{"ORG" => 15})

    organization =
      Organizations.create_organization!(
        %{name: "Office", addresses: [%{line_1: "Original office"}]},
        actor: actor,
        load: [:addresses]
      )

    [address] = organization.addresses
    assert {:ok, history} = AuditLog.history(Organization, nil, actor)
    original = hd(history.revisions)

    organization =
      Organizations.update_organization!(
        organization,
        %{addresses: [%{id: address.id, line_1: "Moved office"}, %{line_1: "New branch"}]},
        actor: actor,
        load: [:addresses]
      )

    assert {:ok, changed_history} = AuditLog.history(Organization, organization.id, actor)
    assert length(changed_history.revisions) == length(history.revisions) + 1

    assert Enum.any?(hd(changed_history.revisions).fields, fn field ->
             field.before == "Original office" and field.after == "Moved office" and
               field.status == :changed
           end)

    refute Enum.any?(hd(changed_history.revisions).current_fields, &(&1.status == :changed))

    assert {:ok, _} = AuditLog.restore(Organization, organization.id, original.id, actor)
    restored = Ash.get!(Organization, organization.id, actor: @system, load: [:addresses])
    assert restored.name == "Office"
    assert Enum.map(restored.addresses, & &1.line_1) == ["Original office"]
  end

  test "a revision from another record cannot be restored or previewed" do
    actor = editor(%{"ROLES" => 15})
    first = Ash.create!(Role, %{code: "first-history", name: "First"}, actor: @system)
    second = Ash.create!(Role, %{code: "second-history", name: "Second"}, actor: @system)
    assert {:ok, history} = AuditLog.history(Role, first.id, actor)
    revision = hd(history.revisions)

    assert {:error, _} = AuditLog.preview(Role, second.id, revision.id, actor)
    assert {:error, _} = AuditLog.restore(Role, second.id, revision.id, actor)
    assert Ash.get!(Role, second.id, actor: @system).name == "Second"
  end

  test "full CRUD does not bypass special authority over permission grants" do
    admin = create_user(roles: ["superuser"])
    editor = editor(%{"ROLES" => 15})

    role =
      Ash.create!(
        Role,
        %{
          code: "grant-history",
          name: "Original",
          permissions: [%{sitenav_code: "USERS", level: 4}]
        },
        actor: admin
      )

    assert {:ok, history} = AuditLog.history(Role, role.id, admin)
    original = hd(history.revisions)

    Ash.update!(role, %{name: "Changed", permissions: [%{sitenav_code: "USERS", level: 5}]},
      actor: admin
    )

    assert {:error, _} = AuditLog.restore(Role, role.id, original.id, editor)
    saved = Ash.get!(Role, role.id, actor: @system, load: [:role_perms])
    assert saved.name == "Changed"
    assert Enum.map(saved.role_perms, & &1.level) == [5]

    assert {:ok, _} = AuditLog.restore(Role, role.id, original.id, admin)
    restored = Ash.get!(Role, role.id, actor: @system, load: [:role_perms])
    assert restored.name == "Original"
    assert Enum.map(restored.role_perms, & &1.level) == [4]
  end

  test "an explicit no-access grant does not require SU to restore ordinary role fields" do
    admin = create_user(roles: ["superuser"])
    actor = editor(%{"ROLES" => 15})
    role = Ash.create!(Role, %{code: "no-access-history", name: "Original"}, actor: admin)
    assert {:ok, history} = AuditLog.history(Role, role.id, actor)
    original = hd(history.revisions)

    Ash.update!(
      role,
      %{name: "Changed", permissions: [%{sitenav_code: "USERS", level: 0}]},
      actor: admin
    )

    assert {:ok, _} = AuditLog.restore(Role, role.id, original.id, actor)
    restored = Ash.get!(Role, role.id, actor: @system, load: [:role_perms])
    assert restored.name == "Original"
    assert [%{sitenav_code: "USERS", level: 0}] = restored.role_perms
  end

  test "invalid historical role membership prevents the entire user restore" do
    actor = create_user(roles: ["superuser"])
    member = Ash.create!(Role, %{code: "former-member", name: "Former member"}, actor: @system)
    target = create_user(display_name: "Original", roles: [member.code])
    assert {:ok, history} = AuditLog.history(User, target.id, actor)
    original = hd(history.revisions)

    target = Ash.update!(target, %{display_name: "Current", roles: []}, actor: actor)
    Ash.destroy!(member, actor: actor)
    assert {:ok, current_history} = AuditLog.history(User, target.id, actor)

    assert {:error, _} = AuditLog.restore(User, target.id, original.id, actor)
    saved = Ash.get!(User, target.id, actor: @system)
    assert saved.display_name == "Current"
    assert saved.roles == []
    assert {:ok, unchanged_history} = AuditLog.history(User, target.id, actor)

    assert Enum.map(unchanged_history.revisions, & &1.id) ==
             Enum.map(current_history.revisions, & &1.id)
  end
end

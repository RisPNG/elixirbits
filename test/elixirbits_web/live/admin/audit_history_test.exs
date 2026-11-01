defmodule ElixirbitsWeb.Admin.AuditHistoryTest do
  use ElixirbitsWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Elixirbits.AccessControl.Role
  alias Elixirbits.AccessControl.RolePerm
  alias Elixirbits.AccessControl.Sitenav
  alias Elixirbits.Accounts.User
  alias Elixirbits.AuditLog
  alias Elixirbits.Organizations
  alias Elixirbits.Organizations.Organization

  @system %{system: true}

  setup do
    for {code, path} <- [
          {"USERS", "admin/users"},
          {"ROLES", "admin/roles"},
          {"ORG", "admin/organization"}
        ] do
      Ash.create!(Sitenav, %{code: code, name: code, url: path, level: 1}, actor: @system)
    end

    :ok
  end

  defp grant(conn, levels, name \\ "History editor") do
    code = "audit-editor-#{System.unique_integer([:positive])}"
    actor = create_user(roles: [code], display_name: name)

    grants =
      for {page, level} <- levels do
        Ash.create!(RolePerm, %{roles_code: code, sitenav_code: page, level: level},
          actor: @system
        )
      end

    {log_in_user(conn, actor), actor, grants}
  end

  test "History appears only on saved View pages for editors", %{conn: conn} do
    target = create_user(display_name: "History target")
    role = Ash.create!(Role, %{code: "history-role", name: "History role"}, actor: @system)
    {manager_conn, _actor, _grants} = grant(conn, %{"USERS" => 15, "ROLES" => 15, "ORG" => 15})

    for path <- [~p"/admin/organization", ~p"/admin/organization/update"] do
      {:ok, view, _html} = live(manager_conn, path)
      refute has_element?(view, "a[data-tooltip=History]")
    end

    Organizations.create_organization!(%{name: "History organization"}, actor: @system)

    for level <- [4, 5] do
      {operator_conn, _actor, _grants} =
        grant(conn, %{"USERS" => level, "ROLES" => level, "ORG" => level})

      for path <- [
            ~p"/admin/users/#{target.id}/read",
            ~p"/admin/roles/#{role.id}/read",
            ~p"/admin/organization"
          ] do
        {:ok, view, _html} = live(operator_conn, path)

        for position <- ["header", "footer"] do
          assert has_element?(
                   view,
                   "#{position} a[href='#{path}?history=true'][data-tooltip=History]"
                 ) == (level == 5)
        end
      end
    end

    for path <- [
          ~p"/admin/users/create",
          ~p"/admin/users/#{target.id}/update",
          ~p"/admin/roles/create",
          ~p"/admin/roles/#{role.id}/update",
          ~p"/admin/organization/update"
        ] do
      {:ok, view, _html} = live(manager_conn, path)
      refute has_element?(view, "a[data-tooltip=History]")
      refute has_element?(view, "#audit-history-picker")
      refute has_element?(view, "#audit-revision")
    end
  end

  test "readers cannot forge the picker or historical revision query", %{conn: conn} do
    target = create_user(display_name: "Private historical name")
    {editor_conn, actor, [editor_grant]} = grant(conn, %{"USERS" => 5})
    {:ok, history} = AuditLog.history(User, target.id, actor)
    original = hd(history.revisions)
    Ash.update!(target, %{display_name: "Current reader-visible name"}, actor: actor)
    {reader_conn, _reader, _grants} = grant(conn, %{"USERS" => 4})
    path = ~p"/admin/users/#{target.id}/read"

    for params <- [%{"history" => "true"}, %{"version" => original.id}] do
      view =
        case live(reader_conn, path <> "?" <> URI.encode_query(params)) do
          {:ok, view, _html} ->
            assert_patch(view, path)
            view

          {:error, {_kind, %{to: ^path}}} ->
            {:ok, view, _html} = live(reader_conn, path)
            view
        end

      refute has_element?(view, "#audit-history-picker")
      refute has_element?(view, "#audit-revision")
      refute render(view) =~ "Private historical name"
      assert has_element?(view, "#form_display_name[value='Current reader-visible name']")
    end

    {:ok, view, _html} = live(editor_conn, path <> "?history=true")
    assert has_element?(view, "#audit-history-picker #revision-#{original.id}")
    view |> element("#revision-#{original.id}") |> render_click()
    assert_patch(view, path <> "?version=#{original.id}")
    Ash.update!(editor_grant, %{level: 4}, actor: @system)
    view |> form("#audit-value-form", audit: %{side: "current"}) |> render_change()
    refute has_element?(view, "#audit-revision")
    refute has_element?(view, "#audit-history-picker")
    assert has_element?(view, "#form_display_name[value='Current reader-visible name']")
  end

  test "Previous highlights the selected save while Current compares its snapshot with today's record",
       %{conn: conn} do
    {conn, actor, _grants} = grant(conn, %{"USERS" => 5}, "Alice history")

    target =
      create_user(
        display_name: "Earlier saved name",
        first_name: "Earlier first name",
        last_name: "Earlier last name",
        display_pic_url: "/uploads/users/earlier.png"
      )

    selected_record =
      Ash.update!(
        target,
        %{
          display_name: "Selected saved name",
          first_name: "Same first name",
          display_pic_url: "/uploads/users/selected.png"
        },
        actor: actor
      )

    {:ok, selected_history} = AuditLog.history(User, target.id, actor)
    selected = hd(selected_history.revisions)

    Ash.update!(
      selected_record,
      %{
        display_name: "Today's current name",
        last_name: "Today's last name",
        display_pic_url: "/uploads/users/current.png"
      },
      actor: actor
    )

    {:ok, saved_history} = AuditLog.history(User, target.id, actor)
    latest = hd(saved_history.revisions)
    path = ~p"/admin/users/#{target.id}/read"

    {:ok, view, _html} = live(conn, path)
    view |> element("header a[data-tooltip=History]") |> render_click()
    assert_patch(view, path <> "?history=true")
    assert has_element?(view, "#audit-history-picker", "Alice history")
    assert has_element?(view, "input[name='form[display_name]'][value=\"Today's current name\"]")
    refute has_element?(view, "#user-form #audit-history-picker")
    view |> element("#audit-history-picker a", "Cancel") |> render_click()
    assert_patch(view, path)
    refute has_element?(view, "#audit-history-picker")
    view |> element("header a[data-tooltip=History]") |> render_click()
    assert_patch(view, path <> "?history=true")
    view |> element("#revision-#{selected.id}") |> render_click()
    assert_patch(view, path <> "?version=#{selected.id}")

    assert has_element?(view, "#audit-value-form input[value=previous][checked]:not([disabled])")
    assert has_element?(view, "#audit-revision", "Alice history")

    assert has_element?(
             view,
             "input[name='form[display_name]'][value='Selected saved name'][data-audit-changed=true][data-audit-side=previous]"
           )

    assert has_element?(
             view,
             "input[name='form[first_name]'][value='Same first name'][data-audit-changed=true][data-audit-side=previous]"
           )

    assert has_element?(view, "input[name='form[last_name]'][value='Earlier last name']")
    refute has_element?(view, "input[name='form[last_name]'][data-audit-changed=true]")
    assert has_element?(view, "#user-form fieldset[disabled]")
    refute has_element?(view, "#audit-unknown-fields")
    refute has_element?(view, "#audit-revision", "Red fields changed")
    refute has_element?(view, "#audit-revision", "Some values were not recorded")
    refute has_element?(view, "#audit-revision", "Password")
    refute render(view) =~ target.hashed_password
    refute has_element?(view, "#audit-picture-notice")

    assert has_element?(
             view,
             "[data-audit-changed=true][data-audit-side=previous] img[src='/uploads/users/current.png']"
           )

    refute has_element?(view, "img[src='/uploads/users/selected.png']")
    refute has_element?(view, "#user-form button[type=submit]")
    refute has_element?(view, "button[phx-click=request_restore]")

    view |> form("#audit-value-form", audit: %{side: "current"}) |> render_change()
    current_selected_path = assert_patch(view)

    assert URI.decode_query(URI.parse(current_selected_path).query) == %{
             "version" => selected.id,
             "side" => "current"
           }

    assert has_element?(
             view,
             "input[name='form[display_name]'][value=\"Today's current name\"][data-audit-changed=true][data-audit-side=current]"
           )

    assert has_element?(view, "input[name='form[first_name]'][value='Same first name']")
    refute has_element?(view, "input[name='form[first_name]'][data-audit-changed=true]")

    assert has_element?(
             view,
             "input[name='form[last_name]'][value=\"Today's last name\"][data-audit-changed=true][data-audit-side=current]"
           )

    assert has_element?(
             view,
             "[data-audit-changed=true][data-audit-side=current] img[src='/uploads/users/current.png']"
           )

    view |> element("header a[data-tooltip=History]") |> render_click()
    picker_path = assert_patch(view)

    assert URI.decode_query(URI.parse(picker_path).query) == %{
             "history" => "true",
             "version" => selected.id,
             "side" => "current"
           }

    view |> element("#audit-history-picker a", "Cancel") |> render_click()
    assert_patch(view, current_selected_path)
    assert has_element?(view, "#audit-value-form input[value=current][checked]")
    view |> element("header a[data-tooltip=History]") |> render_click()
    assert_patch(view, picker_path)
    view |> element("#revision-#{latest.id}") |> render_click()
    assert_patch(view, path <> "?version=#{latest.id}")
    assert has_element?(view, "#audit-value-form input[value=previous][checked]")

    assert has_element?(
             view,
             "input[name='form[display_name]'][value=\"Today's current name\"][data-audit-changed=true][data-audit-side=previous]"
           )

    assert has_element?(
             view,
             "input[name='form[last_name]'][value=\"Today's last name\"][data-audit-changed=true][data-audit-side=previous]"
           )

    refute has_element?(view, "input[name='form[first_name]'][data-audit-changed=true]")
    view |> form("#audit-value-form", audit: %{side: "current"}) |> render_change()
    assert_patch(view)
    assert has_element?(view, "input[name='form[display_name]'][value=\"Today's current name\"]")
    refute has_element?(view, "#user-form [data-audit-changed=true]")

    render_click(view, "request_restore")
    refute has_element?(view, "#confirm-restore")
    assert has_element?(view, "[role=alert]", "Full create, read, update, and delete access")
    render_click(view, "confirm_restore")
    assert Ash.get!(User, target.id, actor: @system).display_name == "Today's current name"
    assert {:ok, unchanged_history} = AuditLog.history(User, target.id, actor)

    assert Enum.map(unchanged_history.revisions, & &1.id) ==
             Enum.map(saved_history.revisions, & &1.id)

    view |> element("#audit-revision a", "Current view") |> render_click()
    assert_patch(view, path)
    assert has_element?(view, "#form_display_name[value=\"Today's current name\"]")
    refute has_element?(view, "#form_display_name[data-audit-changed=true]")
    refute has_element?(view, "#audit-revision")
  end

  test "View blocks ordinary mutations and Current still restores the selected saved snapshot", %{
    conn: conn
  } do
    {conn, actor, _grants} = grant(conn, %{"USERS" => 15}, "Bob history")
    target = create_user(display_name: "Original name", display_pic_url: "/uploads/users/old.png")
    {:ok, history} = AuditLog.history(User, target.id, actor)
    original = hd(history.revisions)

    Ash.update!(
      target,
      %{display_name: "Updated name", display_pic_url: "/uploads/users/new.png"},
      actor: actor
    )

    path = ~p"/admin/users/#{target.id}/read"
    {:ok, view, _html} = live(conn, path <> "?version=#{original.id}")
    assert has_element?(view, "input[name='form[display_name]'][value='Original name']")
    render_submit(view, "save", %{"form" => %{"display_name" => "Forged name"}})
    render_click(view, "remove_upload")
    assert Ash.get!(User, target.id, actor: @system).display_name == "Updated name"
    assert has_element?(view, "img[src='/uploads/users/new.png']")
    view |> form("#audit-value-form", audit: %{side: "current"}) |> render_change()
    assert_patch(view)

    assert has_element?(
             view,
             "input[name='form[display_name]'][value='Updated name'][data-audit-side=current]"
           )

    view |> element("button[phx-click=request_restore]") |> render_click()
    assert has_element?(view, "#confirm-restore", "Original name")
    assert has_element?(view, "#confirm-restore", "Updated name")
    assert has_element?(view, "#restore-fields", "Not restored")
    view |> element("button[phx-click=cancel_restore]") |> render_click()
    refute has_element?(view, "#confirm-restore")
    render_click(view, "confirm_restore")
    assert Ash.get!(User, target.id, actor: @system).display_name == "Updated name"
    view |> element("button[phx-click=request_restore]") |> render_click()
    result = view |> element("button[phx-click=confirm_restore]") |> render_click()

    restored_view =
      case result do
        {:error, {_kind, %{to: ^path}}} ->
          {:ok, restored_view, _html} = follow_redirect(result, conn, path)
          restored_view

        html when is_binary(html) ->
          assert_patch(view, path)
          view
      end

    restored = Ash.get!(User, target.id, actor: @system)
    assert restored.display_name == "Original name"
    assert restored.display_pic_url == "/uploads/users/new.png"
    assert has_element?(restored_view, "#form_display_name[value='Original name']")
    refute has_element?(restored_view, "#audit-revision")
    restored_view |> element("header a[data-tooltip=History]") |> render_click()
    assert has_element?(restored_view, "#audit-history-picker", "Restored a previous version")
    assert has_element?(restored_view, "#audit-history-picker", "Bob history")
  end

  test "restore rechecks full CRUD after the preview opens", %{conn: conn} do
    {conn, actor, [grant]} = grant(conn, %{"USERS" => 15})
    target = create_user(display_name: "Original name")
    {:ok, history} = AuditLog.history(User, target.id, actor)
    original = hd(history.revisions)
    Ash.update!(target, %{display_name: "Updated name"}, actor: actor)

    {:ok, view, _html} =
      live(conn, ~p"/admin/users/#{target.id}/read" <> "?version=#{original.id}")

    view |> element("button[phx-click=request_restore]") |> render_click()
    assert has_element?(view, "#confirm-restore")
    Ash.update!(grant, %{level: 5}, actor: @system)
    view |> element("button[phx-click=confirm_restore]") |> render_click()
    refute has_element?(view, "#confirm-restore")
    assert has_element?(view, "[role=alert]", "Full create, read, update, and delete access")
    assert Ash.get!(User, target.id, actor: @system).display_name == "Updated name"
  end

  test "foreign revisions are rejected and Update ignores historical query parameters", %{
    conn: conn
  } do
    {conn, actor, _grants} = grant(conn, %{"USERS" => 15})
    target = create_user(display_name: "Target current")
    other = create_user(display_name: "Other private history")
    {:ok, history} = AuditLog.history(User, other.id, actor)
    foreign = hd(history.revisions)
    path = ~p"/admin/users/#{target.id}/read"

    view =
      case live(conn, path <> "?version=#{foreign.id}") do
        {:ok, view, _html} ->
          assert_patch(view, path)
          view

        {:error, {_kind, %{to: ^path}}} ->
          {:ok, view, _html} = live(conn, path)
          view
      end

    refute has_element?(view, "#audit-revision")
    refute render(view) =~ "Other private history"
    assert has_element?(view, "#form_display_name[value='Target current']")
    {:ok, history} = AuditLog.history(User, target.id, actor)
    original = hd(history.revisions)
    Ash.update!(target, %{display_name: "Editable current"}, actor: actor)

    {:ok, edit, _html} =
      live(conn, ~p"/admin/users/#{target.id}/update" <> "?version=#{original.id}&history=true")

    assert has_element?(edit, "#form_display_name[value='Editable current']")
    assert has_element?(edit, "#user-form button[type=submit]")
    refute has_element?(edit, "#audit-revision")
    refute has_element?(edit, "#audit-history-picker")
    refute has_element?(edit, "a[data-tooltip=History]")
  end

  test "organization Previous shows the selected save's removals while Current shows later removals",
       %{conn: conn} do
    {conn, actor, _grants} = grant(conn, %{"ORG" => 15}, "Organization editor")

    organization =
      Organizations.create_organization!(
        %{
          name: "Original organization",
          addresses: [
            %{line_1: "Original retained office"},
            %{line_1: "Removed by selected save"},
            %{line_1: "Removed later"}
          ]
        },
        actor: actor,
        load: [:addresses]
      )

    retained = Enum.find(organization.addresses, &(&1.line_1 == "Original retained office"))
    later_removed = Enum.find(organization.addresses, &(&1.line_1 == "Removed later"))

    selected_record =
      Organizations.update_organization!(
        organization,
        %{
          name: "Selected organization",
          addresses: [
            %{id: retained.id, line_1: "Selected retained office"},
            %{id: later_removed.id, line_1: "Removed later"}
          ]
        },
        actor: actor
      )

    {:ok, history} = AuditLog.history(Organization, organization.id, actor)
    selected = hd(history.revisions)

    Organizations.update_organization!(
      selected_record,
      %{
        name: "Today's organization",
        addresses: [
          %{id: retained.id, line_1: "Current retained office"},
          %{line_1: "New branch"}
        ]
      },
      actor: actor
    )

    {:ok, view, _html} = live(conn, ~p"/admin/organization" <> "?version=#{selected.id}")

    assert has_element?(
             view,
             "#form-#{selected.id}-previous_name[data-audit-side=previous]",
             "Selected organization"
           )

    assert has_element?(
             view,
             "#organization-form [data-audit-changed=true][data-audit-side=previous]",
             "Selected retained office"
           )

    assert has_element?(view, "#organization-form", "Removed later")
    refute has_element?(view, "#organization-form [data-audit-changed=true]", "Removed later")
    refute has_element?(view, "#organization-form", "Removed by selected save")
    refute has_element?(view, "#organization-form", "New branch")
    assert has_element?(view, "#audit-removed-fields", "Removed in this revision")
    assert has_element?(view, "#audit-removed-fields", "Removed by selected save")
    refute has_element?(view, "#audit-removed-fields", "Removed later")
    refute has_element?(view, "#audit-added-fields")
    refute has_element?(view, "#organization-form button[type=submit]")

    view |> form("#audit-value-form", audit: %{side: "current"}) |> render_change()
    assert_patch(view)

    assert has_element?(
             view,
             "#form-#{selected.id}-current_name[data-audit-side=current]",
             "Today's organization"
           )

    assert has_element?(
             view,
             "#organization-form [data-audit-changed=true][data-audit-side=current]",
             "Current retained office"
           )

    assert has_element?(
             view,
             "#organization-form [data-audit-changed=true][data-audit-side=current]",
             "New branch"
           )

    refute has_element?(view, "#organization-form", "Removed later")
    assert has_element?(view, "#audit-removed-fields", "Removed since this revision")
    assert has_element?(view, "#audit-removed-fields", "Removed later")
    refute has_element?(view, "#audit-removed-fields", "Removed by selected save")
    refute has_element?(view, "#audit-added-fields")
    assert Organizations.organization_settings!(actor: @system).name == "Today's organization"
  end

  test "address removal lists only populated values while clearing and refilling a field remain changes",
       %{conn: conn} do
    {conn, actor, _grants} = grant(conn, %{"USERS" => 15})

    target =
      create_user(display_name: "Address history", addresses: [%{line_1: "a"}])
      |> Ash.load!(:addresses, actor: @system)

    [address] = target.addresses
    field_key = "addresses.#{address.id}.line_1"
    path = ~p"/admin/users/#{target.id}/read"

    cleared = Ash.update!(target, %{addresses: [%{id: address.id, line_1: nil}]}, actor: actor)
    {:ok, cleared_history} = AuditLog.history(User, target.id, actor)
    cleared_revision = hd(cleared_history.revisions)
    cleared_field = Enum.find(cleared_revision.fields, &(&1.key == field_key))
    assert cleared_field.status == :changed
    assert cleared_field.before == "a"
    assert cleared_field.after == "Not set"
    assert cleared_field.before_present? and cleared_field.after_present?

    {:ok, cleared_view, _html} = live(conn, path <> "?version=#{cleared_revision.id}")

    cleared_selector =
      "input[name='form[addresses][0][line_1]'][data-audit-changed=true][data-audit-side=previous]"

    assert has_element?(cleared_view, cleared_selector)

    cleared_input =
      cleared_view |> render() |> Floki.parse_document!() |> Floki.find(cleared_selector)

    assert Floki.attribute(cleared_input, "value") in [[], [""]]
    refute has_element?(cleared_view, "#audit-removed-fields")

    refilled = Ash.update!(cleared, %{addresses: [%{id: address.id, line_1: "a"}]}, actor: actor)
    {:ok, refilled_history} = AuditLog.history(User, target.id, actor)
    refilled_revision = hd(refilled_history.revisions)
    refilled_field = Enum.find(refilled_revision.fields, &(&1.key == field_key))
    assert refilled_field.status == :changed
    assert refilled_field.before == "Not set"
    assert refilled_field.after == "a"
    assert refilled_field.before_present? and refilled_field.after_present?

    {:ok, refilled_view, _html} = live(conn, path <> "?version=#{refilled_revision.id}")

    assert has_element?(
             refilled_view,
             "input[name='form[addresses][0][line_1]'][value=a][data-audit-changed=true][data-audit-side=previous]"
           )

    Ash.update!(refilled, %{addresses: []}, actor: actor)
    {:ok, deleted_history} = AuditLog.history(User, target.id, actor)
    deletion = hd(deleted_history.revisions)
    before_deletion = Enum.find(deleted_history.revisions, &(&1.id == refilled_revision.id))

    for fields <- [deletion.fields, before_deletion.current_fields] do
      by_key = Map.new(fields, &{&1.key, &1})
      assert by_key[field_key].status == :changed
      assert by_key[field_key].before == "a"
      refute by_key[field_key].after_present?

      for field <- [
            "line_2",
            "line_3",
            "contact_name",
            "contact_tel_no",
            "city",
            "state",
            "country",
            "postal_code"
          ] do
        assert by_key["addresses.#{address.id}.#{field}"].status == :unchanged
      end
    end

    {:ok, deleted_view, _html} = live(conn, path <> "?version=#{deletion.id}")

    {:ok, current_view, _html} =
      live(conn, path <> "?version=#{refilled_revision.id}&side=current")

    for view <- [deleted_view, current_view] do
      cards =
        view
        |> render()
        |> Floki.parse_document!()
        |> Floki.find("#audit-removed-fields > [data-field]")

      assert Floki.attribute(cards, "data-field") == [field_key]
      assert cards |> Floki.find("p.whitespace-pre-wrap") |> Floki.text() == "a"
      refute has_element?(view, "#audit-removed-fields", "Not set")
      refute has_element?(view, "input[name='form[addresses][0][line_1]']")
    end

    assert Ash.get!(User, target.id, actor: @system, load: [:addresses]).addresses == []
  end

  test "a user creation highlights populated values and leaves blank optional values unmarked", %{
    conn: conn
  } do
    {conn, actor, _grants} = grant(conn, %{"USERS" => 15})
    suffix = System.unique_integer([:positive])

    target =
      Ash.create!(
        User,
        %{
          email: "audit-created-#{suffix}@example.com",
          username: "audit-created-#{suffix}",
          password: "password1234",
          password_confirmation: "password1234",
          display_name: "",
          first_name: "",
          tel_no: "",
          weight_kg: 0,
          addresses: [%{line_1: "Created home", line_2: "", latitude: 0}]
        },
        action: :create,
        actor: actor,
        load: [:addresses]
      )

    {:ok, history} = AuditLog.history(User, target.id, actor)
    creation = Enum.find(history.revisions, &(&1.action == :create))
    fields = Map.new(creation.fields, &{&1.key, &1})
    [address] = target.addresses

    for key <- [
          "email",
          "username",
          "weight_kg",
          "addresses.#{address.id}.line_1",
          "addresses.#{address.id}.latitude"
        ] do
      assert fields[key].status == :changed
    end

    for key <- [
          "display_name",
          "first_name",
          "middle_name",
          "last_name",
          "tel_no",
          "dob",
          "timezone",
          "sex",
          "roles",
          "addresses.#{address.id}.line_2",
          "addresses.#{address.id}.city"
        ] do
      assert fields[key].status == :unchanged
    end

    assert fields["hashed_password"].status == :unknown
    refute Enum.any?(creation.current_fields, &(&1.status == :changed))

    {:ok, view, _html} =
      live(conn, ~p"/admin/users/#{target.id}/read" <> "?version=#{creation.id}")

    assert has_element?(view, "#audit-value-form input[value=previous][checked]:not([disabled])")

    for field <- ["email", "username"] do
      assert has_element?(
               view,
               "input[name='form[#{field}]'][data-audit-changed=true][data-audit-side=previous]"
             )
    end

    for field <- ["display_name", "first_name", "tel_no", "dob", "timezone"] do
      assert has_element?(view, "input[name='form[#{field}]']")
      refute has_element?(view, "input[name='form[#{field}]'][data-audit-changed=true]")
    end

    for field <- ["sex", "roles"] do
      refute has_element?(view, "#form-#{creation.id}-previous_#{field}[data-audit-changed=true]")

      refute has_element?(
               view,
               "[data-audit-changed=true] #form-#{creation.id}-previous_#{field}"
             )
    end

    assert has_element?(
             view,
             "input[name='form[addresses][0][line_1]'][value='Created home'][data-audit-changed=true]"
           )

    refute has_element?(view, "input[name='form[addresses][0][line_2]'][data-audit-changed=true]")
    refute has_element?(view, "input[name='form[addresses][0][city]'][data-audit-changed=true]")
    view |> form("#audit-value-form", audit: %{side: "current"}) |> render_change()
    assert_patch(view)
    refute has_element?(view, "#user-form [data-audit-changed=true]")
  end

  test "creation revisions compare their saved grants with today's grants without disabling Previous",
       %{conn: conn} do
    admin = create_user(roles: ["superuser"])
    {conn, actor, _grants} = grant(conn, %{"ROLES" => 5})

    role =
      Ash.create!(
        Role,
        %{
          code: "historical-grants",
          name: "Created role",
          permissions: [%{sitenav_code: "USERS", level: 4}]
        },
        actor: admin
      )

    {:ok, history} = AuditLog.history(Role, role.id, actor)
    created = hd(history.revisions)

    Ash.update!(role, %{name: "Today's role", permissions: [%{sitenav_code: "USERS", level: 15}]},
      actor: admin
    )

    path = ~p"/admin/roles/#{role.id}/read"
    {:ok, view, _html} = live(conn, path <> "?tab=profile")
    view |> element("header a[data-tooltip=History]") |> render_click()
    picker_path = assert_patch(view)

    assert URI.decode_query(URI.parse(picker_path).query) == %{
             "tab" => "profile",
             "history" => "true"
           }

    view |> element("#revision-#{created.id}") |> render_click()
    previous_path = assert_patch(view)

    assert URI.decode_query(URI.parse(previous_path).query) == %{
             "tab" => "profile",
             "version" => created.id
           }

    assert has_element?(view, "#audit-value-form input[value=previous][checked]:not([disabled])")

    assert has_element?(
             view,
             "input[name='form[name]'][value='Created role'][data-audit-changed=true][data-audit-side=previous]"
           )

    assert has_element?(
             view,
             "[data-audit-changed=true][data-audit-side=previous] #permission-level-USERS[disabled][value=Read]"
           )

    view |> form("#audit-value-form", audit: %{side: "current"}) |> render_change()
    current_path = assert_patch(view)

    assert URI.decode_query(URI.parse(current_path).query) == %{
             "tab" => "profile",
             "version" => created.id,
             "side" => "current"
           }

    assert has_element?(
             view,
             "input[name='form[name]'][value=\"Today's role\"][data-audit-side=current]"
           )

    assert has_element?(
             view,
             "[data-audit-changed=true][data-audit-side=current] #permission-level-USERS[disabled][value='Read + Create + Update + Delete']"
           )

    view |> form("#audit-value-form", audit: %{side: "previous"}) |> render_change()
    assert_patch(view, previous_path)

    assert has_element?(
             view,
             "input[name='form[name]'][value='Created role'][data-audit-side=previous]"
           )

    assert Ash.get!(Role, role.id, actor: @system).name == "Today's role"
    view |> element("header a[data-tooltip=History]") |> render_click()
    reopened_picker = assert_patch(view)

    assert URI.decode_query(URI.parse(reopened_picker).query) == %{
             "tab" => "profile",
             "version" => created.id,
             "history" => "true"
           }

    view |> element("#audit-history-picker a", "Cancel") |> render_click()
    assert_patch(view, previous_path)
    view |> element("#audit-revision a", "Current view") |> render_click()
    assert_patch(view, path <> "?tab=profile")
    refute has_element?(view, "#audit-revision")
    assert has_element?(view, "#form_name[value=\"Today's role\"]")
  end
end

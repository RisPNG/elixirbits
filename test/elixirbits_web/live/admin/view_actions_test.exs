defmodule ElixirbitsWeb.Admin.ViewActionsTest do
  use ElixirbitsWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Elixirbits.AccessControl.Role
  alias Elixirbits.AccessControl.RolePerm
  alias Elixirbits.AccessControl.Sitenav
  alias Elixirbits.Accounts.User

  @system %{system: true}

  setup do
    for {code, path} <- [{"USERS", "admin/users"}, {"ROLES", "admin/roles"}] do
      Ash.create!(Sitenav, %{code: code, name: code, url: path, level: 1}, actor: @system)
    end

    :ok
  end

  defp grant(conn, levels) do
    code = "viewer-#{System.unique_integer([:positive])}"
    user = create_user(roles: [code])

    for {page, level} <- levels do
      Ash.create!(RolePerm, %{roles_code: code, sitenav_code: page, level: level}, actor: @system)
    end

    log_in_user(conn, user)
  end

  test "readers and administrators can open records using the collection View action", %{
    conn: conn
  } do
    user = create_user(display_name: "Viewed account")
    role = Ash.create!(Role, %{code: "viewed-role", name: "Viewed role"}, actor: @system)

    for level <- [4, 16],
        {page, collection, record, form_id} <- [
          {"USERS", "/admin/users", user, "user-form"},
          {"ROLES", "/admin/roles", role, "role-form"}
        ] do
      operator_conn = grant(conn, %{page => level})
      {:ok, index, _html} = live(operator_conn, collection)
      render_async(index)
      destination = "#{collection}/#{record.id}/read"
      update_path = "#{collection}/#{record.id}/update"

      assert has_element?(index, "a[href='#{destination}'][data-tooltip=View]")
      assert has_element?(index, "a[href='#{update_path}']") == (level == 16)

      result = index |> element("a[href='#{destination}']") |> render_click()
      {:ok, entry, _html} = follow_redirect(result, operator_conn, destination)

      refute has_element?(entry, "##{form_id} button[type=submit]")

      for position <- ["header", "footer"] do
        assert has_element?(
                 entry,
                 "##{form_id} #{position} a[href='#{collection}'][data-tooltip=Back]"
               )

        assert has_element?(
                 entry,
                 "##{form_id} #{position} a[href='#{update_path}'][data-tooltip=Update]"
               ) == (level == 16)
      end
    end
  end

  test "user View preserves profile, address, role, and picture details without editing controls",
       %{
         conn: conn
       } do
    user =
      create_user(
        display_name: "Stored profile",
        first_name: "Stored first name",
        username: nil,
        middle_name: nil,
        last_name: nil,
        dob: nil,
        roles: ["view-member"],
        addresses: [%{line_1: "Stored address"}],
        display_pic_url: "/uploads/users/viewed.png",
        display_pic_name: "viewed.png"
      )

    for level <- [4, 16] do
      operator_conn = grant(conn, %{"USERS" => level, "ROLES" => level})
      {:ok, view, html} = live(operator_conn, ~p"/admin/users/#{user.id}/read")
      document = Floki.parse_document!(html)

      assert has_element?(view, "h1", "View Stored profile")
      assert has_element?(view, "#user-form fieldset[disabled]")

      assert has_element?(
               view,
               "input[name='form[display_name]'][value='Stored profile'][disabled]"
             )

      assert has_element?(
               view,
               "input[name='form[first_name]'][value='Stored first name'][disabled]"
             )

      assert has_element?(
               view,
               "input[name='form[addresses][0][line_1]'][value='Stored address'][disabled]"
             )

      for id <- [
            "form_username",
            "form_middle_name",
            "form_last_name",
            "form_dob",
            "form_addresses_0_other_label",
            "form_addresses_0_contact_name",
            "form_addresses_0_line_2",
            "form_addresses_0_line_3",
            "form_addresses_0_postal_code",
            "form_addresses_0_city",
            "form_addresses_0_state",
            "form_addresses_0_country"
          ] do
        assert has_element?(
                 view,
                 "input##{id}.input-floating-control[disabled]:not([placeholder])"
               )

        assert Floki.attribute(document, "input##{id}", "value") in [[], [""]]
        assert Floki.find(document, "input##{id} + .input-floating-label") != []
      end

      assert has_element?(view, "input#form_dob[phx-hook=VCalendar][data-vc-mode=date][disabled]")

      refute has_element?(
               view,
               "#user-form input:not([type=hidden]):not([disabled]), #user-form textarea:not([disabled]), #user-form select:not([disabled])"
             )

      assert has_element?(view, "img[src='/uploads/users/viewed.png']")
      assert has_element?(view, "#user-roles input[disabled][value='view-member']")

      refute has_element?(view, "#user-form[phx-change]")
      refute has_element?(view, "#user-form[phx-submit]")
      refute has_element?(view, "#user-form button[type=submit]")
      refute has_element?(view, "#user-form button[phx-click=request_delete]")
      refute has_element?(view, "#user-form button[phx-click=add_form]")
      refute has_element?(view, "#user-form button[phx-click=remove_form]")
      refute has_element?(view, "#user-profile-picture-picker")
      refute has_element?(view, "#user-profile-picture-remove")
    end
  end

  test "role View displays saved permissions without granting administrators editing controls", %{
    conn: conn
  } do
    role =
      Ash.create!(
        Role,
        %{code: "view-permissions", name: "Stored role", description: "Stored details"},
        actor: @system
      )

    Ash.create!(RolePerm, %{roles_code: role.code, sitenav_code: "USERS", level: 5},
      actor: @system
    )

    for level <- [4, 16] do
      operator_conn = grant(conn, %{"ROLES" => level})
      {:ok, view, _html} = live(operator_conn, ~p"/admin/roles/#{role.id}/read")

      assert has_element?(view, "h1", "View Stored role")
      assert has_element?(view, "#role-form fieldset[disabled]")
      assert has_element?(view, "input[name='role_code'][value='view-permissions'][disabled]")
      assert has_element?(view, "input[name='form[name]'][value='Stored role']")
      assert has_element?(view, "textarea[name='form[description]']", "Stored details")

      assert has_element?(
               view,
               "input#permission-level-USERS[disabled][value='Read + Update']"
             )

      refute has_element?(view, "#permission-level-USERS[phx-hook=PetalComboBox]")
      refute has_element?(view, "#role-form[phx-change]")
      refute has_element?(view, "#role-form[phx-submit]")
      refute has_element?(view, "#role-form button[type=submit]")
      refute has_element?(view, "#role-form button[phx-click=request_delete]")
    end
  end

  test "View ignores forged user changes and deletion events even for a superuser", %{conn: conn} do
    target =
      create_user(
        display_name: "Unchanged profile",
        roles: ["view-member"],
        addresses: [%{line_1: "Unchanged address"}],
        display_pic_url: "/uploads/users/unchanged.png",
        display_pic_name: "unchanged.png"
      )

    conn = log_in_user(conn, create_user(roles: ["superuser"]))
    {:ok, view, _html} = live(conn, ~p"/admin/users/#{target.id}/read")

    render_change(view, "validate", %{"form" => %{"display_name" => "Forged profile"}})
    render_click(view, "add_form", %{"field" => "addresses"})
    render_click(view, "remove_form", %{"path" => "form[addresses][0]"})
    render_click(view, "remove_upload")

    render_submit(view, "save", %{
      "form" => %{"display_name" => "Forged profile", "roles" => ["superuser"]}
    })

    render_click(view, "request_delete", %{"id" => target.id})
    refute has_element?(view, "#confirm-delete")
    render_click(view, "confirm_delete")

    unchanged = Ash.get!(User, target.id, actor: @system, load: [:addresses])
    assert unchanged.display_name == "Unchanged profile"
    assert unchanged.roles == ["view-member"]
    assert unchanged.display_pic_url == "/uploads/users/unchanged.png"
    assert Enum.map(unchanged.addresses, & &1.line_1) == ["Unchanged address"]
    assert has_element?(view, "input[name='form[display_name]'][value='Unchanged profile']")
    assert has_element?(view, "img[src='/uploads/users/unchanged.png']")
  end

  test "View ignores forged role metadata, permission, and deletion changes for a superuser", %{
    conn: conn
  } do
    role = Ash.create!(Role, %{code: "unchanged-role", name: "Unchanged role"}, actor: @system)

    Ash.create!(RolePerm, %{roles_code: role.code, sitenav_code: "USERS", level: 4},
      actor: @system
    )

    conn = log_in_user(conn, create_user(roles: ["superuser"]))
    {:ok, view, _html} = live(conn, ~p"/admin/roles/#{role.id}/read")

    render_change(view, "validate", %{
      "form" => %{"name" => "Forged role"},
      "page_levels" => %{"USERS" => "16"}
    })

    render_submit(view, "save", %{"form" => %{"name" => "Forged role"}})
    render_click(view, "request_delete", %{"id" => role.id})
    refute has_element?(view, "#confirm-delete")
    render_click(view, "confirm_delete")

    unchanged = Ash.get!(Role, role.id, actor: @system, load: [:role_perms])
    assert unchanged.name == "Unchanged role"
    assert Enum.find(unchanged.role_perms, &(&1.sitenav_code == "USERS")).level == 4
    assert has_element?(view, "input[name='form[name]'][value='Unchanged role']")
    assert has_element?(view, "input#permission-level-USERS[disabled][value=Read]")
  end

  test "View routes retain page-access restrictions and respect disabled navigation", %{
    conn: conn
  } do
    user = create_user()
    role = Ash.create!(Role, %{code: "protected-view", name: "Protected role"}, actor: @system)

    for path <- [~p"/admin/users/#{user.id}/read", ~p"/admin/roles/#{role.id}/read"] do
      assert {:error, {:redirect, %{to: "/sign-in"}}} = live(conn, path)
      ungranted_conn = log_in_user(conn, create_user())
      assert {:error, {:redirect, %{to: "/"}}} = live(ungranted_conn, path)
    end

    conn = log_in_user(conn, create_user(roles: ["superuser"]))

    for {code, path} <- [
          {"USERS", ~p"/admin/users/#{user.id}/read"},
          {"ROLES", ~p"/admin/roles/#{role.id}/read"}
        ] do
      page = Ash.get!(Sitenav, %{code: code}, actor: @system)
      Ash.update!(page, %{}, action: :disable, actor: @system)
      assert {:error, {:redirect, %{to: "/"}}} = live(conn, path)
    end
  end
end

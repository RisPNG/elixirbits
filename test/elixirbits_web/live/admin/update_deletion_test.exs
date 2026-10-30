defmodule ElixirbitsWeb.Admin.UpdateDeletionTest do
  use ElixirbitsWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  require Ash.Query

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
    code = "update-deleter-#{System.unique_integer([:positive])}"
    user = create_user(roles: [code])

    grants =
      Map.new(levels, fn {page, level} ->
        grant =
          Ash.create!(RolePerm, %{roles_code: code, sitenav_code: page, level: level},
            actor: @system
          )

        {page, grant}
      end)

    %{
      conn: log_in_user(conn, user),
      user: user,
      role: Ash.get!(Role, %{code: code}, actor: @system),
      grants: grants
    }
  end

  test "update pages place Delete after Back and Save at both ends", %{conn: conn} do
    target = create_user(display_name: "Existing account")
    role = Ash.create!(Role, %{code: "existing", name: "Existing role"}, actor: @system)
    manager = grant(conn, %{"USERS" => 15, "ROLES" => 15})

    for {path, form_id} <- [
          {~p"/admin/users/#{target.id}/update", "user-form"},
          {~p"/admin/roles/#{role.id}/update", "role-form"}
        ] do
      {:ok, view, _html} = live(manager.conn, path)
      document = view |> render() |> Floki.parse_document!()

      for position <- ["header", "footer"] do
        controls = Floki.find(document, "##{form_id} > section > #{position} [data-tooltip]")

        labels =
          Enum.map(controls, fn control ->
            [label] = Floki.attribute([control], "data-tooltip")
            label
          end)

        assert labels == ["Back", "Save", "Delete"]

        assert has_element?(
                 view,
                 "##{form_id} > section > #{position} button[phx-click=request_delete][type=button]"
               )
      end
    end
  end

  test "opening and canceling either Delete button preserves unsaved form changes", %{conn: conn} do
    target = create_user(display_name: "Saved account")
    role = Ash.create!(Role, %{code: "draft-role", name: "Saved role"}, actor: @system)
    manager = grant(conn, %{"USERS" => 15, "ROLES" => 15})

    for {resource, record, path, form_id, field, saved_name} <- [
          {User, target, ~p"/admin/users/#{target.id}/update", "user-form", :display_name,
           "Saved account"},
          {Role, role, ~p"/admin/roles/#{role.id}/update", "role-form", :name, "Saved role"}
        ] do
      {:ok, view, _html} = live(manager.conn, path)
      draft = "Unsaved #{saved_name}"
      view |> form("##{form_id}", form: %{field => draft}) |> render_change()

      for position <- ["header", "footer"] do
        view
        |> element("##{form_id} > section > #{position} button[phx-click=request_delete]")
        |> render_click()

        assert has_element?(view, "#confirm-delete", saved_name)
        assert Map.fetch!(Ash.get!(resource, record.id, actor: @system), field) == saved_name

        view |> element("#confirm-delete button[phx-click=cancel_delete]") |> render_click()

        refute has_element?(view, "#confirm-delete")
        assert has_element?(view, "##{form_id} input[name='form[#{field}]'][value='#{draft}']")
        assert Map.fetch!(Ash.get!(resource, record.id, actor: @system), field) == saved_name
      end
    end
  end

  test "a delete-only user operator can archive from the update page without Save", %{conn: conn} do
    target = create_user(display_name: "Delete-only target")
    manager = grant(conn, %{"USERS" => 12})
    {:ok, view, _html} = live(manager.conn, ~p"/admin/users/#{target.id}/update")

    refute has_element?(view, "#user-form button[type=submit]")

    for position <- ["header", "footer"] do
      assert has_element?(
               view,
               "#user-form > section > #{position} button[phx-click=request_delete][type=button]:not([disabled])"
             )
    end

    view |> element("#user-form footer button[phx-click=request_delete]") |> render_click()

    assert {:error, {:live_redirect, %{to: "/admin/users"}}} =
             view |> element("#confirm-delete button[phx-click=confirm_delete]") |> render_click()

    assert Ash.get!(User, target.id, actor: @system, not_found_error?: false) == nil
    id = target.id

    archived =
      User
      |> Ash.Query.new(base_filter?: false)
      |> Ash.Query.filter(id == ^id)
      |> Ash.read_one!(actor: @system)

    assert %DateTime{} = archived.archived_at
    assert archived.display_name == target.display_name
  end

  test "a delete-only role operator can delete from the update page without Save", %{conn: conn} do
    role = Ash.create!(Role, %{code: "delete-only", name: "Delete-only role"}, actor: @system)
    manager = grant(conn, %{"ROLES" => 12})
    {:ok, view, _html} = live(manager.conn, ~p"/admin/roles/#{role.id}/update")

    refute has_element?(view, "#role-form button[type=submit]")

    for position <- ["header", "footer"] do
      assert has_element?(
               view,
               "#role-form > section > #{position} button[phx-click=request_delete][type=button]:not([disabled])"
             )
    end

    view |> element("#role-form header button[phx-click=request_delete]") |> render_click()

    assert {:error, {:live_redirect, %{to: "/admin/roles"}}} =
             view |> element("#confirm-delete button[phx-click=confirm_delete]") |> render_click()

    assert Ash.get!(Role, role.id, actor: @system, not_found_error?: false) == nil
  end

  test "readers and updaters cannot offer or forge deletion from an update page", %{conn: conn} do
    target = create_user()

    role =
      Ash.create!(Role, %{code: "protected-by-permission", name: "Keep role"}, actor: @system)

    for level <- [4, 5] do
      manager = grant(conn, %{"USERS" => level, "ROLES" => level})

      for {resource, record, path, form_id} <- [
            {User, target, ~p"/admin/users/#{target.id}/update", "user-form"},
            {Role, role, ~p"/admin/roles/#{role.id}/update", "role-form"}
          ] do
        {:ok, view, _html} = live(manager.conn, path)
        refute has_element?(view, "##{form_id} button[phx-click=request_delete]")
        render_click(view, "request_delete", %{"id" => record.id})
        refute has_element?(view, "#confirm-delete")
        refute has_element?(view, "#confirm-role-removal")
        render_click(view, "confirm_delete", %{"id" => record.id, "remove-assignments" => "true"})
        assert Ash.get!(resource, record.id, actor: @system)
      end
    end
  end

  test "creation pages expose no Delete and cannot delete an id supplied in a forged request", %{
    conn: conn
  } do
    target = create_user()
    role = Ash.create!(Role, %{code: "keep-from-create", name: "Keep role"}, actor: @system)
    manager = grant(conn, %{"USERS" => 15, "ROLES" => 15})

    for {resource, record, path, form_id} <- [
          {User, target, ~p"/admin/users/create", "user-form"},
          {Role, role, ~p"/admin/roles/create", "role-form"}
        ] do
      {:ok, view, _html} = live(manager.conn, path)
      refute has_element?(view, "##{form_id} button[phx-click=request_delete]")
      render_click(view, "request_delete", %{"id" => record.id})
      refute has_element?(view, "#confirm-delete")
      refute has_element?(view, "#confirm-role-removal")
      render_click(view, "confirm_delete", %{"id" => record.id, "remove-assignments" => "true"})
      assert Ash.get!(resource, record.id, actor: @system)
      assert has_element?(view, "##{form_id}")
    end
  end

  test "entry deletion remains bound to the displayed record when event ids are forged", %{
    conn: conn
  } do
    target = create_user(display_name: "Displayed account")
    other_user = create_user(display_name: "Other account")
    role = Ash.create!(Role, %{code: "displayed-role", name: "Displayed role"}, actor: @system)
    other_role = Ash.create!(Role, %{code: "other-role", name: "Other role"}, actor: @system)
    manager = grant(conn, %{"USERS" => 15, "ROLES" => 15})

    for {resource, record, other, name, other_name, path, destination} <- [
          {User, target, other_user, "Displayed account", "Other account",
           ~p"/admin/users/#{target.id}/update", "/admin/users"},
          {Role, role, other_role, "Displayed role", "Other role",
           ~p"/admin/roles/#{role.id}/update", "/admin/roles"}
        ] do
      {:ok, view, _html} = live(manager.conn, path)
      render_click(view, "request_delete", %{"id" => other.id})
      assert has_element?(view, "#confirm-delete", name)
      refute has_element?(view, "#confirm-delete", other_name)

      assert {:error, {:live_redirect, %{to: ^destination}}} =
               render_click(view, "confirm_delete", %{"id" => other.id})

      assert Ash.get!(resource, record.id, actor: @system, not_found_error?: false) == nil
      assert Ash.get!(resource, other.id, actor: @system)
    end
  end

  test "assigned role deletion requires the marked second confirmation and preserves canceled drafts",
       %{
         conn: conn
       } do
    member = create_user(roles: ["obsolete", "retained"])
    role = Ash.get!(Role, %{code: "obsolete"}, actor: @system)
    manager = grant(conn, %{"ROLES" => 13})
    {:ok, view, _html} = live(manager.conn, ~p"/admin/roles/#{role.id}/update")
    view |> form("#role-form", form: %{name: "Unsaved role name"}) |> render_change()

    view |> element("#role-form header button[phx-click=request_delete]") |> render_click()
    view |> element("#confirm-delete button[phx-click=cancel_delete]") |> render_click()
    assert has_element?(view, "#role-form input[name='form[name]'][value='Unsaved role name']")
    assert Ash.get!(Role, role.id, actor: @system).name == role.name

    view |> element("#role-form footer button[phx-click=request_delete]") |> render_click()
    render_click(view, "confirm_delete", %{"remove-assignments" => "true"})
    assert has_element?(view, "#confirm-role-removal")
    refute has_element?(view, "#confirm-delete")

    render_click(view, "confirm_delete")
    assert has_element?(view, "#confirm-role-removal")
    assert Ash.get!(User, member.id, actor: @system).roles == ["obsolete", "retained"]

    view |> element("#confirm-role-removal button[phx-click=cancel_delete]") |> render_click()
    refute has_element?(view, "#confirm-role-removal")
    assert has_element?(view, "#role-form input[name='form[name]'][value='Unsaved role name']")
    assert Ash.get!(Role, role.id, actor: @system).name == role.name

    view |> element("#role-form header button[phx-click=request_delete]") |> render_click()
    assert has_element?(view, "#confirm-delete")
    view |> element("#confirm-delete button[phx-click=confirm_delete]") |> render_click()

    assert has_element?(
             view,
             "#confirm-role-removal button[phx-click=confirm_delete][phx-value-remove-assignments=true]"
           )

    assert {:error, {:live_redirect, %{to: "/admin/roles"}}} =
             view
             |> element("#confirm-role-removal button[phx-click=confirm_delete]")
             |> render_click()

    assert Ash.get!(Role, role.id, actor: @system, not_found_error?: false) == nil
    assert Ash.get!(User, member.id, actor: @system).roles == ["retained"]
  end

  test "permission revoked after an entry confirmation prevents deletion", %{conn: conn} do
    target = create_user()
    role = Ash.create!(Role, %{code: "revoked-delete", name: "Keep role"}, actor: @system)

    for {page, resource, record, path, form_id} <- [
          {"USERS", User, target, ~p"/admin/users/#{target.id}/update", "user-form"},
          {"ROLES", Role, role, ~p"/admin/roles/#{role.id}/update", "role-form"}
        ] do
      manager = grant(conn, %{page => 12})
      {:ok, view, _html} = live(manager.conn, path)
      view |> element("##{form_id} header button[phx-click=request_delete]") |> render_click()
      assert has_element?(view, "#confirm-delete")
      Ash.update!(manager.grants[page], %{level: 4}, actor: @system)
      render_click(view, "confirm_delete")
      assert Ash.get!(resource, record.id, actor: @system)
    end
  end

  test "permission revoked before the second entry confirmation preserves role memberships", %{
    conn: conn
  } do
    member = create_user(roles: ["revoked-assigned"])
    role = Ash.get!(Role, %{code: "revoked-assigned"}, actor: @system)
    manager = grant(conn, %{"ROLES" => 12})
    {:ok, view, _html} = live(manager.conn, ~p"/admin/roles/#{role.id}/update")
    view |> element("#role-form footer button[phx-click=request_delete]") |> render_click()
    view |> element("#confirm-delete button[phx-click=confirm_delete]") |> render_click()
    assert has_element?(view, "#confirm-role-removal")
    Ash.update!(manager.grants["ROLES"], %{level: 4}, actor: @system)
    view |> element("#confirm-role-removal button[phx-click=confirm_delete]") |> render_click()
    assert Ash.get!(Role, role.id, actor: @system)
    assert Ash.get!(User, member.id, actor: @system).roles == ["revoked-assigned"]
  end

  test "the superuser role offers no entry Delete and rejects forged deletion", %{conn: conn} do
    role = Ash.create!(Role, %{code: "superuser", name: "Superuser"}, actor: @system)

    other =
      Ash.create!(Role, %{code: "other-protected-target", name: "Other role"}, actor: @system)

    manager = grant(conn, %{"ROLES" => 15})
    {:ok, view, _html} = live(manager.conn, ~p"/admin/roles/#{role.id}/update")
    refute has_element?(view, "#role-form button[phx-click=request_delete]")
    render_click(view, "request_delete", %{"id" => other.id})
    refute has_element?(view, "#confirm-delete")
    refute has_element?(view, "#confirm-role-removal")
    render_click(view, "confirm_delete", %{"remove-assignments" => "true"})
    assert Ash.get!(Role, role.id, actor: @system)
    assert Ash.get!(Role, other.id, actor: @system)
  end

  test "deleting the displayed access role redirects home after removing every assignment", %{
    conn: conn
  } do
    manager = grant(conn, %{"ROLES" => 12})
    member = create_user(roles: [manager.role.code, "retained"])
    {:ok, view, _html} = live(manager.conn, ~p"/admin/roles/#{manager.role.id}/update")
    view |> element("#role-form header button[phx-click=request_delete]") |> render_click()
    view |> element("#confirm-delete button[phx-click=confirm_delete]") |> render_click()
    assert has_element?(view, "#confirm-role-removal")

    result =
      view |> element("#confirm-role-removal button[phx-click=confirm_delete]") |> render_click()

    assert {:error, {:live_redirect, %{to: "/"}}} = result
    assert Ash.get!(Role, manager.role.id, actor: @system, not_found_error?: false) == nil
    assert Ash.get!(User, manager.user.id, actor: @system).roles == []
    assert Ash.get!(User, member.id, actor: @system).roles == ["retained"]
    {:ok, home, _html} = follow_redirect(result, manager.conn, "/")
    refute has_element?(home, "nav a[href='/admin/roles']")
  end

  test "deleting the displayed signed-in account archives it before leaving its update page", %{
    conn: conn
  } do
    manager = grant(conn, %{"USERS" => 12})
    {:ok, view, _html} = live(manager.conn, ~p"/admin/users/#{manager.user.id}/update")
    view |> element("#user-form footer button[phx-click=request_delete]") |> render_click()

    assert {:error, {:live_redirect, %{to: "/admin/users"}}} =
             view |> element("#confirm-delete button[phx-click=confirm_delete]") |> render_click()

    assert Ash.get!(User, manager.user.id, actor: @system, not_found_error?: false) == nil
  end
end

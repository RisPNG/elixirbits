defmodule ElixirbitsWeb.Admin.UserManagementTest do
  use ElixirbitsWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Elixirbits.AccessControl.Role
  alias Elixirbits.AccessControl.RolePerm
  alias Elixirbits.AccessControl.Sitenav
  alias Elixirbits.Accounts.User
  alias Elixirbits.Address

  @system %{system: true}

  setup do
    for {code, path} <- [{"USERS", "admin/users"}, {"ROLES", "admin/roles"}] do
      Ash.create!(Sitenav, %{code: code, name: code, url: path, level: 1}, actor: @system)
    end

    :ok
  end

  defp grant(conn, levels) do
    code = "manager-#{System.unique_integer([:positive])}"
    user = create_user(roles: [code])

    grants =
      Map.new(levels, fn {page, level} ->
        grant =
          Ash.create!(RolePerm, %{roles_code: code, sitenav_code: page, level: level},
            actor: @system
          )

        {page, grant}
      end)

    %{conn: log_in_user(conn, user), user: user, grants: grants}
  end

  test "user creation, update, and deletion controls follow independent permissions", %{
    conn: conn
  } do
    target = create_user(display_name: "Existing account")

    for {level, create?, update?, delete?} <- [
          {4, false, false, false},
          {5, false, true, false},
          {6, true, false, false},
          {12, false, false, true}
        ] do
      manager = grant(conn, %{"USERS" => level})
      {:ok, view, _html} = live(manager.conn, ~p"/admin/users")
      render_async(view)

      assert has_element?(view, "#new-user[href='/admin/users/create']") == create?
      assert has_element?(view, "a[href='/admin/users/#{target.id}/update']") == update?

      assert has_element?(
               view,
               "button[phx-click=request_delete][phx-value-id='#{target.id}']"
             ) == delete?

      if create? do
        {:ok, entry, _html} = live(manager.conn, ~p"/admin/users/create")
        assert has_element?(entry, "#user-form input[name='form[email]']:not([disabled])")
        assert has_element?(entry, "#user-form input[name='form[password]']")
        assert has_element?(entry, "#user-form button[type=submit]")
        refute has_element?(entry, "#user-roles")
      else
        assert {:error, {:redirect, %{to: "/"}}} =
                 live(manager.conn, ~p"/admin/users/create")
      end

      unless delete? do
        html = render_click(view, "request_delete", %{"id" => target.id})
        assert html =~ "do not have permission"
        refute has_element?(view, "#confirm-delete")
        render_click(view, "confirm_delete")
        assert Ash.get!(User, target.id, actor: @system)
      end
    end
  end

  test "a user creator saves credentials and profile details without update permission", %{
    conn: conn
  } do
    manager = grant(conn, %{"USERS" => 6})
    {:ok, view, _html} = live(manager.conn, ~p"/admin/users/create")

    assert {:error, {:live_redirect, %{to: "/admin/users"}}} =
             view
             |> form("#user-form",
               form: %{
                 email: "managed@example.com",
                 password: "created-password",
                 password_confirmation: "created-password",
                 display_name: "Managed account",
                 first_name: "Managed",
                 last_name: "Person",
                 timezone: "Asia/Singapore"
               }
             )
             |> render_submit()

    user = Ash.get!(User, %{email: "managed@example.com"}, actor: @system)
    assert user.display_name == "Managed account"
    assert user.first_name == "Managed"
    assert user.last_name == "Person"
    assert user.timezone == "Asia/Singapore"
    assert user.roles == []
    assert Bcrypt.verify_pass("created-password", user.hashed_password)
  end

  test "invalid credentials keep the creation form open without saving an account", %{conn: conn} do
    manager = grant(conn, %{"USERS" => 6})
    {:ok, view, _html} = live(manager.conn, ~p"/admin/users/create")

    for {email, password, confirmation} <- [
          {"short@example.com", "short", "short"},
          {"mismatch@example.com", "created-password", "different-password"},
          {"invalid-email", "created-password", "created-password"}
        ] do
      view
      |> form("#user-form",
        form: %{email: email, password: password, password_confirmation: confirmation}
      )
      |> render_submit()

      assert has_element?(view, "#user-form button[type=submit]")
      assert has_element?(view, "#user-form .text-error")
      assert Ash.get!(User, %{email: email}, actor: @system, not_found_error?: false) == nil
    end
  end

  test "user deletion can be canceled and archives the confirmed account while refreshing its row",
       %{
         conn: conn
       } do
    target =
      create_user(display_name: "Delete this account", addresses: [%{line_1: "Saved home"}])
      |> Ash.load!(:addresses, actor: @system)

    [address] = target.addresses
    manager = grant(conn, %{"USERS" => 12})
    {:ok, view, _html} = live(manager.conn, ~p"/admin/users")
    render_async(view)

    view
    |> element("button[phx-click=request_delete][phx-value-id='#{target.id}']")
    |> render_click()

    assert has_element?(view, "#confirm-delete", "Delete this account")
    view |> element("#confirm-delete button[phx-click=cancel_delete]") |> render_click()
    refute has_element?(view, "#confirm-delete")
    assert Ash.get!(User, target.id, actor: @system)

    view
    |> element("button[phx-click=request_delete][phx-value-id='#{target.id}']")
    |> render_click()

    view |> element("#confirm-delete button[phx-click=confirm_delete]") |> render_click()
    render_async(view)

    refute has_element?(view, "#confirm-delete")
    refute has_element?(view, "button[phx-click=request_delete][phx-value-id='#{target.id}']")
    assert Ash.get!(User, target.id, actor: @system, not_found_error?: false) == nil
    assert Ash.get!(Address, address.id, actor: @system).user_id == target.id
  end

  test "delete permission revoked after opening confirmation prevents user deletion", %{
    conn: conn
  } do
    target = create_user()
    manager = grant(conn, %{"USERS" => 12})
    {:ok, view, _html} = live(manager.conn, ~p"/admin/users")
    render_async(view)
    render_click(view, "request_delete", %{"id" => target.id})
    assert has_element?(view, "#confirm-delete")

    Ash.update!(manager.grants["USERS"], %{level: 4}, actor: @system)
    assert render_click(view, "confirm_delete") =~ "do not have permission"
    assert Ash.get!(User, target.id, actor: @system)
  end

  test "role deletion confirms assignments and protects the superuser role", %{
    conn: conn
  } do
    removable = Ash.create!(Role, %{code: "removable", name: "Removable role"}, actor: @system)
    assigned_user = create_user(roles: ["assigned"])
    assigned = Ash.get!(Role, %{code: "assigned"}, actor: @system)
    superuser = Ash.create!(Role, %{code: "superuser", name: "Superuser"}, actor: @system)
    manager = grant(conn, %{"ROLES" => 12})
    {:ok, view, _html} = live(manager.conn, ~p"/admin/roles")
    render_async(view)

    refute has_element?(view, "#new-role")
    refute has_element?(view, "a[href='/admin/roles/#{removable.id}/update']")

    view
    |> element("button[phx-click=request_delete][phx-value-id='#{removable.id}']")
    |> render_click()

    view |> element("#confirm-delete button[phx-click=confirm_delete]") |> render_click()
    render_async(view)
    assert Ash.get!(Role, removable.id, actor: @system, not_found_error?: false) == nil
    refute has_element?(view, "button[phx-click=request_delete][phx-value-id='#{removable.id}']")

    render_click(view, "request_delete", %{"id" => assigned.id})
    render_click(view, "confirm_delete")
    assert has_element?(view, "#confirm-role-removal")
    refute has_element?(view, "#confirm-delete")
    assert Ash.get!(Role, assigned.id, actor: @system)
    assert Ash.get!(User, assigned_user.id, actor: @system).roles == ["assigned"]
    render_click(view, "cancel_delete")

    refute has_element?(view, "button[phx-click=request_delete][phx-value-id='#{superuser.id}']")

    assert render_click(view, "request_delete", %{"id" => superuser.id}) =~
             "superuser role cannot be deleted"

    refute has_element?(view, "#confirm-delete")
    render_click(view, "confirm_delete")
    assert Ash.get!(Role, superuser.id, actor: @system)
  end

  test "page-level SU cannot offer or forge a new global superuser assignment", %{conn: conn} do
    target = create_user(display_name: "Original")
    Ash.create!(Role, %{code: "superuser", name: "Superuser"}, actor: @system)
    manager = grant(conn, %{"USERS" => 5, "ROLES" => 16})
    {:ok, view, _html} = live(manager.conn, ~p"/admin/users/#{target.id}/update")

    assert has_element?(view, "#user-form #user-roles")
    refute has_element?(view, "#user-roles option[value=superuser]")

    assert render_submit(view, "save", %{
             "form" => %{"display_name" => "Forged", "roles" => ["superuser"]}
           }) =~ "do not have permission to save these changes"

    unchanged = Ash.get!(User, target.id, actor: @system)
    assert unchanged.roles == []
    assert unchanged.display_name == "Original"
  end

  test "a global superuser can select and assign the superuser role", %{conn: conn} do
    target = create_user()
    editor = create_user(roles: ["superuser"])
    {:ok, view, _html} = live(log_in_user(conn, editor), ~p"/admin/users/#{target.id}/update")

    assert has_element?(view, "#user-roles option[value=superuser]")

    assert {:error, {:live_redirect, %{to: "/admin/users"}}} =
             view
             |> form("#user-form", form: %{display_name: "Promoted", roles: ["superuser"]})
             |> render_submit()

    updated = Ash.get!(User, target.id, actor: @system)
    assert updated.roles == ["superuser"]
    assert updated.display_name == "Promoted"
  end
end

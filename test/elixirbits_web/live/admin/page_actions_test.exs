defmodule ElixirbitsWeb.Admin.PageActionsTest do
  use ElixirbitsWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Elixirbits.AccessControl.Role
  alias Elixirbits.AccessControl.RolePerm
  alias Elixirbits.AccessControl.Sitenav
  alias Elixirbits.Accounts.User
  alias Elixirbits.Organizations

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

  defp grant(conn, levels) do
    code = "page-operator-#{System.unique_integer([:positive])}"
    user = create_user(roles: [code])

    for {page, level} <- levels do
      Ash.create!(RolePerm, %{roles_code: code, sitenav_code: page, level: level}, actor: @system)
    end

    log_in_user(conn, user)
  end

  test "collection creation links appear at both ends only with create access", %{conn: conn} do
    for {page, path, id} <- [
          {"USERS", "/admin/users", "new-user"},
          {"ROLES", "/admin/roles", "new-role"}
        ],
        {level, create?} <- [{4, false}, {6, true}] do
      operator_conn = grant(conn, %{page => level})
      {:ok, view, _html} = live(operator_conn, path)
      document = view |> render_async() |> Floki.parse_document!()
      destination = path <> "/create"

      assert has_element?(view, "header a##{id}[href='#{destination}']") == create?
      assert has_element?(view, "footer a##{id}-bottom[href='#{destination}']") == create?

      if create? do
        assert length(Floki.find(document, "##{id}")) == 1
        assert length(Floki.find(document, "##{id}-bottom")) == 1

        assert {:error, {:live_redirect, %{to: ^destination}}} =
                 view |> element("##{id}-bottom") |> render_click()
      end
    end
  end

  test "bottom user actions submit the shared creation and update forms", %{conn: conn} do
    conn = grant(conn, %{"USERS" => 7})
    {:ok, view, _html} = live(conn, ~p"/admin/users/create")

    for section <- ["header", "footer"] do
      assert has_element?(view, "#user-form #{section} button[type=submit]")
      assert has_element?(view, "#user-form #{section} a[href='/admin/users'][data-tooltip=Back]")
    end

    document = view |> render() |> Floki.parse_document!()
    assert length(Floki.find(document, "#user-form button[type=submit]")) == 2

    view
    |> form("#user-form",
      form: %{
        email: "invalid-email",
        password: "created-password",
        password_confirmation: "created-password"
      }
    )
    |> render_submit()

    assert has_element?(view, "#user-form .text-error")
    assert has_element?(view, "#user-form footer button[type=submit]")

    assert {:error, {:live_redirect, %{to: "/admin/users"}}} =
             view
             |> form("#user-form",
               form: %{
                 email: "bottom-user@example.com",
                 password: "created-password",
                 password_confirmation: "created-password",
                 display_name: "Created from footer"
               }
             )
             |> render_submit()

    user = Ash.get!(User, %{email: "bottom-user@example.com"}, actor: @system)
    assert user.display_name == "Created from footer"
    {:ok, view, _html} = live(conn, ~p"/admin/users/#{user.id}/update")

    for section <- ["header", "footer"] do
      assert has_element?(view, "#user-form #{section} button[type=submit]")
      assert has_element?(view, "#user-form #{section} a[href='/admin/users'][data-tooltip=Back]")
    end

    assert {:error, {:live_redirect, %{to: "/admin/users"}}} =
             view
             |> form("#user-form", form: %{display_name: "Updated from footer"})
             |> render_submit()

    assert Ash.get!(User, user.id, actor: @system).display_name == "Updated from footer"
  end

  test "bottom role actions submit the shared creation and update forms", %{conn: conn} do
    conn = grant(conn, %{"ROLES" => 7})
    {:ok, view, _html} = live(conn, ~p"/admin/roles/create")

    for section <- ["header", "footer"] do
      assert has_element?(view, "#role-form #{section} button[type=submit]")
      assert has_element?(view, "#role-form #{section} a[href='/admin/roles'][data-tooltip=Back]")
    end

    assert {:error, {:live_redirect, %{to: "/admin/roles"}}} =
             view
             |> form("#role-form", form: %{code: "bottom-role", name: "Created from footer"})
             |> render_submit()

    role = Ash.get!(Role, %{code: "bottom-role"}, actor: @system)
    assert role.name == "Created from footer"
    {:ok, view, _html} = live(conn, ~p"/admin/roles/#{role.id}/update")

    for section <- ["header", "footer"] do
      assert has_element?(view, "#role-form #{section} button[type=submit]")
      assert has_element?(view, "#role-form #{section} a[href='/admin/roles'][data-tooltip=Back]")
    end

    assert {:error, {:live_redirect, %{to: "/admin/roles"}}} =
             view
             |> form("#role-form", form: %{name: "Updated from footer"})
             |> render_submit()

    assert Ash.get!(Role, role.id, actor: @system).name == "Updated from footer"
  end

  test "bottom organization actions create and update the same settings", %{conn: conn} do
    conn = grant(conn, %{"ORG" => 7})
    {:ok, view, _html} = live(conn, ~p"/admin/organization")

    for section <- ["header", "footer"] do
      assert has_element?(view, "#organization-form #{section} button[type=submit]")
    end

    html =
      view
      |> form("#organization-form", form: %{name: "Created from footer"})
      |> render_submit()

    assert html =~ "Organization settings saved."
    organization = Organizations.organization_settings!(actor: @system)
    assert organization.name == "Created from footer"

    for section <- ["header", "footer"] do
      assert has_element?(view, "#organization-form #{section} button[type=submit]")
    end

    view
    |> form("#organization-form", form: %{name: "Updated from footer"})
    |> render_submit()

    updated = Organizations.organization_settings!(actor: @system)
    assert updated.id == organization.id
    assert updated.name == "Updated from footer"
  end

  test "read access hides save controls at both ends while retaining form back links", %{
    conn: conn
  } do
    user = create_user()
    role = Ash.create!(Role, %{code: "reader-target", name: "Read only"}, actor: @system)
    Organizations.create_organization!(%{name: "Read only"}, actor: @system)
    conn = grant(conn, %{"USERS" => 4, "ROLES" => 4, "ORG" => 4})

    for {path, form_id, back_path} <- [
          {~p"/admin/users/#{user.id}/update", "user-form", "/admin/users"},
          {~p"/admin/roles/#{role.id}/update", "role-form", "/admin/roles"}
        ] do
      {:ok, view, _html} = live(conn, path)

      for section <- ["header", "footer"] do
        refute has_element?(view, "##{form_id} #{section} button[type=submit]")

        assert has_element?(
                 view,
                 "##{form_id} #{section} a[href='#{back_path}'][data-tooltip=Back]"
               )
      end
    end

    {:ok, view, _html} = live(conn, ~p"/admin/organization")
    refute has_element?(view, "#organization-form header button[type=submit]")
    refute has_element?(view, "#organization-form footer button[type=submit]")
  end
end

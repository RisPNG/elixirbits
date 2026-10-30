defmodule ElixirbitsWeb.Admin.RoleDeletionTest do
  use ElixirbitsWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Elixirbits.AccessControl.Role
  alias Elixirbits.AccessControl.RolePerm
  alias Elixirbits.AccessControl.Sitenav
  alias Elixirbits.Accounts.User

  @system %{system: true}

  setup do
    Ash.create!(Sitenav, %{code: "ROLES", name: "Roles", url: "admin/roles", level: 1},
      actor: @system
    )

    :ok
  end

  defp operator(conn) do
    code = "role-deleter-#{System.unique_integer([:positive])}"
    user = create_user(roles: [code])

    grant =
      Ash.create!(RolePerm, %{roles_code: code, sitenav_code: "ROLES", level: 12}, actor: @system)

    %{
      conn: log_in_user(conn, user),
      user: user,
      role: Ash.get!(Role, %{code: code}, actor: @system),
      grant: grant
    }
  end

  test "canceling either confirmation preserves the role and its assignments", %{conn: conn} do
    member = create_user(roles: ["obsolete", "retained"])
    role = Ash.get!(Role, %{code: "obsolete"}, actor: @system)
    operator = operator(conn)
    {:ok, view, _html} = live(operator.conn, ~p"/admin/roles")
    render_async(view)

    view
    |> element("button[phx-click=request_delete][phx-value-id='#{role.id}']")
    |> render_click()

    assert has_element?(view, "#confirm-delete")
    view |> element("#confirm-delete button[phx-click=cancel_delete]") |> render_click()
    refute has_element?(view, "#confirm-delete")
    assert Ash.get!(Role, role.id, actor: @system)
    assert Ash.get!(User, member.id, actor: @system).roles == ["obsolete", "retained"]

    render_click(view, "request_delete", %{"id" => role.id})
    view |> element("#confirm-delete button[phx-click=confirm_delete]") |> render_click()
    assert has_element?(view, "#confirm-role-removal")
    refute has_element?(view, "#confirm-delete")

    view |> element("#confirm-role-removal button[phx-click=cancel_delete]") |> render_click()
    refute has_element?(view, "#confirm-role-removal")
    assert Ash.get!(Role, role.id, actor: @system)
    assert Ash.get!(User, member.id, actor: @system).roles == ["obsolete", "retained"]

    render_click(view, "request_delete", %{"id" => role.id})
    assert has_element?(view, "#confirm-delete")
    refute has_element?(view, "#confirm-role-removal")
  end

  test "a role delete operator removes confirmed assignments while preserving other roles", %{
    conn: conn
  } do
    first = create_user(roles: ["obsolete", "retained-first"])
    second = create_user(roles: ["retained-second", "obsolete", "retained-first"])
    role = Ash.get!(Role, %{code: "obsolete"}, actor: @system)

    role_grant =
      Ash.create!(RolePerm, %{roles_code: role.code, sitenav_code: "ROLES", level: 4},
        actor: @system
      )

    operator = operator(conn)
    {:ok, view, _html} = live(operator.conn, ~p"/admin/roles")
    render_async(view)
    render_click(view, "request_delete", %{"id" => role.id})
    view |> element("#confirm-delete button[phx-click=confirm_delete]") |> render_click()

    assert has_element?(view, "#confirm-role-removal")
    assert Ash.get!(Role, role.id, actor: @system)
    assert Ash.get!(User, first.id, actor: @system).roles == ["obsolete", "retained-first"]

    view |> element("#confirm-role-removal button[phx-click=confirm_delete]") |> render_click()
    render_async(view)

    refute has_element?(view, "#confirm-role-removal")
    refute has_element?(view, "#confirm-delete")
    refute has_element?(view, "button[phx-click=request_delete][phx-value-id='#{role.id}']")
    assert has_element?(view, "#flash-info", "Role deleted.")
    refute has_element?(view, "#flash-error")
    assert Ash.get!(Role, role.id, actor: @system, not_found_error?: false) == nil
    assert Ash.get!(RolePerm, role_grant.id, actor: @system, not_found_error?: false) == nil
    assert Ash.get!(User, first.id, actor: @system).roles == ["retained-first"]

    assert Ash.get!(User, second.id, actor: @system).roles == [
             "retained-second",
             "retained-first"
           ]
  end

  test "late assignments require the second confirmation and are included in removal", %{
    conn: conn
  } do
    role = Ash.create!(Role, %{code: "late-assignment", name: "Late assignment"}, actor: @system)
    first = create_user(roles: ["retained"])
    operator = operator(conn)
    {:ok, view, _html} = live(operator.conn, ~p"/admin/roles")
    render_async(view)
    render_click(view, "request_delete", %{"id" => role.id})

    Ash.update!(first, %{roles: [role.code, "retained"]}, action: :assign_roles, actor: @system)

    render_click(view, "confirm_delete", %{"remove-assignments" => "true"})
    assert has_element?(view, "#confirm-role-removal")

    render_click(view, "confirm_delete")
    assert has_element?(view, "#confirm-role-removal")
    assert Ash.get!(Role, role.id, actor: @system)
    assert Ash.get!(User, first.id, actor: @system).roles == [role.code, "retained"]

    second = create_user(roles: [role.code])
    view |> element("#confirm-role-removal button[phx-click=confirm_delete]") |> render_click()
    render_async(view)

    assert Ash.get!(Role, role.id, actor: @system, not_found_error?: false) == nil
    assert Ash.get!(User, first.id, actor: @system).roles == ["retained"]
    assert Ash.get!(User, second.id, actor: @system).roles == []
  end

  test "delete permission revoked before the second confirmation preserves every assignment", %{
    conn: conn
  } do
    member = create_user(roles: ["obsolete"])
    role = Ash.get!(Role, %{code: "obsolete"}, actor: @system)
    operator = operator(conn)
    {:ok, view, _html} = live(operator.conn, ~p"/admin/roles")
    render_async(view)
    render_click(view, "request_delete", %{"id" => role.id})
    view |> element("#confirm-delete button[phx-click=confirm_delete]") |> render_click()
    assert has_element?(view, "#confirm-role-removal")

    Ash.update!(operator.grant, %{level: 4}, actor: @system)

    html =
      view |> element("#confirm-role-removal button[phx-click=confirm_delete]") |> render_click()

    assert html =~ "do not have permission"
    assert Ash.get!(Role, role.id, actor: @system)
    assert Ash.get!(User, member.id, actor: @system).roles == ["obsolete"]
  end

  test "deleting the editor's only access role removes all assignments before leaving the page",
       %{
         conn: conn
       } do
    operator = operator(conn)
    member = create_user(roles: [operator.role.code, "retained"])
    {:ok, view, _html} = live(operator.conn, ~p"/admin/roles")
    render_async(view)
    render_click(view, "request_delete", %{"id" => operator.role.id})
    view |> element("#confirm-delete button[phx-click=confirm_delete]") |> render_click()
    assert has_element?(view, "#confirm-role-removal")

    result =
      view |> element("#confirm-role-removal button[phx-click=confirm_delete]") |> render_click()

    assert {:error, {:live_redirect, %{to: "/"}}} = result
    assert Ash.get!(Role, operator.role.id, actor: @system, not_found_error?: false) == nil
    assert Ash.get!(User, operator.user.id, actor: @system).roles == []
    assert Ash.get!(User, member.id, actor: @system).roles == ["retained"]

    {:ok, home, _html} = follow_redirect(result, operator.conn, "/")
    refute has_element?(home, "nav a[href='/admin/roles']")
  end
end

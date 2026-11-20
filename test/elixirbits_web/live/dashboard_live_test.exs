defmodule ElixirbitsWeb.DashboardLiveTest do
  use ElixirbitsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "dashboard renders its workspace and navigation without an account", %{conn: conn} do
    for path <- ["/dashboard", "/dashboard/"] do
      document = conn |> get(path) |> html_response(200) |> Floki.parse_document!()

      assert Floki.text(Floki.find(document, "main h1")) =~ "Elixirbits"
      assert [_] = Floki.find(document, "aside#app-navigation")
      assert [_] = Floki.find(document, "dialog#compact-navigation:not([open])")

      assert [_] =
               Floki.find(document, "#app-navigation a[href='/dashboard'][aria-current='page']")

      assert Floki.text(Floki.find(document, "main")) =~ "Workspace sections"
      assert [_] = Floki.find(document, "main a[href='/dashboard/dev_panel/design_standards']")
      assert Floki.find(document, "#account-menu") == []
      assert Floki.find(document, "a[href='/dashboard/sign-in']") == []
      assert Floki.find(document, "a[href='/dashboard/admin/users']") == []
    end
  end

  test "compact home groups the workspace shortcuts and returns to the expanded layout", %{
    conn: conn
  } do
    conn = put_connect_params(conn, %{"compact_layout" => true})
    {:ok, view, _html} = live(conn, ~p"/dashboard")

    assert has_element?(view, "#dashboard-home[data-dashboard-layout=compact]")
    assert has_element?(view, "#dashboard-home-group-DP h2", "Components")

    assert has_element?(
             view,
             "#dashboard-home-group-DP a[href='/dashboard/dev_panel/design_standards']",
             "Design Standards"
           )

    render_click(view, "dashboard_layout", %{"compact" => false})

    assert has_element?(
             view,
             "#dashboard-home[data-dashboard-layout=expanded] h2",
             "Workspace sections"
           )

    refute has_element?(view, "#dashboard-home-launcher")
  end

  test "dashboard and showcase links navigate in the same LiveView session", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/dashboard")

    result =
      view |> element("main a[href='/dashboard/dev_panel/design_standards']") |> render_click()

    assert {:error, {:live_redirect, %{to: "/dashboard/dev_panel/design_standards"}}} = result

    {:ok, showcase, _html} =
      follow_redirect(result, conn, ~p"/dashboard/dev_panel/design_standards")

    assert has_element?(showcase, "#app-navigation a[aria-current=page]", "Design Standards")
    assert has_element?(showcase, "main h1", "Design Standards")

    result =
      showcase
      |> element(".dashboard-expanded-header a[data-page-chrome=brand]")
      |> render_click()

    assert {:error, {:live_redirect, %{to: "/dashboard"}}} = result
    {:ok, home, _html} = follow_redirect(result, conn, ~p"/dashboard")

    assert has_element?(home, "#app-navigation a[aria-current=page]", "Home")
    assert has_element?(home, "main h1", "Elixirbits")
  end

  test "account and administration routes are absent", %{conn: conn} do
    for path <- [
          "/dashboard/sign-in",
          "/dashboard/sign-out",
          "/dashboard/register",
          "/dashboard/reset",
          "/dashboard/password-reset/token",
          "/dashboard/magic_link/token",
          "/dashboard/confirm_new_user/token",
          "/dashboard/admin",
          "/dashboard/admin/users",
          "/dashboard/admin/users/create",
          "/dashboard/admin/users/id/read",
          "/dashboard/admin/users/id/update",
          "/dashboard/admin/roles",
          "/dashboard/admin/roles/create",
          "/dashboard/admin/roles/id/read",
          "/dashboard/admin/roles/id/update",
          "/dashboard/admin/organization",
          "/dashboard/admin/organization/update"
        ] do
      assert conn |> get(path) |> response(404)
    end

    assert conn |> post("/dashboard/auth/user/password/sign_in", %{}) |> response(404)
  end
end

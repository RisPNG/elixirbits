defmodule ElixirbitsWeb.DashboardLiveTest do
  use ElixirbitsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "dashboard renders inside the app layout", %{conn: conn} do
    conn = get(conn, ~p"/dashboard")

    document = conn |> html_response(200) |> Floki.parse_document!()
    assert [_] = Floki.find(document, "main h1")
    assert Floki.text(Floki.find(document, "main h1")) =~ "Elixirbits"
  end

  test "signed-in dashboard keeps its navigation and account controls", %{conn: conn} do
    user = create_user(roles: ["superuser"])

    Ash.create!(
      Elixirbits.AccessControl.Sitenav,
      %{code: "HOME", name: "Home", url: "dashboard", level: 1, roles_bypass: ["public"]},
      actor: %{system: true}
    )

    for path <- ["/dashboard", "/dashboard/"] do
      document =
        conn
        |> log_in_user(user)
        |> get(path)
        |> html_response(200)
        |> Floki.parse_document!()

      assert [_] = Floki.find(document, "aside#app-navigation")
      assert [_] = Floki.find(document, "#account-menu")
      assert [_] = Floki.find(document, "dialog#compact-navigation:not([open])")
      assert [_] = Floki.find(document, "#compact-navigation #compact-timezone-form")

      assert [_] =
               Floki.find(document, "#app-navigation a[href='/dashboard'][aria-current='page']")

      assert [_] =
               Floki.find(
                 document,
                 "#compact-navigation a[href='/dashboard'][aria-current='page']"
               )

      assert Floki.text(Floki.find(document, "main")) =~ "Your account"
    end
  end

  test "compact home groups accessible shortcuts and switches back to the expanded workspace", %{
    conn: conn
  } do
    user = create_user(display_name: "Launcher User")

    for entry <- [
          %{code: "ADMIN", name: "Administration", level: 1, sequence: 100},
          %{
            code: "USERS",
            name: "Users",
            parent: "ADMIN",
            url: "dashboard/admin/users",
            level: 2,
            sequence: 110,
            roles_bypass: ["public"]
          },
          %{
            code: "ROLES",
            name: "Roles",
            parent: "ADMIN",
            url: "dashboard/admin/roles",
            level: 2,
            sequence: 120
          },
          %{code: "DP", name: "Components", level: 1, sequence: 1000},
          %{
            code: "LT",
            name: "Design Standards",
            parent: "DP",
            url: "dashboard/dev_panel/design_standards",
            level: 2,
            sequence: 1010,
            roles_bypass: ["public"]
          }
        ] do
      Ash.create!(Elixirbits.AccessControl.Sitenav, entry, actor: %{system: true})
    end

    conn = conn |> log_in_user(user) |> put_connect_params(%{"compact_layout" => true})
    {:ok, home, _html} = live(conn, ~p"/dashboard")

    assert has_element?(home, "#dashboard-home[data-dashboard-layout=compact]")
    assert has_element?(home, "#dashboard-home-group-ADMIN h2", "Administration")

    assert has_element?(
             home,
             "#dashboard-home-group-ADMIN a[href='/dashboard/admin/users']",
             "Users"
           )

    assert has_element?(home, "#dashboard-home-group-DP h2", "Components")

    assert has_element?(
             home,
             "#dashboard-home-group-DP a[href='/dashboard/dev_panel/design_standards']",
             "Design Standards"
           )

    refute has_element?(home, "#dashboard-home-launcher a[href='/dashboard/admin/roles']")
    assert has_element?(home, "#dashboard-home details:not([open]) summary", "Your account")
    assert has_element?(home, "#dashboard-home details:not([open])", "Launcher User")

    render_click(home, "dashboard_layout", %{"compact" => false})

    assert has_element?(
             home,
             "#dashboard-home[data-dashboard-layout=expanded] h2",
             "Workspace sections"
           )

    assert has_element?(home, "#dashboard-home a[href='/dashboard/admin/users']", "Users")
    refute has_element?(home, "#dashboard-home-launcher")
  end

  test "guest navigation opens sign in and returns home through LiveView", %{conn: conn} do
    {:ok, home, _html} = live(conn, ~p"/dashboard")

    sign_in_link = home |> element("main a[href='/dashboard/sign-in']") |> render_click()
    assert {:error, {:live_redirect, %{to: "/dashboard/sign-in"}}} = sign_in_link

    {:ok, sign_in, _html} = follow_redirect(sign_in_link, conn, ~p"/dashboard/sign-in")
    assert has_element?(sign_in, "#login-form")
    refute has_element?(sign_in, "#app-navigation")

    home_link =
      sign_in |> element(".dashboard-compact-header a[href='/dashboard']") |> render_click()

    assert {:error, {:live_redirect, %{to: "/dashboard"}}} = home_link

    {:ok, home, _html} = follow_redirect(home_link, conn, ~p"/dashboard")
    assert has_element?(home, "main a[href='/dashboard/sign-in']")
  end
end

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

      assert [_] =
               Floki.find(document, "#app-navigation a[href='/dashboard'][aria-current='page']")

      assert Floki.text(Floki.find(document, "main")) =~ "Your account"
    end
  end

  test "guest navigation opens sign in and returns home through LiveView", %{conn: conn} do
    {:ok, home, _html} = live(conn, ~p"/dashboard")

    sign_in_link = home |> element("main a[href='/dashboard/sign-in']") |> render_click()
    assert {:error, {:live_redirect, %{to: "/dashboard/sign-in"}}} = sign_in_link

    {:ok, sign_in, _html} = follow_redirect(sign_in_link, conn, ~p"/dashboard/sign-in")
    assert has_element?(sign_in, "#login-form")
    refute has_element?(sign_in, "#app-navigation")

    home_link = sign_in |> element("header a[href='/dashboard']") |> render_click()
    assert {:error, {:live_redirect, %{to: "/dashboard"}}} = home_link

    {:ok, home, _html} = follow_redirect(home_link, conn, ~p"/dashboard")
    assert has_element?(home, "main a[href='/dashboard/sign-in']")
  end
end

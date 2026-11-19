defmodule ElixirbitsWeb.NavigationIconsTest do
  use ElixirbitsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "navigation retains the Home and Components icons", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/dashboard")

    assert has_element?(view, "#app-navigation a[href='/dashboard'] .hero-home")

    assert has_element?(
             view,
             "#app-navigation button[phx-value-code=DP] .hero-squares-2x2"
           )

    assert has_element?(view, "#app-navigation button[phx-value-code=DP][aria-expanded=false]")

    view |> element("#app-navigation button[aria-label='Components']") |> render_click()

    assert has_element?(
             view,
             "#nav-DP[data-open=true]:not([inert]) a[href='/dashboard/dev_panel/layout_test']"
           )

    refute has_element?(
             view,
             "#app-navigation a[href='/dashboard/dev_panel/layout_test'] span[class^=hero-]"
           )
  end

  test "the compact navigation keeps groups visible and expands their sections", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/dashboard")

    view |> element("button[phx-click=toggle_nav]") |> render_click()
    assert has_element?(view, "button[phx-click=toggle_nav][aria-expanded=false]")
    assert has_element?(view, "#app-navigation a[aria-label=Home] .hero-home")
    assert has_element?(view, "[data-navigation=compact] button[phx-value-code=DP]")
    assert has_element?(view, "#nav-DP[inert]")

    view |> element("#app-navigation button[aria-label='Components']") |> render_click()
    assert has_element?(view, "button[phx-click=toggle_nav][aria-expanded=true]")

    assert has_element?(
             view,
             "[data-navigation=expanded][data-nav-staged=true] #nav-DP[data-open=true]"
           )
  end

  test "direct showcase navigation expands its active parent", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/dashboard/dev_panel/layout_test")

    assert has_element?(view, "#app-navigation button[phx-value-code=DP][aria-expanded=true]")

    assert has_element?(
             view,
             "#app-navigation a[href='/dashboard/dev_panel/layout_test'][aria-current=page]"
           )

    view |> element("#app-navigation button[aria-label='Components']") |> render_click()
    assert has_element?(view, "#nav-DP[data-open=false][inert]")
    assert has_element?(view, ".nav-group-highlight > button[phx-value-code=DP]")
  end

  test "the active branch stays visible when the browser requests a compact rail", %{conn: conn} do
    conn = put_connect_params(conn, %{"nav_open" => false})
    {:ok, view, _html} = live(conn, ~p"/dashboard/dev_panel/layout_test")

    assert has_element?(
             view,
             "[data-navigation=compact] .nav-group-highlight > button[phx-value-code=DP]"
           )

    assert has_element?(view, "#nav-DP[inert]")

    view |> element("button[phx-click=toggle_nav]") |> render_click()

    assert has_element?(
             view,
             "[data-navigation=expanded][data-nav-staged=true] #nav-DP[data-open=true]"
           )
  end
end

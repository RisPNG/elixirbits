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
             "#nav-DP[data-open=true]:not([inert]) a[href='/dashboard/dev_panel/design_standards']"
           )

    refute has_element?(
             view,
             "#app-navigation a[href='/dashboard/dev_panel/design_standards'] span[class^=hero-]"
           )
  end

  test "the collapsed rail keeps groups visible and expands their sections", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/dashboard")

    view |> element("button[phx-click=toggle_nav]") |> render_click()
    assert has_element?(view, "button[phx-click=toggle_nav][aria-expanded=false]")
    assert has_element?(view, "#app-navigation a[aria-label=Home] .hero-home")
    assert has_element?(view, "[data-navigation=collapsed] button[phx-value-code=DP]")
    assert has_element?(view, "#nav-DP[inert]")

    view |> element("#app-navigation button[aria-label='Components']") |> render_click()
    assert has_element?(view, "button[phx-click=toggle_nav][aria-expanded=true]")

    assert has_element?(
             view,
             "[data-navigation=expanded][data-nav-staged=true] #nav-DP[data-open=true]"
           )
  end

  test "compact navigation opens groups independently of the expanded rail", %{conn: conn} do
    conn = put_connect_params(conn, %{"compact_layout" => true, "nav_open" => false})
    {:ok, view, _html} = live(conn, ~p"/dashboard")

    assert has_element?(view, "#compact-navigation a[href='/dashboard'] .hero-home")
    assert has_element?(view, "#compact-navigation #compact-nav-DP[inert]")

    view |> element("#compact-navigation button[aria-controls=compact-nav-DP]") |> render_click()

    assert has_element?(
             view,
             "#compact-nav-DP[data-open=true]:not([inert]) a[href='/dashboard/dev_panel/design_standards']"
           )

    assert has_element?(view, "[data-navigation=collapsed] #nav-DP[inert]")
  end

  test "direct showcase navigation expands its active parent", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/dashboard/dev_panel/design_standards")

    assert has_element?(view, "#app-navigation button[phx-value-code=DP][aria-expanded=true]")

    assert has_element?(
             view,
             "#app-navigation a[href='/dashboard/dev_panel/design_standards'][aria-current=page]"
           )

    view |> element("#app-navigation button[aria-label='Components']") |> render_click()
    assert has_element?(view, "#nav-DP[data-open=false][inert]")
    assert has_element?(view, ".nav-group-highlight > button[phx-value-code=DP]")
  end

  test "the active branch stays visible when the browser requests a collapsed rail", %{conn: conn} do
    conn = put_connect_params(conn, %{"nav_open" => false})
    {:ok, view, _html} = live(conn, ~p"/dashboard/dev_panel/design_standards")

    assert has_element?(
             view,
             "[data-navigation=collapsed] .nav-group-highlight > button[phx-value-code=DP]"
           )

    assert has_element?(view, "#nav-DP[inert]")

    view |> element("button[phx-click=toggle_nav]") |> render_click()

    assert has_element?(
             view,
             "[data-navigation=expanded][data-nav-staged=true] #nav-DP[data-open=true]"
           )
  end
end

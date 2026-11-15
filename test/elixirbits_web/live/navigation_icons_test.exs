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

    view |> element("#app-navigation button[aria-label='Toggle Components']") |> render_click()

    assert has_element?(view, "#app-navigation a[href='/dashboard/dev_panel/layout_test']")

    refute has_element?(
             view,
             "#app-navigation a[href='/dashboard/dev_panel/layout_test'] span[class^=hero-]"
           )
  end

  test "the collapsed navigation keeps the Home icon and restores its sections", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/dashboard")

    view |> element("button[phx-click=toggle_nav]") |> render_click()
    assert has_element?(view, "button[phx-click=toggle_nav][aria-expanded=false]")
    assert has_element?(view, "#app-navigation a[aria-label=Home] .hero-home")
    refute has_element?(view, "#app-navigation button[phx-value-code=DP]")

    view |> element("button[phx-click=toggle_nav]") |> render_click()
    assert has_element?(view, "button[phx-click=toggle_nav][aria-expanded=true]")
    assert has_element?(view, "#app-navigation button[phx-value-code=DP]")
  end

  test "direct showcase navigation expands its active parent", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/dashboard/dev_panel/layout_test")

    assert has_element?(view, "#app-navigation button[phx-value-code=DP][aria-expanded=true]")

    assert has_element?(
             view,
             "#app-navigation a[href='/dashboard/dev_panel/layout_test'][aria-current=page]"
           )

    view |> element("#app-navigation button[aria-label='Toggle Components']") |> render_click()
    refute has_element?(view, "#nav-DP")
  end
end

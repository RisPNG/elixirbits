defmodule ElixirbitsWeb.UserTimezoneTest do
  use ElixirbitsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "the initial HTTP render uses UTC before browser connection", %{conn: conn} do
    document = conn |> get(~p"/dashboard") |> html_response(200) |> Floki.parse_document!()
    assert [_] = Floki.find(document, "[data-user-timezone='Etc/UTC']")
  end

  test "visitors use their browser timezone throughout the dashboard", %{conn: conn} do
    conn = put_connect_params(conn, %{"user_timezone" => "America/New_York"})
    {:ok, view, _html} = live(conn, ~p"/dashboard")

    assert has_element?(view, "[data-user-timezone='America/New_York']")
    assert has_element?(view, "main", "America/New_York")
    view |> element("button[phx-click=toggle_nav]") |> render_click()
    assert has_element?(view, "[data-user-timezone='America/New_York']")
    refute has_element?(view, "#user-timezone-form")
    refute has_element?(view, "#account-menu")
  end

  test "missing or invalid browser timezones use UTC", %{conn: conn} do
    for params <- [%{}, %{"user_timezone" => "Unknown/Zone"}, %{"user_timezone" => 42}] do
      {:ok, view, _html} = conn |> put_connect_params(params) |> live(~p"/dashboard")
      assert has_element?(view, "[data-user-timezone='Etc/UTC']")
    end
  end

  test "the component showcase receives the shared browser timezone", %{conn: conn} do
    conn = put_connect_params(conn, %{"user_timezone" => "Asia/Singapore"})
    {:ok, view, _html} = live(conn, ~p"/dashboard/dev_panel/layout_test")
    assert has_element?(view, "[data-user-timezone='Asia/Singapore']")
    assert has_element?(view, "#app-navigation")
  end
end

defmodule ElixirbitsWeb.PageControllerTest do
  use ElixirbitsWeb.ConnCase, async: true

  test "home renders inside the app layout", %{conn: conn} do
    conn = get(conn, ~p"/")

    assert html_response(conn, 200) =~ ~s(<main class="px-4 py-20)
  end
end

defmodule ElixirbitsWeb.HomeLiveTest do
  use ElixirbitsWeb.ConnCase, async: true

  test "home renders inside the app layout", %{conn: conn} do
    conn = get(conn, ~p"/")

    document = conn |> html_response(200) |> Floki.parse_document!()
    assert [_] = Floki.find(document, "main h1")
    assert Floki.text(Floki.find(document, "main h1")) =~ "Elixirbits"
  end
end

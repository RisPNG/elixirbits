defmodule ElixirbitsWeb.IndexLiveTest do
  use ElixirbitsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Elixirbits.Organizations.OrganizationService

  test "public home is blank for guests and signed-in visitors", %{conn: conn} do
    user = create_user(roles: ["superuser"])

    for visitor_conn <- [conn, log_in_user(conn, user)] do
      {:ok, view, html} = live(visitor_conn, ~p"/")
      document = Floki.parse_document!(html)

      assert document |> Floki.find("title") |> Floki.text() |> String.trim() == "Elixirbits"
      assert document |> Floki.find("body") |> Floki.text() |> String.trim() == ""
      assert render(view) |> Floki.parse_fragment!() |> Floki.find("[data-phx-main] *") == []
    end
  end

  test "public home stays blank when an organization is configured", %{conn: conn} do
    OrganizationService.create_organization!(%{name: "Elixirbits Studio"}, actor: %{system: true})
    user = create_user()

    for visitor_conn <- [conn, log_in_user(conn, user)] do
      {:ok, view, html} = live(visitor_conn, ~p"/")
      document = Floki.parse_document!(html)

      assert document |> Floki.find("body") |> Floki.text() |> String.trim() == ""
      assert render(view) |> Floki.parse_fragment!() |> Floki.find("[data-phx-main] *") == []
    end
  end
end

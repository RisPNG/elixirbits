defmodule ElixirbitsWeb.ApiDocumentationTest do
  use ElixirbitsWeb.ConnCase, async: true

  test "Scalar serves browser navigation and loads the generated specification", %{conn: conn} do
    conn =
      conn
      |> put_req_header("accept", "text/html")
      |> get("/api/json/scalar")

    document = conn |> html_response(200) |> Floki.parse_document!()

    assert document |> Floki.find("title") |> Floki.text() == "Elixirbits API"

    assert Floki.attribute(document, "script#api-reference", "data-url") == [
             "/api/json/open_api"
           ]

    [configuration] = Floki.attribute(document, "script#api-reference", "data-configuration")
    assert Jason.decode!(configuration) == %{}
    assert length(Floki.find(document, "script[src]")) == 1
  end

  test "OpenAPI remains available as the Ash-generated contract", %{conn: conn} do
    conn =
      conn
      |> put_req_header("accept", "application/json")
      |> get("/api/json/open_api")

    specification = conn |> response(200) |> Jason.decode!()

    expected =
      [
        domains: ElixirbitsWeb.AshJsonApiRouter.domains(),
        prefix: "/api/json",
        phoenix_endpoint: ElixirbitsWeb.Endpoint
      ]
      |> AshJsonApi.OpenApi.spec()
      |> Jason.encode!()
      |> Jason.decode!()

    assert specification == expected
    assert specification["openapi"] == "3.0.0"
  end

  test "unmatched Scalar paths pass through to the API router", %{conn: conn} do
    for path <- ["/api/json/scalar/", "/api/json/scalar/not-found"] do
      conn =
        conn
        |> put_req_header("accept", "application/json")
        |> get(path)

      assert response(conn, 404)
    end
  end
end

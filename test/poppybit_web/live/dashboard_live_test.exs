defmodule PoppybitWeb.DashboardLiveTest do
  use PoppybitWeb.ConnCase, async: true

  test "dashboard renders inside the app layout", %{conn: conn} do
    conn = get(conn, ~p"/dashboard")

    document = conn |> html_response(200) |> Floki.parse_document!()
    assert [_] = Floki.find(document, "main h1")
    assert Floki.text(Floki.find(document, "main h1")) =~ "Poppybit"
  end

  test "signed-in dashboard keeps its navigation and account controls", %{conn: conn} do
    user = create_user(roles: ["superuser"])

    Ash.create!(
      Poppybit.AccessControl.Sitenav,
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
end

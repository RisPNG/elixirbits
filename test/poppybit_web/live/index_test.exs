defmodule PoppybitWeb.IndexLiveTest do
  use PoppybitWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Poppybit.Organizations.OrganizationService

  test "public home has the same navigation for guests and signed-in visitors", %{conn: conn} do
    user = create_user(roles: ["superuser"])

    for visitor_conn <- [conn, log_in_user(conn, user)] do
      {:ok, view, html} = live(visitor_conn, ~p"/")
      document = Floki.parse_document!(html)

      assert has_element?(view, "header nav a[href='/'][aria-current='page']", "Home")
      assert [home_link] = Floki.find(document, "header nav a")
      assert Floki.attribute([home_link], "href") == ["/"]
      assert home_link |> Floki.text() |> String.trim() == "Home"
      assert [_] = Floki.find(document, "header img[src='/images/poppybit.png']")
      assert Floki.text(Floki.find(document, "header")) =~ "Poppybit"

      for theme <- ["system", "light", "dark"] do
        assert [_] = Floki.find(document, "header button[data-phx-theme='#{theme}']")
      end

      assert Floki.find(document, "aside, #app-navigation, #account-menu, #user-timezone-form") ==
               []

      assert Floki.find(document, "button[aria-label='Open account menu']") == []

      assert Floki.find(
               document,
               "a[href='/dashboard/sign-in'], a[href='/dashboard/sign-out']"
             ) == []
    end
  end

  test "public home displays the configured organization name", %{conn: conn} do
    OrganizationService.create_organization!(%{name: "Poppybit Studio"}, actor: %{system: true})
    user = create_user()

    for visitor_conn <- [conn, log_in_user(conn, user)] do
      {:ok, view, html} = live(visitor_conn, ~p"/")
      document = Floki.parse_document!(html)

      assert has_element?(view, "header nav a[href='/'][aria-current='page']", "Home")
      assert Floki.text(Floki.find(document, "header")) =~ "Poppybit Studio"
    end
  end
end

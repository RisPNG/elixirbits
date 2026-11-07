defmodule PoppybitWeb.Dashboard.LoginLive.ConfirmTest do
  use PoppybitWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "renders the confirm form bound to the token from the URL", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/dashboard/confirm_new_user/some-token")

    assert has_element?(
             view,
             "#confirm-form[action=\"/dashboard/auth/user/confirm_new_user\"][novalidate]"
           )

    assert has_element?(view, "#confirm-form input[name=\"confirm\"][value=\"some-token\"]")
    assert has_element?(view, "#confirm-form button[type=\"submit\"]")
  end
end

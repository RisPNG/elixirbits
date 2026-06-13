defmodule ElixirbitsWeb.LoginLive.ConfirmTest do
  use ElixirbitsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "renders the confirm form bound to the token from the url", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/confirm_new_user/some-token")

    assert has_element?(view, "#confirm-form[action=\"/auth/user/confirm_new_user\"]")
    assert has_element?(view, "#confirm-form input[name=\"confirm\"][value=\"some-token\"]")
    assert has_element?(view, "#confirm-form button[type=\"submit\"]")
  end
end

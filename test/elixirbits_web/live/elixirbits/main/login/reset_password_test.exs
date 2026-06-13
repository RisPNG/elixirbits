defmodule ElixirbitsWeb.LoginLive.ResetPasswordTest do
  use ElixirbitsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "renders the reset form bound to the token from the url", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/password-reset/some-token")

    assert has_element?(view, "#reset-password-form[action=\"/auth/user/password/reset\"]")

    assert has_element?(
             view,
             "#reset-password-form input[name=\"user[reset_token]\"][value=\"some-token\"]"
           )

    assert has_element?(
             view,
             "#reset-password-form input[name=\"user[password]\"][type=\"password\"]"
           )

    assert has_element?(
             view,
             "#reset-password-form input[name=\"user[password_confirmation]\"][type=\"password\"]"
           )

    assert has_element?(view, "a[href=\"/reset\"]")
  end
end

defmodule ElixirbitsWeb.LoginLive.ResetPasswordTest do
  use ElixirbitsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "renders the reset form bound to the token from the URL", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/password-reset/some-token")

    assert has_element?(
             view,
             "#reset-password-form[action=\"/auth/user/password/reset\"][novalidate]"
           )

    assert has_element?(
             view,
             "#reset-password-form input[name=\"user[reset_token]\"][value=\"some-token\"]"
           )

    assert has_element?(
             view,
             "#reset-password-form input[name=\"user[password]\"][type=\"password\"][required]"
           )

    assert has_element?(
             view,
             "#reset-password-form input[name=\"user[password_confirmation]\"][type=\"password\"][required]"
           )

    assert has_element?(view, "a[href=\"/reset\"]")
  end

  test "blank reset passwords return application errors without posting", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/password-reset/some-token")

    html =
      view
      |> form("#reset-password-form", user: %{password: "", password_confirmation: ""})
      |> render_submit()

    assert html =~ "is required"
    refute has_element?(view, "#reset-password-form[phx-trigger-action=\"true\"]")
  end
end

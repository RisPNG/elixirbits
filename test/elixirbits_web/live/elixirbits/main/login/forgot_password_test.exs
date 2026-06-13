defmodule ElixirbitsWeb.LoginLive.ForgotPasswordTest do
  use ElixirbitsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "renders the request form with key elements", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/reset")

    assert has_element?(view, "#forgot-password-form")
    assert has_element?(view, "#forgot-password-form input[name=\"user[email]\"][type=\"email\"]")
    assert has_element?(view, "a[href=\"/sign-in\"]")
  end

  test "always responds with a generic message, even for unknown emails", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/reset")

    view
    |> form("#forgot-password-form",
      user: %{email: "unknown-#{System.unique_integer([:positive])}@example.com"}
    )
    |> render_submit()

    flash = assert_redirect(view, ~p"/sign-in")
    assert flash["info"] =~ "If an account exists for that email"
  end
end

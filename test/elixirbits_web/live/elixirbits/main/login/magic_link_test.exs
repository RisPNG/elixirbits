defmodule ElixirbitsWeb.LoginLive.MagicLinkTest do
  use ElixirbitsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "renders the magic link form bound to the token from the url", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/magic_link/some-token")

    assert has_element?(view, "#magic-link-form[action=\"/auth/user/magic_link\"]")

    assert has_element?(
             view,
             "#magic-link-form input[name=\"user[token]\"][value=\"some-token\"]"
           )

    assert has_element?(
             view,
             "#magic-link-form input[name=\"user[remember_me]\"][type=\"checkbox\"]"
           )

    assert has_element?(view, "#magic-link-form button[type=\"submit\"]")
  end
end

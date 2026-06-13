defmodule ElixirbitsWeb.LoginLive.RegisterTest do
  use ElixirbitsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "renders the registration form with key elements", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/register")

    assert has_element?(view, "#register-form[action=\"/auth/user/password/register\"]")
    assert has_element?(view, "#register-form input[name=\"user[email]\"][type=\"email\"]")
    assert has_element?(view, "#register-form input[name=\"user[password]\"][type=\"password\"]")

    assert has_element?(
             view,
             "#register-form input[name=\"user[password_confirmation]\"][type=\"password\"]"
           )

    assert has_element?(view, "a[href=\"/sign-in\"]")
  end

  test "triggers the post action when the form is valid", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/register")

    html =
      view
      |> form("#register-form",
        user: %{
          email: "register-#{System.unique_integer([:positive])}@example.com",
          password: "password1234",
          password_confirmation: "password1234"
        }
      )
      |> render_submit()

    assert html =~ "phx-trigger-action"
  end

  test "registers and signs in through the auth endpoint", %{conn: conn} do
    email = "register-post-#{System.unique_integer([:positive])}@example.com"

    conn =
      post(conn, ~p"/auth/user/password/register", %{
        "user" => %{
          "email" => email,
          "password" => "password1234",
          "password_confirmation" => "password1234"
        }
      })

    assert redirected_to(conn) == ~p"/"
    assert get_session(conn, "user_token")
    assert get_session(conn, :remember_me) == false
  end
end

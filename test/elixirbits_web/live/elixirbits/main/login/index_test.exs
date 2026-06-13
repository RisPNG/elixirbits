defmodule ElixirbitsWeb.LoginLive.IndexTest do
  use ElixirbitsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "renders the sign in form with key elements", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/sign-in")

    assert has_element?(view, "#login-form")
    assert has_element?(view, "#login-form input[name=\"user[email]\"][type=\"email\"]")
    assert has_element?(view, "#login-form input[name=\"user[password]\"][type=\"password\"]")
    assert has_element?(view, "#login-form input[name=\"user[remember_me]\"][type=\"checkbox\"]")
    assert has_element?(view, "button[phx-click=\"request_magic_link\"]")
    assert has_element?(view, "a[href=\"/reset\"]")
    assert has_element?(view, "a[href=\"/register\"]")
  end

  test "signs in with valid credentials and forwards remember me", %{conn: conn} do
    email = "signin-#{System.unique_integer([:positive])}@example.com"

    Elixirbits.Accounts.User
    |> Ash.Changeset.for_create(
      :register_with_password,
      %{email: email, password: "password1234", password_confirmation: "password1234"},
      context: %{private: %{ash_authentication?: true}}
    )
    |> Ash.create!()

    {:ok, view, _html} = live(conn, ~p"/sign-in")

    result =
      view
      |> form("#login-form",
        user: %{email: email, password: "password1234", remember_me: "true"}
      )
      |> render_submit()

    assert {:error, {:redirect, %{to: path}}} = result
    assert path =~ "/auth/user/password/sign_in_with_token"
    assert path =~ "remember_me=true"

    conn = get(conn, path)

    assert redirected_to(conn) == ~p"/"
    assert get_session(conn, "user_token")
    assert get_session(conn, :remember_me) == true
    assert Map.has_key?(conn.resp_cookies, "remember_me")
  end

  test "shows a generic error for wrong credentials and locks after five failures", %{conn: conn} do
    email = "lock-#{System.unique_integer([:positive])}@example.com"

    {:ok, view, _html} = live(conn, ~p"/sign-in")

    for _ <- 1..4 do
      html =
        view
        |> form("#login-form", user: %{email: email, password: "wrong-password"})
        |> render_submit()

      assert html =~ "Incorrect email or password"
    end

    html =
      view
      |> form("#login-form", user: %{email: email, password: "wrong-password"})
      |> render_submit()

    assert html =~ "Too many failed attempts"

    html =
      view
      |> form("#login-form", user: %{email: email, password: "wrong-password"})
      |> render_submit()

    assert html =~ "Too many failed attempts"
  end
end

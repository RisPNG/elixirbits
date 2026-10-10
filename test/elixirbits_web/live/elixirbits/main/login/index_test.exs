defmodule ElixirbitsWeb.LoginLive.IndexTest do
  use ElixirbitsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "renders the sign in form with key elements", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/sign-in")

    assert has_element?(view, "#login-form[novalidate]")

    assert has_element?(view, "#login-form input[name=\"user[email]\"][type=\"email\"][required]")

    assert has_element?(
             view,
             "#login-form input[name=\"user[password]\"][type=\"password\"][required]"
           )

    assert has_element?(view, "#login-form input[name=\"user[remember_me]\"][type=\"checkbox\"]")
    assert has_element?(view, "button[phx-click=\"request_magic_link\"]")
    assert has_element?(view, "a[href=\"/reset\"]")
    assert has_element?(view, "a[href=\"/register\"]")
  end

  test "shows application errors for blank and malformed sign-in input", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/sign-in")

    html =
      view
      |> form("#login-form", user: %{email: "", password: ""})
      |> render_submit()

    assert html =~ "is required"
    assert html =~ "Incorrect email or password"

    html =
      view
      |> form("#login-form", user: %{email: "not-an-email", password: "password1234"})
      |> render_submit()

    assert html =~ "must be a valid email address"
    assert has_element?(view, "#login-form")
  end

  test "malformed magic-link requests show an email error without requiring a password", %{
    conn: conn
  } do
    {:ok, view, _html} = live(conn, ~p"/sign-in")

    view
    |> form("#login-form", user: %{email: "not-an-email", password: ""})
    |> render_change()

    html = view |> element("button[phx-click=\"request_magic_link\"]") |> render_click()

    assert html =~ "must be a valid email address"
    refute html =~ "is required"
    assert has_element?(view, "#login-form")

    view
    |> form("#login-form", user: %{email: "magic-valid@example.com", password: ""})
    |> render_change()

    html = view |> element("button[phx-click=\"request_magic_link\"]") |> render_click()

    assert html =~ "If your email is valid, a sign-in link has been sent."
  end

  test "the sign-in action rejects malformed email input directly" do
    query =
      Elixirbits.Accounts.User
      |> Ash.Query.for_read(
        :sign_in_with_password,
        %{email: "not-an-email", password: "password1234"},
        context: %{private: %{ash_authentication?: true}}
      )

    assert {:error, %Ash.Error.Invalid{errors: errors}} = Ash.read_one(query)
    assert Enum.any?(errors, &(Map.get(&1, :field) == :email))
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

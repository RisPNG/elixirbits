defmodule ElixirbitsWeb.LoginLive.ForgotPasswordTest do
  use ElixirbitsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "renders the request form with key elements", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/reset")

    assert has_element?(view, "#forgot-password-form[novalidate]")

    assert has_element?(
             view,
             "#forgot-password-form input[name=\"user[email]\"][type=\"email\"][required]"
           )

    assert has_element?(view, "a[href=\"/sign-in\"]")
  end

  test "shows input errors without redirecting for blank or malformed emails", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/reset")

    html =
      view
      |> form("#forgot-password-form", user: %{email: ""})
      |> render_submit()

    assert html =~ "is required"
    assert has_element?(view, "#forgot-password-form")

    for email <- ["not-an-email", "user@-example.com", "user@example..com"] do
      html =
        view
        |> form("#forgot-password-form", user: %{email: email})
        |> render_submit()

      assert html =~ "must be a valid email address"
      refute html =~ "password reset instructions have been sent"
      assert has_element?(view, "#forgot-password-form")
    end
  end

  test "reset and magic-link request actions reject malformed email input directly" do
    for action <- [:request_password_reset_token, :request_magic_link] do
      input =
        Elixirbits.Accounts.User
        |> Ash.ActionInput.for_action(action, %{email: "user@example..com"},
          context: %{private: %{ash_authentication?: true}}
        )

      assert {:error, %Ash.Error.Invalid{errors: errors}} = Ash.run_action(input)
      assert Enum.any?(errors, &(Map.get(&1, :field) == :email))
    end
  end

  test "email syntax preserves valid single-label domains and local-part characters" do
    for email <- ["user@localhost", "O'Neil+tag@example.com", "user.name@example.COM"] do
      input =
        Elixirbits.Accounts.User
        |> Ash.ActionInput.for_action(:request_password_reset_token, %{email: email},
          context: %{private: %{ash_authentication?: true}}
        )

      assert input.valid?
    end
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

  test "uses the same generic response for an existing account", %{conn: conn} do
    email = "reset-known-#{System.unique_integer([:positive])}@example.com"

    Elixirbits.Accounts.User
    |> Ash.Changeset.for_create(
      :register_with_password,
      %{email: email, password: "password1234", password_confirmation: "password1234"},
      context: %{private: %{ash_authentication?: true}}
    )
    |> Ash.create!()

    {:ok, view, _html} = live(conn, ~p"/reset")

    view
    |> form("#forgot-password-form", user: %{email: email})
    |> render_submit()

    flash = assert_redirect(view, ~p"/sign-in")

    assert flash["info"] ==
             "If an account exists for that email, password reset instructions have been sent."
  end
end

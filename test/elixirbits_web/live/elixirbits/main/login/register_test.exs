defmodule ElixirbitsWeb.LoginLive.RegisterTest do
  use ElixirbitsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "renders the registration form with key elements", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/register")

    assert has_element?(
             view,
             "#register-form[action=\"/auth/user/password/register\"][novalidate]"
           )

    assert has_element?(
             view,
             "#register-form input[name=\"user[email]\"][type=\"email\"][required]"
           )

    assert has_element?(
             view,
             "#register-form input[name=\"user[password]\"][type=\"password\"][required]"
           )

    assert has_element?(
             view,
             "#register-form input[name=\"user[password_confirmation]\"][type=\"password\"][required]"
           )

    assert has_element?(view, "a[href=\"/sign-in\"]")
  end

  test "shows server errors for malformed email and preserves password constraints", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/register")

    html =
      view
      |> form("#register-form",
        user: %{
          email: "not-an-email",
          password: "password1234",
          password_confirmation: "password1234"
        }
      )
      |> render_submit()

    assert html =~ "must be a valid email address"
    refute has_element?(view, "#register-form[phx-trigger-action=\"true\"]")

    html =
      view
      |> form("#register-form",
        user: %{email: "valid@example.com", password: "short", password_confirmation: "different"}
      )
      |> render_submit()

    assert html =~ "length must be greater than or equal to 8"
    assert html =~ "does not match"
    refute has_element?(view, "#register-form[phx-trigger-action=\"true\"]")
  end

  test "the registration action rejects malformed email outside the form" do
    changeset =
      Elixirbits.Accounts.User
      |> Ash.Changeset.for_create(
        :register_with_password,
        %{
          email: "user@example..com",
          password: "password1234",
          password_confirmation: "password1234"
        },
        context: %{private: %{ash_authentication?: true}}
      )

    assert {:error, %Ash.Error.Invalid{errors: errors}} = Ash.create(changeset)
    assert Enum.any?(errors, &(Map.get(&1, :field) == :email))
  end

  test "unrelated profile changes do not reject a legacy email address" do
    user = %Elixirbits.Accounts.User{
      id: Ash.UUIDv7.generate(),
      email: Ash.CiString.new("legacy-address")
    }

    changeset = Ash.Changeset.for_update(user, :update, %{display_name: "Updated name"})

    assert changeset.valid?
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

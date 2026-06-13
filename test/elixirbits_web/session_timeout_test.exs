defmodule ElixirbitsWeb.SessionTimeoutTest do
  use ElixirbitsWeb.ConnCase, async: true

  setup do
    user =
      Elixirbits.Accounts.User
      |> Ash.Changeset.for_create(
        :register_with_password,
        %{
          email: "timeout-#{System.unique_integer([:positive])}@example.com",
          password: "password1234",
          password_confirmation: "password1234"
        },
        context: %{private: %{ash_authentication?: true}}
      )
      |> Ash.create!()

    %{token: user.__metadata__.token}
  end

  test "keeps a recently active session", %{conn: conn, token: token} do
    conn =
      conn
      |> Plug.Test.init_test_session(%{
        "user_token" => token,
        "last_active_at" => System.system_time(:second) - 60
      })
      |> get(~p"/")

    assert get_session(conn, "user_token") == token
  end

  test "expires a session idle for more than three hours", %{conn: conn, token: token} do
    conn =
      conn
      |> Plug.Test.init_test_session(%{
        "user_token" => token,
        "last_active_at" => System.system_time(:second) - 4 * 60 * 60
      })
      |> get(~p"/")

    assert get_session(conn, "user_token") == nil
  end

  test "remember me sessions survive an idle gap longer than three hours", %{
    conn: conn,
    token: token
  } do
    conn =
      conn
      |> Plug.Test.init_test_session(%{
        "user_token" => token,
        "remember_me" => true,
        "last_active_at" => System.system_time(:second) - 4 * 60 * 60
      })
      |> get(~p"/")

    assert get_session(conn, "user_token") == token
  end

  test "stamps activity on every request", %{conn: conn} do
    conn = get(conn, ~p"/")

    assert is_integer(get_session(conn, :last_active_at))
  end
end

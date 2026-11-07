defmodule PoppybitWeb.SessionTimeoutTest do
  use PoppybitWeb.ConnCase, async: true

  setup do
    user =
      Poppybit.Accounts.User
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

  test "ordinary sessions expire at the 7-day inactivity limit", %{conn: conn, token: token} do
    timeout_seconds = 7 * 24 * 60 * 60

    for {idle_seconds, active?} <- [
          {timeout_seconds - 60, true},
          {timeout_seconds + 60, false}
        ] do
      conn =
        conn
        |> Plug.Test.init_test_session(%{
          "user_token" => token,
          "last_active_at" => System.system_time(:second) - idle_seconds
        })
        |> get(~p"/")

      assert get_session(conn, "user_token") == if(active?, do: token, else: nil)
    end
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

  test "remember me sessions expire according to the configured strategy lifetime", %{
    conn: conn,
    token: token
  } do
    timeout_seconds =
      AshAuthentication.Info.strategy!(Poppybit.Accounts.User, :remember_me).token_lifetime
      |> AshAuthentication.Utils.lifetime_to_seconds()

    for {idle_seconds, active?} <- [
          {timeout_seconds - 60, true},
          {timeout_seconds + 60, false}
        ] do
      conn =
        conn
        |> Plug.Test.init_test_session(%{
          "user_token" => token,
          "remember_me" => true,
          "last_active_at" => System.system_time(:second) - idle_seconds
        })
        |> get(~p"/")

      assert get_session(conn, "user_token") == if(active?, do: token, else: nil)
      assert get_session(conn, :remember_me) == if(active?, do: true, else: nil)
    end
  end

  test "stamps activity on every request", %{conn: conn} do
    conn = get(conn, ~p"/")

    assert is_integer(get_session(conn, :last_active_at))
  end
end

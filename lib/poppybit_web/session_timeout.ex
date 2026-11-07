defmodule PoppybitWeb.SessionTimeout do
  @behaviour Plug

  import Plug.Conn

  @user_token_key "user_token"
  @inactivity_timeout_seconds 7 * 24 * 60 * 60

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    now = System.system_time(:second)
    last_active_at = get_session(conn, :last_active_at)

    timeout_seconds =
      if get_session(conn, :remember_me) do
        strategy =
          AshAuthentication.Info.strategy!(Poppybit.Accounts.User, :remember_me)

        AshAuthentication.Utils.lifetime_to_seconds(strategy.token_lifetime)
      else
        @inactivity_timeout_seconds
      end

    conn =
      if get_session(conn, @user_token_key) && is_integer(last_active_at) &&
           now - last_active_at > timeout_seconds do
        conn
        |> AshAuthentication.Plug.Helpers.revoke_session_tokens(:poppybit)
        |> delete_session(@user_token_key)
        |> delete_session(:remember_me)
      else
        conn
      end

    put_session(conn, :last_active_at, now)
  end
end

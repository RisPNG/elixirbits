defmodule ElixirbitsWeb.SessionTimeout do
  @behaviour Plug

  import Plug.Conn

  @user_token_key "user_token"
  @remember_me_timeout_seconds 365 * 24 * 60 * 60
  @inactivity_timeout_seconds 3 * 60 * 60

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    now = System.system_time(:second)
    last_active_at = get_session(conn, :last_active_at)

    timeout_seconds =
      if get_session(conn, :remember_me),
        do: @remember_me_timeout_seconds,
        else: @inactivity_timeout_seconds

    conn =
      if get_session(conn, @user_token_key) && is_integer(last_active_at) &&
           now - last_active_at > timeout_seconds do
        conn
        |> AshAuthentication.Plug.Helpers.revoke_session_tokens(:elixirbits)
        |> delete_session(@user_token_key)
        |> delete_session(:remember_me)
      else
        conn
      end

    put_session(conn, :last_active_at, now)
  end
end

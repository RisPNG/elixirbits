defmodule ElixirbitsWeb.Dashboard.LoginLive.MagicLink do
  use ElixirbitsWeb, :live_view

  on_mount {ElixirbitsWeb.LiveUserAuth, :live_no_user}

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Magic Link Sign In")
     |> assign(:token, token)}
  end
end

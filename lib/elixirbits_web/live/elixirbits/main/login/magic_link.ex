defmodule ElixirbitsWeb.LoginLive.MagicLink do
  use ElixirbitsWeb, :live_view

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Magic Link Sign In")
     |> assign(:token, token)}
  end
end

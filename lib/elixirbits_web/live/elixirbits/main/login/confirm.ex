defmodule ElixirbitsWeb.LoginLive.Confirm do
  use ElixirbitsWeb, :live_view

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Confirm Email")
     |> assign(:token, token)}
  end
end

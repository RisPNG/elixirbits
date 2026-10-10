defmodule ElixirbitsWeb.HomeLive do
  use ElixirbitsWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, "Home")}
  end
end

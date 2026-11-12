defmodule ElixirbitsWeb.IndexLive.Index do
  use ElixirbitsWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, "Elixirbits")}
  end
end

defmodule ElixirbitsWeb.Admin.RoleLive.Index do
  use ElixirbitsWeb, :live_view

  on_mount {ElixirbitsWeb.LiveUserAuth, {:require_page_access, "/admin/roles"}}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Roles")
     |> assign(:query, Ash.Query.sort(Elixirbits.AccessControl.Role, name: :asc))}
  end
end

defmodule ElixirbitsWeb.Dashboard.RoleLive.Index do
  use ElixirbitsWeb, :dashboard_live_view

  alias Elixirbits.AccessControl.Role
  alias ElixirbitsWeb.Dashboard.RoleLive.Deletion

  on_mount {ElixirbitsWeb.LiveUserAuth, {:require_page_access, "/dashboard/admin/roles"}}
  on_mount {Deletion, :index}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Roles")
     |> assign(:query, Ash.Query.sort(Role, name: :asc))}
  end
end

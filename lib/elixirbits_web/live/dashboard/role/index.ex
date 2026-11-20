defmodule ElixirbitsWeb.Dashboard.RoleLive.Index do
  use ElixirbitsWeb, :dashboard_live_view

  alias Elixirbits.AccessControl.Role
  alias ElixirbitsWeb.Dashboard.RoleLive.Deletion

  @collection_id "roles-table"
  @collection_fields [{:code, "Code"}, {:name, "Name"}]

  on_mount {ElixirbitsWeb.LiveUserAuth, {:require_page_access, "/dashboard/admin/roles"}}
  on_mount {Layouts, {:collection_layout, @collection_id}}
  on_mount {Deletion, :index}

  embed_templates "index_compact.html"

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:collection_id, @collection_id)
     |> assign(:collection_fields, @collection_fields)
     |> assign(:page_title, "Roles")
     |> assign(:query, Ash.Query.sort(Role, name: :asc))}
  end
end

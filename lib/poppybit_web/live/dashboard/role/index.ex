defmodule PoppybitWeb.Dashboard.RoleLive.Index do
  use PoppybitWeb, :live_view

  alias Poppybit.AccessControl.Role
  alias PoppybitWeb.Dashboard.RoleLive.Deletion

  on_mount {PoppybitWeb.LiveUserAuth, {:require_page_access, "/dashboard/admin/roles"}}
  on_mount {Deletion, :index}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Roles")
     |> assign(:query, Ash.Query.sort(Role, name: :asc))}
  end
end

defmodule ElixirbitsWeb.Dashboard.UserLive.Index do
  use ElixirbitsWeb, :dashboard_live_view

  alias Elixirbits.Accounts.User
  alias ElixirbitsWeb.Dashboard.UserLive.Deletion

  @collection_id "users-table"
  @collection_fields [{:email, "Email"}, {:username, "Username"}, {:display_name, "Display name"}]

  on_mount {ElixirbitsWeb.LiveUserAuth, {:require_page_access, "/dashboard/admin/users"}}
  on_mount {Layouts, {:collection_layout, @collection_id}}
  on_mount {Deletion, :index}

  embed_templates "index_compact.html"

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:collection_id, @collection_id)
     |> assign(:collection_fields, @collection_fields)
     |> assign(:page_title, "Users")
     |> assign(:query, Ash.Query.sort(User, inserted_at: :desc))}
  end
end

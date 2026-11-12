defmodule ElixirbitsWeb.Dashboard.UserLive.Index do
  use ElixirbitsWeb, :live_view

  alias Elixirbits.Accounts.User
  alias ElixirbitsWeb.Dashboard.UserLive.Deletion

  on_mount {ElixirbitsWeb.LiveUserAuth, {:require_page_access, "/dashboard/admin/users"}}
  on_mount {Deletion, :index}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Users")
     |> assign(:query, Ash.Query.sort(User, inserted_at: :desc))}
  end
end

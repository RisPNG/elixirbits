defmodule ElixirbitsWeb.Admin.UserLive.Index do
  use ElixirbitsWeb, :live_view

  alias Elixirbits.Accounts.User
  alias ElixirbitsWeb.Admin.UserLive.Deletion

  on_mount {ElixirbitsWeb.LiveUserAuth, {:require_page_access, "/admin/users"}}
  on_mount {Deletion, :index}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Users")
     |> assign(:query, Ash.Query.sort(User, inserted_at: :desc))}
  end
end

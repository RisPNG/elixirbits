defmodule ElixirbitsWeb.Admin.UserLive.Index do
  use ElixirbitsWeb, :live_view

  on_mount {ElixirbitsWeb.LiveUserAuth, {:require_page_access, "/admin/users"}}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Users")
     |> assign(:query, Ash.Query.sort(Elixirbits.Accounts.User, inserted_at: :desc))}
  end
end

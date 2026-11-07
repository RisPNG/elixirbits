defmodule PoppybitWeb.Admin.UserLive.Index do
  use PoppybitWeb, :live_view

  alias Poppybit.Accounts.User
  alias PoppybitWeb.Admin.UserLive.Deletion

  on_mount {PoppybitWeb.LiveUserAuth, {:require_page_access, "/dashboard/admin/users"}}
  on_mount {Deletion, :index}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Users")
     |> assign(:query, Ash.Query.sort(User, inserted_at: :desc))}
  end
end

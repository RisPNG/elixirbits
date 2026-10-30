defmodule ElixirbitsWeb.Admin.UserLive.Index do
  use ElixirbitsWeb, :live_view

  alias Elixirbits.Accounts.User

  on_mount {ElixirbitsWeb.LiveUserAuth, {:require_page_access, "/admin/users"}}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Users")
     |> assign(:query, Ash.Query.sort(User, inserted_at: :desc))
     |> assign(:to_delete, nil)}
  end

  @impl true
  def handle_event("request_delete", %{"id" => id}, socket) do
    if can?(socket.assigns.current_user, "/admin/users", :delete) do
      case Ash.get(User, id, actor: socket.assigns.current_user) do
        {:ok, user} ->
          {:noreply, assign(socket, :to_delete, user)}

        {:error, _error} ->
          {:noreply, put_flash(socket, :error, "User could not be found.")}
      end
    else
      {:noreply, put_flash(socket, :error, "You do not have permission to do that.")}
    end
  end

  def handle_event("cancel_delete", _params, socket) do
    {:noreply, assign(socket, :to_delete, nil)}
  end

  def handle_event("confirm_delete", _params, socket) do
    case socket.assigns.to_delete do
      nil ->
        {:noreply, socket}

      user ->
        case Ash.destroy(user, actor: socket.assigns.current_user) do
          :ok ->
            socket =
              socket
              |> assign(:to_delete, nil)
              |> put_flash(:info, "User deleted.")

            if user.id == socket.assigns.current_user.id do
              {:noreply, push_navigate(socket, to: ~p"/admin/users")}
            else
              {:noreply, Cinder.Refresh.refresh_table(socket, "users-table")}
            end

          {:error, %Ash.Error.Forbidden{}} ->
            {:noreply, put_flash(socket, :error, "You do not have permission to do that.")}

          {:error, _error} ->
            {:noreply, put_flash(socket, :error, "User could not be deleted.")}
        end
    end
  end
end

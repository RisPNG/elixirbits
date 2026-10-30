defmodule ElixirbitsWeb.Admin.UserLive.Deletion do
  import Phoenix.Component, only: [assign: 3]
  import Phoenix.LiveView, only: [attach_hook: 4, push_navigate: 2]
  import ElixirbitsWeb.Flash, only: [put_flash: 3]
  use ElixirbitsWeb, :verified_routes

  alias Elixirbits.AccessControl.Permissions
  alias Elixirbits.Accounts.User

  def on_mount(mode, _params, _session, socket) when mode in [:index, :entry] do
    socket =
      socket
      |> assign(:to_delete, nil)
      |> attach_hook(:user_deletion, :handle_event, fn
        "request_delete", params, socket ->
          id =
            case mode do
              :index -> params["id"]
              :entry -> if socket.assigns.live_action == :update, do: socket.assigns.user.id
            end

          cond do
            is_nil(id) ->
              {:halt, socket}

            not Permissions.can?(socket.assigns.current_user, "/admin/users", :delete) ->
              {:halt, put_flash(socket, :error, "You do not have permission to do that.")}

            true ->
              case Ash.get(User, id, actor: socket.assigns.current_user) do
                {:ok, user} ->
                  {:halt, assign(socket, :to_delete, user)}

                {:error, _error} ->
                  {:halt, put_flash(socket, :error, "User could not be found.")}
              end
          end

        "cancel_delete", _params, socket ->
          {:halt, assign(socket, :to_delete, nil)}

        "confirm_delete", _params, socket ->
          case socket.assigns.to_delete do
            nil ->
              {:halt, socket}

            user ->
              case Ash.destroy(user, actor: socket.assigns.current_user) do
                :ok ->
                  socket =
                    socket
                    |> assign(:to_delete, nil)
                    |> put_flash(:info, "User deleted.")

                  if mode == :entry or user.id == socket.assigns.current_user.id do
                    {:halt, push_navigate(socket, to: ~p"/admin/users")}
                  else
                    {:halt, Cinder.Refresh.refresh_table(socket, "users-table")}
                  end

                {:error, %Ash.Error.Forbidden{}} ->
                  {:halt, put_flash(socket, :error, "You do not have permission to do that.")}

                {:error, _error} ->
                  {:halt, put_flash(socket, :error, "User could not be deleted.")}
              end
          end

        _event, _params, socket ->
          {:cont, socket}
      end)

    {:cont, socket}
  end
end

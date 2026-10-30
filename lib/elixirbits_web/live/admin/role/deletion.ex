defmodule ElixirbitsWeb.Admin.RoleLive.Deletion do
  import Phoenix.Component, only: [assign: 3, update: 3]
  import Phoenix.LiveView, only: [attach_hook: 4, push_navigate: 2]
  import ElixirbitsWeb.Flash, only: [put_flash: 3]
  use ElixirbitsWeb, :verified_routes

  alias Elixirbits.AccessControl.Permissions
  alias Elixirbits.AccessControl.Role

  def on_mount(mode, _params, _session, socket) when mode in [:index, :entry] do
    socket =
      socket
      |> assign(:to_delete, nil)
      |> assign(:remove_assignments?, false)
      |> attach_hook(:role_deletion, :handle_event, fn
        "request_delete", params, socket ->
          id =
            case mode do
              :index -> params["id"]
              :entry -> if socket.assigns.live_action == :update, do: socket.assigns.role.id
            end

          cond do
            is_nil(id) ->
              {:halt, socket}

            not Permissions.can?(socket.assigns.current_user, "/admin/roles", :delete) ->
              {:halt, put_flash(socket, :error, "You do not have permission to do that.")}

            true ->
              case Ash.get(Role, id, actor: socket.assigns.current_user) do
                {:ok, %{code: "superuser"}} ->
                  {:halt, put_flash(socket, :error, "The superuser role cannot be deleted.")}

                {:ok, role} ->
                  {:halt,
                   socket |> assign(:to_delete, role) |> assign(:remove_assignments?, false)}

                {:error, _error} ->
                  {:halt, put_flash(socket, :error, "Role could not be found.")}
              end
          end

        "cancel_delete", _params, socket ->
          {:halt, socket |> assign(:to_delete, nil) |> assign(:remove_assignments?, false)}

        "confirm_delete", params, socket ->
          case socket.assigns.to_delete do
            nil ->
              {:halt, socket}

            role ->
              changeset =
                Ash.Changeset.for_destroy(
                  role,
                  :destroy,
                  %{
                    remove_assignments?:
                      socket.assigns.remove_assignments? and
                        params["remove-assignments"] == "true"
                  },
                  actor: socket.assigns.current_user
                )

              case Ash.destroy(changeset) do
                :ok ->
                  socket =
                    socket
                    |> assign(:to_delete, nil)
                    |> assign(:remove_assignments?, false)
                    |> put_flash(:info, "Role deleted.")

                  permissions = Permissions.load(socket.assigns.current_user)

                  if Permissions.can_access_path?(permissions, "/admin/roles") do
                    socket =
                      socket
                      |> assign(:permissions, permissions)
                      |> assign(:current_user, permissions.user)
                      |> update(
                        :nav,
                        &%{
                          &1
                          | user: permissions.user,
                            items: Permissions.visible_sitenav(permissions)
                        }
                      )

                    case mode do
                      :index -> {:halt, Cinder.Refresh.refresh_table(socket, "roles-table")}
                      :entry -> {:halt, push_navigate(socket, to: ~p"/admin/roles")}
                    end
                  else
                    {:halt, push_navigate(socket, to: ~p"/")}
                  end

                {:error, %Ash.Error.Forbidden{}} ->
                  {:halt, put_flash(socket, :error, "You do not have permission to do that.")}

                {:error, %Ash.Error.Invalid{errors: errors}} ->
                  if Enum.any?(
                       errors,
                       &match?(
                         %Ash.Error.Changes.InvalidArgument{field: :remove_assignments?},
                         &1
                       )
                     ) do
                    {:halt, assign(socket, :remove_assignments?, true)}
                  else
                    {:halt, put_flash(socket, :error, "Role could not be deleted.")}
                  end

                {:error, _error} ->
                  {:halt, put_flash(socket, :error, "Role could not be deleted.")}
              end
          end

        _event, _params, socket ->
          {:cont, socket}
      end)

    {:cont, socket}
  end
end

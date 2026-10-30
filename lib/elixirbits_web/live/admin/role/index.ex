defmodule ElixirbitsWeb.Admin.RoleLive.Index do
  use ElixirbitsWeb, :live_view

  alias Elixirbits.AccessControl.Permissions
  alias Elixirbits.AccessControl.Role

  on_mount {ElixirbitsWeb.LiveUserAuth, {:require_page_access, "/admin/roles"}}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Roles")
     |> assign(:query, Ash.Query.sort(Role, name: :asc))
     |> assign(:to_delete, nil)
     |> assign(:remove_assignments?, false)}
  end

  @impl true
  def handle_event("request_delete", %{"id" => id}, socket) do
    if can?(socket.assigns.current_user, "/admin/roles", :delete) do
      case Ash.get(Role, id, actor: socket.assigns.current_user) do
        {:ok, %{code: "superuser"}} ->
          {:noreply, put_flash(socket, :error, "The superuser role cannot be deleted.")}

        {:ok, role} ->
          {:noreply, socket |> assign(:to_delete, role) |> assign(:remove_assignments?, false)}

        {:error, _error} ->
          {:noreply, put_flash(socket, :error, "Role could not be found.")}
      end
    else
      {:noreply, put_flash(socket, :error, "You do not have permission to do that.")}
    end
  end

  def handle_event("cancel_delete", _params, socket) do
    {:noreply, socket |> assign(:to_delete, nil) |> assign(:remove_assignments?, false)}
  end

  def handle_event("confirm_delete", params, socket) do
    case socket.assigns.to_delete do
      nil ->
        {:noreply, socket}

      role ->
        changeset =
          Ash.Changeset.for_destroy(
            role,
            :destroy,
            %{
              remove_assignments?:
                socket.assigns.remove_assignments? and params["remove-assignments"] == "true"
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
              {:noreply,
               socket
               |> assign(:permissions, permissions)
               |> assign(:current_user, permissions.user)
               |> update(
                 :nav,
                 &%{&1 | user: permissions.user, items: Permissions.visible_sitenav(permissions)}
               )
               |> Cinder.Refresh.refresh_table("roles-table")}
            else
              {:noreply, push_navigate(socket, to: ~p"/")}
            end

          {:error, %Ash.Error.Forbidden{}} ->
            {:noreply, put_flash(socket, :error, "You do not have permission to do that.")}

          {:error, %Ash.Error.Invalid{errors: errors}} ->
            if Enum.any?(
                 errors,
                 &match?(%Ash.Error.Changes.InvalidArgument{field: :remove_assignments?}, &1)
               ) do
              {:noreply, assign(socket, :remove_assignments?, true)}
            else
              {:noreply, put_flash(socket, :error, "Role could not be deleted.")}
            end

          {:error, _error} ->
            {:noreply, put_flash(socket, :error, "Role could not be deleted.")}
        end
    end
  end
end

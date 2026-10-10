defmodule ElixirbitsWeb.Admin.RoleLive.Entry do
  use ElixirbitsWeb, :live_view

  alias Elixirbits.AccessControl.Permissions
  alias Elixirbits.AccessControl.Role
  alias Elixirbits.CoreUtils.Resource
  alias Elixirbits.CoreUtils.Search
  alias LiveSelect.Component

  on_mount {ElixirbitsWeb.LiveUserAuth, {:require_page_access, "/admin/roles"}}

  @levels [
    {"None", 0},
    {"Read", 4},
    {"Read + Update", 5},
    {"Read + Create", 6},
    {"Read + Create + Update", 7},
    {"Read + Delete", 12},
    {"Read + Update + Delete", 13},
    {"Read + Create + Delete", 14},
    {"Read + Create + Update + Delete", 15},
    {"Superuser Access", 16}
  ]

  @impl true
  def mount(_params, _session, socket) do
    entries = socket.assigns.permissions.entries
    by_code = Map.new(entries, &{&1.code, &1})

    pages =
      entries
      |> Enum.filter(&(not is_nil(&1.url)))
      |> Enum.sort_by(& &1.sequence)
      |> Enum.map(fn entry ->
        parent = Map.get(by_code, entry.parent)

        %{
          code: entry.code,
          name: entry.name,
          group: parent && parent.name,
          public?: "public" in entry.roles_bypass
        }
      end)

    {:ok, socket |> assign(:pages, pages) |> assign(:levels, @levels)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {role, form, title, levels} =
      case socket.assigns.live_action do
        :create ->
          form =
            AshPhoenix.Form.for_create(Role, :create,
              actor: socket.assigns.current_user,
              context: %{shared: %{user_timezone: socket.assigns.user_timezone}},
              transform_params: &Resource.convert_form_datetimes/3,
              post_process_errors: &Resource.local_datetime_errors/3,
              forms: [auto?: false]
            )

          {nil, form, "New Role", %{}}

        :update ->
          role =
            Ash.get!(Role, params["id"], actor: socket.assigns.current_user, load: [:role_perms])

          form =
            AshPhoenix.Form.for_update(role, :update,
              actor: socket.assigns.current_user,
              context: %{shared: %{user_timezone: socket.assigns.user_timezone}},
              transform_params: &Resource.convert_form_datetimes/3,
              post_process_errors: &Resource.local_datetime_errors/3,
              forms: [auto?: false]
            )

          {role, form, "Update #{role.name}",
           Map.new(role.role_perms, &{&1.sitenav_code, &1.level})}
      end

    levels =
      Map.new(socket.assigns.pages, fn page ->
        {page.code, Map.get(levels, page.code, 0)}
      end)

    {:noreply,
     socket
     |> assign(:role, role)
     |> assign(:form, to_form(form))
     |> assign(:page_title, title)
     |> assign(:perm_levels, levels)
     |> assign(:permission_form, to_form(levels, as: "page_levels", id: "permission-level"))}
  end

  @impl true
  def handle_event("validate", %{"form" => params} = payload, socket) do
    socket =
      if Map.has_key?(payload, "page_levels") do
        permissions = Permissions.load(socket.assigns.current_user)

        socket
        |> assign(:permissions, permissions)
        |> assign(:current_user, permissions.user)
        |> update(
          :nav,
          &%{&1 | user: permissions.user, items: Permissions.visible_sitenav(permissions)}
        )
      else
        socket
      end

    levels =
      if can?(socket.assigns.permissions, "/admin/roles", :su) do
        changes =
          payload
          |> Map.get("page_levels", %{})
          |> Map.take(Enum.map(socket.assigns.pages, & &1.code))
          |> Map.new(fn {code, level} -> {code, String.to_integer(level)} end)

        Map.merge(socket.assigns.perm_levels, changes)
      else
        socket.assigns.perm_levels
      end

    {:noreply,
     socket
     |> assign(:form, AshPhoenix.Form.validate(socket.assigns.form, params))
     |> assign(:perm_levels, levels)
     |> assign(:permission_form, to_form(levels, as: "page_levels", id: "permission-level"))}
  end

  def handle_event("live_select_change", %{"id" => id} = params, socket) do
    options = Search.filter(socket.assigns.levels, Map.get(params, "text", ""))
    send_update(Component, id: id, options: options)
    {:noreply, socket}
  end

  def handle_event("save", %{"form" => params}, socket) do
    params =
      if can?(socket.assigns.permissions, "/admin/roles", :su) do
        permissions =
          Enum.map(socket.assigns.pages, fn page ->
            %{
              "sitenav_code" => page.code,
              "level" => Map.get(socket.assigns.perm_levels, page.code, 0)
            }
          end)

        Map.put(params, "permissions", permissions)
      else
        Map.delete(params, "permissions")
      end

    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, _role} ->
        {:noreply,
         socket |> put_flash(:info, "Role saved.") |> push_navigate(to: ~p"/admin/roles")}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end
end

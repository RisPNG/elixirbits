defmodule ElixirbitsWeb.Admin.UserLive.Entry do
  use ElixirbitsWeb, :live_view

  alias Elixirbits.Accounts
  alias Elixirbits.AccessControl.Permissions
  alias Elixirbits.CoreUtils.EnumTypes.AddressLabel
  alias Elixirbits.CoreUtils.EnumTypes.UserSex
  alias Elixirbits.CoreUtils.Resource
  alias Elixirbits.CoreUtils.Search
  alias Elixirbits.CoreUtils.Upload
  alias LiveSelect.Component

  on_mount {ElixirbitsWeb.LiveUserAuth, {:require_page_access, "/admin/users"}}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     allow_upload(socket, :display_pic,
       accept: ~w(.jpg .jpeg .png .gif .webp),
       max_entries: 1,
       max_file_size: 8_000_000
     )}
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    user = Accounts.get_user!(id, actor: socket.assigns.current_user, load: [:addresses])

    form =
      AshPhoenix.Form.for_update(user, :update,
        actor: socket.assigns.current_user,
        context: %{shared: %{user_timezone: socket.assigns.user_timezone}},
        transform_params: &Resource.convert_form_datetimes/3,
        post_process_errors: &Resource.local_datetime_errors/3,
        forms: [auto?: true]
      )

    roles_form =
      if Permissions.can?(socket.assigns.permissions, "/admin/roles", :su) and
           Permissions.can?(socket.assigns.permissions, "/admin/users", :update) do
        AshPhoenix.Form.for_update(user, :assign_roles,
          actor: socket.assigns.current_user,
          context: %{shared: %{user_timezone: socket.assigns.user_timezone}},
          transform_params: &Resource.convert_form_datetimes/3,
          post_process_errors: &Resource.local_datetime_errors/3,
          as: "roles_form"
        )
        |> to_form()
      end

    roles =
      if roles_form do
        Elixirbits.AccessControl.Role
        |> Ash.read!(actor: socket.assigns.current_user)
        |> Enum.sort_by(& &1.name)
        |> Enum.map(&{&1.name, &1.code})
      else
        []
      end

    {:noreply,
     socket
     |> assign(:page_title, "Update #{user.display_name || to_string(user.email)}")
     |> assign(:user, user)
     |> assign(:existing_display_pic, user.display_pic_url)
     |> assign(:form, to_form(form))
     |> assign(:roles_form, roles_form)
     |> assign(:role_options, roles)
     |> assign(
       :sex_options,
       Enum.map(UserSex.values(), &{Phoenix.Naming.humanize(&1), to_string(&1)})
     )
     |> assign(
       :label_options,
       Enum.map(AddressLabel.values(), &{Phoenix.Naming.humanize(&1), to_string(&1)})
     )}
  end

  @impl true
  def handle_event("validate", %{"form" => params}, socket) do
    {:noreply, assign(socket, :form, AshPhoenix.Form.validate(socket.assigns.form, params))}
  end

  def handle_event("save", %{"form" => params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.form.source, params)

    if form.valid? do
      picked_name =
        case socket.assigns.uploads.display_pic.entries do
          [entry] -> entry.client_name
          [] -> nil
        end

      new_display_pic = List.first(Upload.consume(socket, :display_pic, "users"))
      display_pic_url = new_display_pic || socket.assigns.existing_display_pic

      params =
        Map.merge(params, %{
          "display_pic_url" => display_pic_url,
          "display_pic_name" =>
            display_pic_url && (picked_name || socket.assigns.user.display_pic_name)
        })

      case AshPhoenix.Form.submit(form, params: params) do
        {:ok, user} ->
          stored_before = socket.assigns.user.display_pic_url

          if stored_before && stored_before != user.display_pic_url,
            do: Upload.delete(stored_before)

          {:noreply,
           socket |> put_flash(:info, "User updated.") |> push_navigate(to: ~p"/admin/users")}

        {:error, form} ->
          if new_display_pic, do: Upload.delete(new_display_pic)
          {:noreply, assign(socket, :form, to_form(form))}
      end
    else
      {:noreply, assign(socket, :form, to_form(form))}
    end
  end

  def handle_event("assign_roles", %{"roles_form" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.roles_form, params: params) do
      {:ok, _user} ->
        {:noreply,
         socket |> put_flash(:info, "Roles updated.") |> push_navigate(to: ~p"/admin/users")}

      {:error, form} ->
        {:noreply, assign(socket, :roles_form, form)}
    end
  end

  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :display_pic, ref)}
  end

  def handle_event("remove_upload", _params, socket) do
    {:noreply, assign(socket, :existing_display_pic, nil)}
  end

  def handle_event("add_form", %{"field" => "addresses"}, socket) do
    {:noreply, assign(socket, :form, AshPhoenix.Form.add_form(socket.assigns.form, [:addresses]))}
  end

  def handle_event("remove_form", %{"path" => path}, socket) do
    {:noreply, assign(socket, :form, AshPhoenix.Form.remove_form(socket.assigns.form, path))}
  end

  def handle_event("live_select_change", %{"id" => id} = params, socket) do
    text = Map.get(params, "text", "")

    options =
      cond do
        String.ends_with?(id, "_roles-ls") ->
          Search.filter(socket.assigns.role_options, text)

        String.ends_with?(id, "_sex-ls") ->
          UserSex.values()
          |> Enum.map(&{Phoenix.Naming.humanize(&1), to_string(&1)})
          |> Search.filter(text)

        String.ends_with?(id, "_label_select") ->
          AddressLabel.values()
          |> Enum.map(&{Phoenix.Naming.humanize(&1), to_string(&1)})
          |> Search.filter(text)

        true ->
          []
      end

    send_update(Component, id: id, options: options)
    {:noreply, socket}
  end
end

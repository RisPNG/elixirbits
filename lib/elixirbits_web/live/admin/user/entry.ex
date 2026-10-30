defmodule ElixirbitsWeb.Admin.UserLive.Entry do
  use ElixirbitsWeb, :live_view

  alias Elixirbits.Accounts
  alias Elixirbits.AccessControl.Permissions
  alias Elixirbits.CoreUtils.EnumTypes.AddressLabel
  alias Elixirbits.CoreUtils.EnumTypes.UserSex
  alias Elixirbits.CoreUtils.Resource
  alias Elixirbits.CoreUtils.Upload
  alias ElixirbitsWeb.Admin.UserLive.Deletion

  on_mount {ElixirbitsWeb.LiveUserAuth, {:require_page_access, "/admin/users"}}
  on_mount {Deletion, :entry}

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
  def handle_params(params, _uri, socket) do
    {user, form, title} =
      case socket.assigns.live_action do
        :create ->
          form =
            AshPhoenix.Form.for_create(Elixirbits.Accounts.User, :create,
              actor: socket.assigns.current_user,
              context: %{shared: %{user_timezone: socket.assigns.user_timezone}},
              transform_params: &Resource.convert_form_datetimes/3,
              post_process_errors: &Resource.local_datetime_errors/3,
              forms: [auto?: true]
            )

          {nil, form, "New User"}

        :update ->
          user =
            Accounts.get_user!(params["id"],
              actor: socket.assigns.current_user,
              load: [:addresses]
            )

          form =
            AshPhoenix.Form.for_update(user, :update,
              actor: socket.assigns.current_user,
              context: %{shared: %{user_timezone: socket.assigns.user_timezone}},
              transform_params: &Resource.convert_form_datetimes/3,
              post_process_errors: &Resource.local_datetime_errors/3,
              forms: [auto?: true]
            )

          {user, form, "Update #{user.display_name || to_string(user.email)}"}
      end

    can_assign_roles? =
      socket.assigns.live_action == :update and
        Permissions.can?(socket.assigns.permissions, "/admin/roles", :su) and
        Permissions.can?(socket.assigns.permissions, "/admin/users", :update)

    roles =
      if can_assign_roles? do
        Elixirbits.AccessControl.Role
        |> Ash.read!(actor: socket.assigns.current_user)
        |> Enum.filter(fn role ->
          role.code != "superuser" or Permissions.superuser?(socket.assigns.permissions.user) or
            "superuser" in user.roles
        end)
        |> Enum.sort_by(& &1.name)
        |> Enum.map(&{&1.name, &1.code})
      else
        []
      end

    {:noreply,
     socket
     |> assign(:page_title, title)
     |> assign(:user, user)
     |> assign(:existing_display_pic, user && user.display_pic_url)
     |> assign(:form, to_form(form))
     |> assign(:can_assign_roles?, can_assign_roles?)
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

    cond do
      not form.valid? ->
        {:noreply, assign(socket, :form, to_form(form))}

      not Ash.can?(form.source, socket.assigns.current_user) ->
        {:noreply, put_flash(socket, :error, "You do not have permission to save these changes.")}

      true ->
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
              display_pic_url &&
                (picked_name || (socket.assigns.user && socket.assigns.user.display_pic_name))
          })

        case AshPhoenix.Form.submit(form, params: params) do
          {:ok, user} ->
            stored_before = socket.assigns.user && socket.assigns.user.display_pic_url

            if stored_before && stored_before != user.display_pic_url,
              do: Upload.delete(stored_before)

            {:noreply,
             socket
             |> put_flash(
               :info,
               if(socket.assigns.live_action == :create,
                 do: "User created.",
                 else: "User updated."
               )
             )
             |> push_navigate(to: ~p"/admin/users")}

          {:error, form} ->
            if new_display_pic, do: Upload.delete(new_display_pic)
            {:noreply, assign(socket, :form, to_form(form))}
        end
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
end

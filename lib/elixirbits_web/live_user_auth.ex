defmodule ElixirbitsWeb.LiveUserAuth do
  import Phoenix.Component
  import Phoenix.LiveView, except: [put_flash: 3]
  import ElixirbitsWeb.Flash, only: [put_flash: 3]
  use ElixirbitsWeb, :verified_routes

  alias Elixirbits.AccessControl.Permissions
  alias Elixirbits.Accounts

  def on_mount(:timezone, _params, _session, socket) do
    socket =
      socket
      |> assign_new(:user_timezone, fn ->
        organization =
          case socket.assigns[:nav] do
            %{organization: organization} -> organization
            _ -> Elixirbits.Organizations.current_organization!()
          end

        browser_timezone =
          if is_nil(socket.parent_pid), do: (get_connect_params(socket) || %{})["user_timezone"]

        browser_timezone =
          if is_binary(browser_timezone) and match?({:ok, _}, DateTime.now(browser_timezone)) do
            browser_timezone
          end

        (socket.assigns[:current_user] && socket.assigns.current_user.timezone) ||
          browser_timezone || (organization && organization.timezone) || "Etc/UTC"
      end)
      |> assign(:current_url, "/")
      |> attach_hook(:user_timezone_preference, :handle_event, fn
        "change_timezone", %{"timezone" => timezone}, socket ->
          case socket.assigns[:current_user] do
            nil ->
              {:halt, put_flash(socket, :error, "Sign in to save your timezone.")}

            user ->
              timezone = if timezone == "", do: nil, else: timezone

              case Accounts.update_user_timezone(user, %{timezone: timezone}, actor: user) do
                {:ok, _user} ->
                  {:halt,
                   socket
                   |> put_flash(:info, "Timezone saved.")
                   |> push_navigate(to: socket.assigns.current_url)}

                {:error, _error} ->
                  {:halt, put_flash(socket, :error, "Choose a valid timezone.")}
              end
          end

        _event, _params, socket ->
          {:cont, socket}
      end)

    socket =
      if socket.router && is_nil(socket.parent_pid) do
        attach_hook(socket, :timezone_path, :handle_params, fn _params, uri, socket ->
          uri = URI.parse(uri)

          {:cont,
           assign(socket, :current_url, URI.to_string(%URI{path: uri.path, query: uri.query}))}
        end)
      else
        socket
      end

    {:cont, socket}
  end

  def on_mount(:current_user, _params, session, socket) do
    {:cont, AshAuthentication.Phoenix.LiveSession.assign_new_resources(socket, session)}
  end

  def on_mount(:app_nav, _params, _session, socket) do
    permissions = Permissions.load(socket.assigns[:current_user])

    socket =
      socket
      |> assign(:permissions, permissions)
      |> assign(:current_path, "/")
      |> assign(:nav, %{
        items: Permissions.visible_sitenav(permissions),
        organization: Elixirbits.Organizations.current_organization!(),
        user: permissions.user,
        timezone_form:
          to_form(%{"timezone" => (permissions.user && permissions.user.timezone) || ""}),
        timezone_options:
          if(permissions.user,
            do:
              Tzdata.zone_list()
              |> Enum.filter(&match?({:ok, _}, DateTime.now(&1)))
              |> Enum.sort()
              |> Enum.map(&{&1, &1})
              |> then(&[{"Automatic (browser)", ""} | &1]),
            else: []
          ),
        path: "/",
        open?: true,
        open_codes: nil
      })
      |> attach_hook(:app_nav_path, :handle_params, fn _params, uri, socket ->
        path = URI.parse(uri).path

        {:cont,
         socket
         |> assign(:current_path, path)
         |> update(:nav, fn nav ->
           %{
             nav
             | path: path,
               open_codes:
                 nav.open_codes ||
                   Permissions.active_branch_codes(socket.assigns.permissions, path)
           }
         end)}
      end)
      |> attach_hook(:app_nav_events, :handle_event, fn
        "timezone_change", %{"timezone" => timezone}, socket ->
          {:halt,
           update(socket, :nav, fn nav ->
             %{nav | timezone_form: to_form(%{"timezone" => timezone})}
           end)}

        "toggle_nav", _params, socket ->
          {:halt, update(socket, :nav, &%{&1 | open?: not &1.open?})}

        "toggle_nav_section", %{"code" => code}, socket ->
          {:halt,
           update(socket, :nav, fn nav ->
             %{
               nav
               | open_codes:
                   if(code in nav.open_codes,
                     do: List.delete(nav.open_codes, code),
                     else: [code | nav.open_codes]
                   )
             }
           end)}

        _event, _params, socket ->
          {:cont, socket}
      end)

    {:cont, socket}
  end

  def on_mount({:require_page_access, path}, _params, _session, socket) do
    case authorize_page(socket, path) do
      {:halt, socket} ->
        {:halt, socket}

      {:cont, socket} ->
        socket =
          socket
          |> attach_hook(:require_page_access, :handle_params, fn _params, uri, socket ->
            authorize_page(socket, URI.parse(uri).path)
          end)
          |> attach_hook(:require_capability, :handle_event, fn event, params, socket ->
            permission =
              case event do
                "save" ->
                  capability =
                    if socket.assigns.form.source.type == :create, do: :create, else: :update

                  [{socket.assigns.current_path, capability}]

                "confirm_delete" ->
                  [{socket.assigns.current_path, :delete}]

                "add_form" ->
                  capability =
                    if socket.assigns.form.source.type == :create, do: :create, else: :update

                  [
                    {socket.assigns.current_path, capability},
                    {socket.assigns.current_path, :create}
                  ]

                "remove_form" ->
                  capability =
                    if socket.assigns.form.source.type == :create, do: :create, else: :update

                  case AshPhoenix.Form.get_form(socket.assigns.form, params["path"]) do
                    %{type: :create} ->
                      [{socket.assigns.current_path, capability}]

                    _form ->
                      [
                        {socket.assigns.current_path, capability},
                        {socket.assigns.current_path, :delete}
                      ]
                  end

                _ ->
                  nil
              end

            case permission do
              nil ->
                {:cont, socket}

              capabilities ->
                permissions = Permissions.load(socket.assigns.current_user)

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

                if Enum.all?(capabilities, fn {path, capability} ->
                     Permissions.can?(permissions, path, capability)
                   end) do
                  {:cont, socket}
                else
                  {:halt, put_flash(socket, :error, "You do not have permission to do that.")}
                end
            end
          end)

        {:cont, socket}
    end
  end

  def on_mount(:live_user_optional, _params, _session, socket) do
    if socket.assigns[:current_user] do
      {:cont, socket}
    else
      {:cont, assign(socket, :current_user, nil)}
    end
  end

  def on_mount(:live_user_required, _params, _session, socket) do
    if socket.assigns[:current_user] do
      {:cont, socket}
    else
      {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/sign-in")}
    end
  end

  def on_mount(:live_no_user, _params, _session, socket) do
    if socket.assigns[:current_user] do
      {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/")}
    else
      {:cont, assign(socket, :current_user, nil)}
    end
  end

  defp authorize_page(socket, path) do
    permissions = socket.assigns.permissions

    cond do
      Permissions.can_access_path?(permissions, path) ->
        if socket.assigns.live_action == :create and
             not Permissions.can?(permissions, path, :create) do
          {:halt,
           socket
           |> put_flash(:error, "You do not have permission to create that.")
           |> redirect(to: ~p"/")}
        else
          {:cont, socket}
        end

      is_nil(permissions.user) and not Permissions.public_path?(permissions, path) ->
        {:halt, redirect(socket, to: ~p"/sign-in")}

      true ->
        {:halt,
         socket
         |> put_flash(:error, "You do not have access to that page.")
         |> redirect(to: ~p"/")}
    end
  end
end

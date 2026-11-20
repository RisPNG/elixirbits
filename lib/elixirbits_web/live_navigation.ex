defmodule ElixirbitsWeb.LiveNavigation do
  import Phoenix.Component
  import Phoenix.LiveView

  @items [
    %{code: "HOME", name: "Home", icon: "hero-home", parent: nil, url: "dashboard"},
    %{code: "DP", name: "Components", icon: "hero-squares-2x2", parent: nil, url: nil},
    %{
      code: "LT",
      name: "Design Standards",
      icon: nil,
      parent: "DP",
      url: "dashboard/dev_panel/design_standards"
    }
  ]
  @by_code Map.new(@items, &{&1.code, &1})

  def on_mount(:timezone, _params, _session, socket) do
    socket =
      assign_new(socket, :user_timezone, fn ->
        timezone =
          if is_nil(socket.parent_pid), do: (get_connect_params(socket) || %{})["user_timezone"]

        if is_binary(timezone) and match?({:ok, _}, DateTime.now(timezone)),
          do: timezone,
          else: "Etc/UTC"
      end)

    {:cont, socket}
  end

  def on_mount(:app_nav, _params, _session, socket) do
    nav_open? = (get_connect_params(socket) || %{})["nav_open"] != false

    socket =
      socket
      |> assign(:nav, %{
        items: @items,
        path: "/dashboard",
        open?: nav_open?,
        staged?: false,
        active_codes: [],
        open_codes: nil
      })
      |> attach_hook(:app_nav_path, :handle_params, fn _params, uri, socket ->
        path = String.trim_trailing(URI.parse(uri).path, "/")

        entry =
          Enum.find(socket.assigns.nav.items, fn entry ->
            entry.url &&
              (path == "/" <> entry.url ||
                 (entry.url != "dashboard" and String.starts_with?(path, "/" <> entry.url <> "/")))
          end)

        active_codes = branch_codes(entry, @by_code)

        {:cont,
         update(socket, :nav, fn nav ->
           %{
             nav
             | path: path,
               active_codes: active_codes,
               open_codes:
                 if(nav.path == path, do: nav.open_codes || active_codes, else: active_codes)
           }
         end)}
      end)
      |> attach_hook(:app_nav_events, :handle_event, fn
        "toggle_nav", params, socket ->
          compact? = params["layout"] == "compact"

          {:halt,
           update(socket, :nav, fn nav ->
             open_codes =
               if (compact? or !nav.open?) and nav.open_codes == [],
                 do: nav.active_codes,
                 else: nav.open_codes

             %{
               nav
               | open?: if(compact?, do: nav.open?, else: !nav.open?),
                 open_codes: open_codes,
                 staged?:
                   if(compact?,
                     do: nav.staged?,
                     else: Enum.any?(nav.items, &(&1.parent in open_codes))
                   )
             }
           end)}

        "toggle_nav_section", %{"code" => code} = params, socket ->
          nav = socket.assigns.nav
          compact? = params["layout"] == "compact"

          case Map.get(@by_code, code) do
            nil ->
              {:halt, socket}

            entry ->
              ancestors = Enum.drop_while(nav.open_codes, &(&1 != entry.parent))

              open_codes =
                if (compact? or nav.open?) and code in nav.open_codes,
                  do: ancestors,
                  else: [code | ancestors]

              {:halt,
               assign(socket, :nav, %{
                 nav
                 | open?: nav.open? or !compact?,
                   open_codes: open_codes,
                   staged?: if(compact?, do: nav.staged?, else: !nav.open?)
               })}
          end

        _event, _params, socket ->
          {:cont, socket}
      end)

    {:cont, socket}
  end

  defp branch_codes(%{code: code, parent: parent}, by_code),
    do: [code | branch_codes(Map.get(by_code, parent), by_code)]

  defp branch_codes(nil, _by_code), do: []
end

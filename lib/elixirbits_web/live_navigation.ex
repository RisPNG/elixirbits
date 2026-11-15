defmodule ElixirbitsWeb.LiveNavigation do
  import Phoenix.Component
  import Phoenix.LiveView

  @items [
    %{code: "HOME", name: "Home", icon: "hero-home", parent: nil, url: "dashboard"},
    %{code: "DP", name: "Components", icon: "hero-squares-2x2", parent: nil, url: nil},
    %{
      code: "LT",
      name: "Layout Test",
      icon: nil,
      parent: "DP",
      url: "dashboard/dev_panel/layout_test"
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
    socket =
      socket
      |> assign(:nav, %{
        items: @items,
        path: "/dashboard",
        open?: true,
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

        {:cont,
         update(socket, :nav, fn nav ->
           %{nav | path: path, open_codes: nav.open_codes || branch_codes(entry, @by_code)}
         end)}
      end)
      |> attach_hook(:app_nav_events, :handle_event, fn
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

  defp branch_codes(%{code: code, parent: parent}, by_code),
    do: [code | branch_codes(Map.get(by_code, parent), by_code)]

  defp branch_codes(nil, _by_code), do: []
end

defmodule ElixirbitsWeb.DashboardLive.Index do
  use ElixirbitsWeb, :live_view

  on_mount {Layouts, :dashboard_layout}

  embed_templates "index_compact.html"

  @shortcut_icons %{
    "dashboard/dev_panel/design_standards" => "hero-squares-2x2"
  }

  @impl true
  def mount(_params, _session, socket) do
    items = socket.assigns.nav.items
    by_parent = Enum.group_by(items, & &1.parent)
    by_code = Map.new(items, &{&1.code, &1})

    destinations =
      items
      |> Enum.filter(&(&1.url not in [nil, "", "dashboard"]))
      |> Enum.group_by(fn entry ->
        root =
          entry
          |> Stream.unfold(fn
            nil -> nil
            item -> {item, Map.get(by_code, item.parent)}
          end)
          |> Enum.at(-1)

        if Map.has_key?(by_parent, root.code), do: root.code
      end)

    groups =
      for entry <- items, shortcuts = destinations[entry.code], shortcuts do
        %{id: "dashboard-home-group-#{entry.code}", name: entry.name, shortcuts: shortcuts}
      end

    groups =
      case destinations do
        %{nil => shortcuts} ->
          [
            %{
              id: "dashboard-home-direct-shortcuts",
              name: "Workspace sections",
              shortcuts: shortcuts
            }
            | groups
          ]

        _ ->
          groups
      end

    {:ok,
     assign(socket, page_title: "Home", launcher_groups: groups, shortcut_icons: @shortcut_icons)}
  end
end

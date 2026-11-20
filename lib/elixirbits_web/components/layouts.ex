defmodule ElixirbitsWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality used by your application.
  """
  use ElixirbitsWeb, :html

  import Phoenix.LiveView, only: [attach_hook: 4, get_connect_params: 1]

  # root.html.heex contains the shared HTML document. The other templates define the page shells and dashboard navigation.
  embed_templates "layouts/{root,index}.html"
  embed_templates "layouts/dashboard.html", suffix: "_template"
  embed_templates "layouts/dashboard_compact.html", suffix: "_template"

  @no_nav %{
    items: [],
    organization: nil,
    user: nil,
    timezone_form: nil,
    timezone_options: [],
    path: nil,
    open?: false,
    staged?: false,
    active_codes: [],
    open_codes: []
  }

  def on_mount(:dashboard_layout, _params, _session, socket) do
    socket =
      socket
      |> assign(:compact_layout?, (get_connect_params(socket) || %{})["compact_layout"] == true)
      |> attach_hook(:dashboard_layout, :handle_event, fn
        "dashboard_layout", %{"compact" => compact}, socket when is_boolean(compact) ->
          {:halt, assign(socket, :compact_layout?, compact)}

        "dashboard_layout", _params, socket ->
          {:halt, socket}

        _event, _params, socket ->
          {:cont, socket}
      end)

    {:cont, socket}
  end

  def on_mount({:collection_layout, id}, params, session, socket) do
    {:cont, socket} = __MODULE__.on_mount(:dashboard_layout, params, session, socket)

    socket =
      socket
      |> assign(:collection_state, %{})
      |> attach_hook(:collection_state, :handle_info, fn
        {:collection_state_change, ^id, state}, socket ->
          state = Map.new(state, fn {key, value} -> {to_string(key), value} end)
          {:halt, assign(socket, :collection_state, state)}

        _message, socket ->
          {:cont, socket}
      end)

    {:cont, socket}
  end

  def on_mount({:entry_sections, [{first, _, _} | _] = sections}, params, session, socket) do
    {:cont, socket} = __MODULE__.on_mount(:dashboard_layout, params, session, socket)

    socket =
      socket
      |> assign(:entry_sections, sections)
      |> assign(:entry_section, first)
      |> attach_hook(:entry_sections, :handle_event, fn
        "entry_section", %{"section" => section}, socket ->
          if List.keymember?(socket.assigns.entry_sections, section, 0) do
            {:halt, assign(socket, :entry_section, section)}
          else
            {:halt, socket}
          end

        "entry_section", _params, socket ->
          {:halt, socket}

        _event, _params, socket ->
          {:cont, socket}
      end)

    {:cont, socket}
  end

  def show_invalid_entry(socket, form) do
    socket = assign(socket, :form, to_form(form))

    if socket.assigns.compact_layout? do
      invalid_fields =
        form
        |> AshPhoenix.Form.errors(for_path: :all)
        |> Enum.flat_map(fn
          {[], errors} -> Keyword.keys(errors)
          {[field | _], [_ | _]} -> [field]
          {_path, []} -> []
        end)

      section =
        Enum.find_value(socket.assigns.entry_sections, socket.assigns.entry_section, fn
          {id, _label, fields} -> if Enum.any?(fields, &(&1 in invalid_fields)), do: id
        end)

      assign(socket, :entry_section, section)
    else
      socket
    end
  end

  @doc """
  Renders the dashboard layout.

  ## Examples

      <Layouts.dashboard flash={@flash}>
        <h1>Content</h1>
      </Layouts.dashboard>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :nav, :map,
    default: @no_nav,
    doc: "the navigation chrome state assigned by `LiveUserAuth`'s `:app_nav` hook"

  attr :user_timezone, :string, default: "Etc/UTC"

  attr :content_class, :any,
    default: "w-full space-y-6",
    doc: "the class for the inner content container"

  slot :inner_block, required: true

  def dashboard(assigns) do
    assigns =
      assigns
      |> assign(:by_parent, Enum.group_by(assigns.nav.items, & &1.parent))
      |> assign(:show_nav?, assigns.nav.items != [] or not is_nil(assigns.nav.user))

    dashboard_template(assign(assigns, :component, :dashboard))
  end

  attr :entries, :list, required: true
  attr :by_parent, :map, required: true
  attr :open_codes, :list, required: true
  attr :active_codes, :list, required: true
  attr :current_path, :string, default: nil
  attr :depth, :integer, required: true
  attr :expanded, :boolean, required: true

  defp nav_branch(assigns) do
    dashboard_template(assign(assigns, :component, :nav_branch))
  end

  attr :nav, :map, required: true
  attr :by_parent, :map, required: true
  attr :user_timezone, :string, required: true

  defp dashboard_compact(assigns) do
    dashboard_compact_template(assign(assigns, :component, :dashboard))
  end

  attr :entries, :list, required: true
  attr :by_parent, :map, required: true
  attr :open_codes, :list, required: true
  attr :active_codes, :list, required: true
  attr :current_path, :string, required: true
  attr :depth, :integer, required: true

  defp dashboard_compact_nav(assigns) do
    dashboard_compact_template(assign(assigns, :component, :nav_branch))
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  attr :class, :any, default: nil

  def theme_toggle(assigns) do
    ~H"""
    <div class={[
      "theme-toggle inset-surface relative grid grid-cols-[2rem_2rem_2rem] items-center rounded-full p-1 text-subcontent",
      @class
    ]}>
      <span aria-hidden="true" class="theme-toggle-indicator bg-brand overlay-opacity-[0.14]"></span>
      <button
        type="button"
        aria-label="Use system theme"
        class="theme-toggle-button [:root:not([data-theme])_&]:text-content"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4" />
      </button>

      <button
        type="button"
        aria-label="Use light theme"
        class="theme-toggle-button [[data-theme=light]_&]:text-content"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4" />
      </button>

      <button
        type="button"
        aria-label="Use dark theme"
        class="theme-toggle-button [[data-theme=dark]_&]:text-content"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4" />
      </button>
    </div>
    """
  end
end

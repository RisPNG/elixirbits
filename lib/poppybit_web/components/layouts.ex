defmodule PoppybitWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality used by your application.
  """
  use PoppybitWeb, :html

  # root.html.heex contains the shared HTML document. index.html.heex and dashboard.html.heex define the page shells.
  embed_templates "layouts/{root,index}.html"
  embed_templates "layouts/dashboard.html", suffix: "_template"

  @no_nav %{
    items: [],
    organization: nil,
    user: nil,
    timezone_form: nil,
    timezone_options: [],
    path: nil,
    open?: false,
    open_codes: []
  }

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
  attr :current_path, :string, default: nil
  attr :depth, :integer, required: true

  defp nav_branch(assigns) do
    dashboard_template(assign(assigns, :component, :nav_branch))
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  attr :class, :any, default: nil

  def theme_toggle(assigns) do
    ~H"""
    <div class={[
      "inset-surface grid grid-cols-[2rem_2rem_2rem] items-center rounded-full p-1 text-subcontent",
      @class
    ]}>
      <button
        type="button"
        aria-label="Use system theme"
        class="grid size-8 cursor-pointer place-items-center rounded-full transition-colors hover:overlay-dark focus-visible:outline-2 focus-visible:outline-brand [:root:not([data-theme])_&]:bg-brand [:root:not([data-theme])_&]:overlay-opacity-[0.14] [:root:not([data-theme])_&]:text-content"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4" />
      </button>

      <button
        type="button"
        aria-label="Use light theme"
        class="grid size-8 cursor-pointer place-items-center rounded-full transition-colors hover:overlay-dark focus-visible:outline-2 focus-visible:outline-brand [[data-theme=light]_&]:bg-brand [[data-theme=light]_&]:overlay-opacity-[0.14] [[data-theme=light]_&]:text-content"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4" />
      </button>

      <button
        type="button"
        aria-label="Use dark theme"
        class="grid size-8 cursor-pointer place-items-center rounded-full transition-colors hover:overlay-dark focus-visible:outline-2 focus-visible:outline-brand [[data-theme=dark]_&]:bg-brand [[data-theme=dark]_&]:overlay-opacity-[0.14] [[data-theme=dark]_&]:text-content"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4" />
      </button>
    </div>
    """
  end
end

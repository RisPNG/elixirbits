defmodule ElixirbitsWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality used by your application.
  """
  use ElixirbitsWeb, :html

  # Embed all files in layouts/* within this module. The default root.html.heex file contains the HTML skeleton of your application, namely HTML headers and other static content.
  embed_templates "layouts/*"

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
  Renders your app layout.

  This function is typically invoked from every template, and it often contains your application menu, sidebar, or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

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

  def app(assigns) do
    assigns =
      assigns
      |> assign(:by_parent, Enum.group_by(assigns.nav.items, & &1.parent))
      |> assign(:show_nav?, assigns.nav.items != [] or not is_nil(assigns.nav.user))

    ~H"""
    <div
      class="shell-surface grid min-h-screen grid-rows-[4rem_minmax(0,1fr)]"
      data-user-timezone={@user_timezone}
    >
      <header class={[
        "shell-surface sticky top-0 z-30 grid items-center gap-3 px-4",
        (@show_nav? && "grid-cols-[2.75rem_minmax(0,1fr)_max-content]") ||
          "grid-cols-[minmax(0,1fr)_max-content]"
      ]}>
        <button
          :if={@show_nav?}
          type="button"
          phx-click="toggle_nav"
          aria-label="Toggle navigation"
          aria-expanded={@nav.open?}
          aria-controls="app-navigation"
          class="grid size-11 place-items-center rounded-default text-subcontent transition-colors hover:overlay-dark focus-visible:outline-2 focus-visible:outline-brand cursor-pointer"
        >
          <.icon name="hero-bars-3" class="size-5" />
        </button>

        <a
          href="/"
          class="grid w-fit max-w-full grid-cols-[2rem_minmax(0,1fr)] items-center gap-2"
        >
          <img src={~p"/images/logo.svg"} width="32" alt="" />
          <span class="truncate text-sm font-semibold">
            {(@nav.organization && @nav.organization.name) || "Elixirbits"}
          </span>
        </a>

        <div class="grid grid-cols-[max-content_max-content] items-center gap-3">
          <.theme_toggle />
          <button
            :if={@nav.user}
            type="button"
            popovertarget="account-menu"
            aria-label="Open account menu"
            aria-haspopup="dialog"
            class="grid size-11 cursor-pointer place-items-center rounded-full bg-brand overlay-opacity-[0.14] text-content transition-colors hover:overlay-dark focus-visible:outline-2 focus-visible:outline-brand"
          >
            <img
              :if={@nav.user.display_pic_url}
              src={@nav.user.display_pic_url}
              alt=""
              class="size-10 rounded-full object-cover"
            />
            <span :if={!@nav.user.display_pic_url} class="text-sm font-semibold">
              {String.upcase(String.slice(@nav.user.display_name || to_string(@nav.user.email), 0, 1))}
            </span>
          </button>

          <.button :if={is_nil(@nav.user)} variant={:neutral} navigate={~p"/sign-in"}>
            Sign in
          </.button>
        </div>

        <div
          :if={@nav.user}
          id="account-menu"
          popover="auto"
          role="dialog"
          aria-label="Account"
          class="panel-surface fixed inset-auto mx-0 my-2 w-80 max-w-[calc(100vw-1rem)] max-h-[calc(100vh-5rem)] space-y-5 overflow-y-auto rounded-default border border-outline p-5 shadow-lg [position-anchor:auto] [position-area:block-end_span-inline-start] [position-try-fallbacks:flip-inline,flip-block,flip-block_flip-inline] [position-try-order:most-block-size]"
        >
          <div class="space-y-1">
            <p class="truncate text-sm font-semibold text-content">
              {@nav.user.display_name || to_string(@nav.user.email)}
            </p>

            <p :if={@nav.user.display_name} class="truncate text-xs text-subcontent">
              {@nav.user.email}
            </p>

            <p :if={@nav.user.roles != []} class="truncate text-xs text-subcontent">
              {Enum.join(@nav.user.roles, ", ")}
            </p>
          </div>

          <.form
            :let={form}
            for={@nav.timezone_form}
            id="user-timezone-form"
            phx-change="timezone_change"
            phx-submit="change_timezone"
            class="space-y-3 border-t border-outline pt-4"
          >
            <.input
              id="user-timezone"
              field={form[:timezone]}
              type="combobox"
              label="Timezone"
              options={@nav.timezone_options}
              placeholder="Automatic (browser)"
              clearable={false}
            />
            <p class="text-xs text-subcontent">Currently using {@user_timezone}</p>
            <.button type="submit" variant={:neutral}>Save timezone</.button>
          </.form>

          <.link
            href={~p"/sign-out"}
            class="grid min-h-10 items-center border-t border-outline pt-3 text-sm text-content underline-offset-4 hover:underline focus-visible:underline"
          >
            Sign out
          </.link>
        </div>
      </header>

      <div class={[
        "grid min-w-0",
        cond do
          @show_nav? and @nav.open? -> "grid-cols-[16rem_minmax(0,1fr)]"
          @show_nav? -> "grid-cols-[4.5rem_minmax(0,1fr)]"
          true -> "grid-cols-[minmax(0,1fr)]"
        end
      ]}>
        <aside
          :if={@show_nav?}
          id="app-navigation"
          aria-label="Application navigation"
          class="shell-surface sticky top-16 h-[calc(100dvh-4rem)] min-h-0 self-start overflow-y-auto"
        >
          <nav :if={@nav.open?} class="px-3 py-4">
            <.nav_branch
              entries={Map.get(@by_parent, nil, [])}
              by_parent={@by_parent}
              open_codes={@nav.open_codes}
              current_path={@nav.path}
              depth={0}
            />
          </nav>

          <nav :if={!@nav.open?} class="grid auto-rows-max justify-items-center gap-2 py-4">
            <.link
              navigate={~p"/"}
              aria-label="Home"
              title="Home"
              class={[
                "nav-item grid size-11 place-items-center focus-visible:outline-2 focus-visible:outline-brand",
                @nav.path == "/" && "bg-brand overlay-opacity-[0.14] text-content"
              ]}
            >
              <.icon
                name={
                  Enum.find_value(Map.get(@by_parent, nil, []), "hero-slash", fn entry ->
                    entry.url == "" && entry.icon
                  end)
                }
                class="size-5"
              />
            </.link>
          </nav>
        </aside>

        <main class="workspace-canvas min-w-0 px-8 py-10">
          <div class="mx-auto min-w-0 max-w-[80rem]">
            <div class={@content_class}>
              {render_slot(@inner_block)}
            </div>
          </div>
        </main>
      </div>
    </div>
    <.flash_group flash={@flash} />
    """
  end

  attr :entries, :list, required: true
  attr :by_parent, :map, required: true
  attr :open_codes, :list, required: true
  attr :current_path, :string, default: nil
  attr :depth, :integer, required: true

  defp nav_branch(assigns) do
    ~H"""
    <ul class="flex flex-col gap-1">
      <li :for={entry <- @entries}>
        <% current? =
          @current_path && not is_nil(entry.url) &&
            (@current_path == "/" <> entry.url ||
               (entry.url != "" && String.starts_with?(@current_path, "/" <> entry.url <> "/"))) %>
        <div class={[
          "nav-item grid items-center",
          (Map.get(@by_parent, entry.code, []) != [] &&
             "grid-cols-[minmax(0,1fr)_2.25rem]") || "grid-cols-[minmax(0,1fr)]",
          current? && "bg-brand overlay-opacity-[0.14] text-content"
        ]}>
          <.link
            :if={not is_nil(entry.url)}
            navigate={"/" <> entry.url}
            aria-current={
              if current?,
                do: if(@current_path == "/" <> entry.url, do: "page", else: "location")
            }
            class={[
              "grid min-h-10 min-w-0 items-center truncate rounded-default px-3 py-2 text-sm focus-visible:outline-2 focus-visible:outline-brand",
              if(@depth == 0,
                do: "grid-cols-[1.25rem_minmax(0,1fr)] gap-3 font-medium",
                else: "grid-cols-[minmax(0,1fr)]"
              )
            ]}
          >
            <.icon
              :if={@depth == 0}
              name={entry.icon || "hero-slash"}
              class="size-5"
            /> <span class="truncate">{entry.name}</span>
          </.link>

          <button
            :if={is_nil(entry.url)}
            type="button"
            phx-click="toggle_nav_section"
            phx-value-code={entry.code}
            aria-expanded={entry.code in @open_codes}
            aria-controls={if Map.get(@by_parent, entry.code, []) != [], do: "nav-#{entry.code}"}
            class={[
              "grid min-h-10 min-w-0 cursor-pointer items-center truncate rounded-default px-3 py-2 text-left text-sm focus-visible:outline-2 focus-visible:outline-brand",
              if(@depth == 0,
                do: "grid-cols-[1.25rem_minmax(0,1fr)] gap-3 font-medium",
                else: "grid-cols-[minmax(0,1fr)]"
              )
            ]}
          >
            <.icon
              :if={@depth == 0}
              name={entry.icon || "hero-slash"}
              class="size-5"
            /> <span class="truncate">{entry.name}</span>
          </button>

          <button
            :if={Map.get(@by_parent, entry.code, []) != []}
            type="button"
            phx-click="toggle_nav_section"
            phx-value-code={entry.code}
            aria-label={"Toggle #{entry.name}"}
            aria-expanded={entry.code in @open_codes}
            aria-controls={"nav-#{entry.code}"}
            class="grid size-9 place-items-center cursor-pointer rounded-full text-subcontent hover:overlay-dark transition-colors"
          >
            <.icon
              name="hero-chevron-down-micro"
              class={[
                "size-4 transition-transform",
                entry.code in @open_codes && "rotate-180 text-content"
              ]}
            />
          </button>
        </div>

        <div
          :if={Map.get(@by_parent, entry.code, []) != [] and entry.code in @open_codes}
          id={"nav-#{entry.code}"}
          class="ms-3 mt-1 border-l border-outline ps-2"
        >
          <.nav_branch
            entries={Map.get(@by_parent, entry.code, [])}
            by_parent={@by_parent}
            open_codes={@open_codes}
            current_path={@current_path}
            depth={@depth + 1}
          />
        </div>
      </li>
    </ul>
    """
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

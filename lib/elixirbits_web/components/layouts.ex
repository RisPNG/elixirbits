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

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

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
      |> assign(
        :timezone_options,
        if(assigns.nav.open? and not is_nil(assigns.nav.user),
          do:
            Tzdata.zone_list()
            |> Enum.filter(&match?({:ok, _}, DateTime.now(&1)))
            |> Enum.sort()
            |> Enum.map(&{&1, &1})
            |> then(&[{"Automatic (browser)", ""} | &1]),
          else: []
        )
      )

    ~H"""
    <div class="min-h-screen" data-user-timezone={@user_timezone}>
      <header class="grid grid-cols-[1fr_auto] items-center w-full min-h-16 px-8 border-b border-outline">
        <a :if={!@show_nav?} href="/" class="flex w-fit items-center gap-2">
          <img src={~p"/images/logo.svg"} width="36" alt="" />
          <span class="text-sm font-semibold">Elixirbits</span>
        </a>
        <.theme_toggle class="col-start-2" />
      </header>

      <main class="px-8 py-10">
        <div class={@content_class}>
          {render_slot(@inner_block)}
        </div>
      </main>
    </div>

    <div
      :if={@show_nav?}
      class="fixed left-8 top-4 z-40 w-80 rounded-default border border-outline bg-primary overlay-dark shadow-xl"
    >
      <div class="grid grid-cols-[2.75rem_1fr] items-center">
        <button
          type="button"
          phx-click="toggle_nav"
          aria-label="Toggle navigation"
          class="grid h-11 place-items-center text-content hover:overlay-dark transition-colors"
        >
          <.icon name={(@nav.open? && "hero-x-mark") || "hero-bars-3"} class="size-5" />
        </button>

        <div class="grid grid-cols-[1.25rem_1fr] items-center gap-2 h-11 px-3 border-l border-dashed border-outline">
          <img src={~p"/images/logo.svg"} width="20" alt="" />
          <span class="truncate text-sm font-semibold uppercase tracking-wide text-content">
            {(@nav.organization && @nav.organization.name) || "Elixirbits"}
          </span>
        </div>
      </div>

      <div
        :if={@nav.user}
        class="grid grid-cols-[1fr_1fr_1fr] items-center border-t border-dashed border-outline text-xs uppercase tracking-wide"
      >
        <span class="truncate px-3 py-2 text-content">
          {@nav.user.display_name || to_string(@nav.user.email)}
        </span>
        <span class="truncate px-3 py-2 text-subcontent border-l border-dashed border-outline">
          {Enum.join(@nav.user.roles, ", ")}
        </span>
        <a
          href={~p"/sign-out"}
          class="truncate px-3 py-2 text-brand hover:overlay-dark transition-colors border-l border-dashed border-outline"
        >
          Sign out
        </a>
      </div>

      <.link
        :if={is_nil(@nav.user)}
        navigate={~p"/sign-in"}
        class="block border-t border-outline px-3 py-2 text-sm text-brand hover:overlay-dark"
      >
        Sign in
      </.link>

      <nav
        :if={@nav.open?}
        class="max-h-[calc(100vh-9rem)] overflow-y-auto border-t border-dashed border-outline px-3 py-3"
      >
        <.nav_branch
          entries={Map.get(@by_parent, nil, [])}
          by_parent={@by_parent}
          open_codes={@nav.open_codes}
          current_path={@nav.path}
          depth={0}
        />

        <.form
          :let={form}
          :if={@nav.user}
          for={@nav.timezone_form}
          id="user-timezone-form"
          phx-change="timezone_change"
          phx-submit="change_timezone"
          class="mt-4 space-y-2 border-t border-outline pt-4"
        >
          <.input
            id="user-timezone"
            field={form[:timezone]}
            type="select"
            label="Timezone"
            options={@timezone_options}
            allow_clear={false}
            update_min_len={0}
            keep_options_on_select
          />
          <p class="text-xs text-subcontent">Currently using {@user_timezone}</p>
          <.button type="submit" variant={:neutral}>Save timezone</.button>
        </.form>
      </nav>
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
      <li :for={{entry, position} <- Enum.with_index(@entries, 1)}>
        <div class={[
          "grid items-center gap-2",
          (@depth == 0 && "grid-cols-[1.75rem_1fr_1.25rem]") || "grid-cols-[1fr_1.25rem]"
        ]}>
          <span :if={@depth == 0} class="text-xs tabular-nums text-subcontent">
            {String.pad_leading(to_string(position), 2, "0")}
          </span>

          <.link
            :if={not is_nil(entry.url)}
            navigate={"/" <> entry.url}
            class={[
              "truncate hover:overlay-dark transition-colors",
              (@depth == 0 && "text-base font-bold uppercase tracking-wide") || "text-sm",
              (@current_path == "/" <> entry.url && "text-brand") ||
                "text-subcontent"
            ]}
          >
            {entry.name}
          </.link>

          <button
            :if={is_nil(entry.url)}
            type="button"
            phx-click="toggle_nav_section"
            phx-value-code={entry.code}
            class={[
              "truncate text-left hover:overlay-dark transition-colors",
              (@depth == 0 && "text-base font-bold uppercase tracking-wide") || "text-sm",
              (entry.code in @open_codes && "text-brand") || "text-subcontent"
            ]}
          >
            {entry.name}
          </button>

          <button
            :if={Map.get(@by_parent, entry.code, []) != []}
            type="button"
            phx-click="toggle_nav_section"
            phx-value-code={entry.code}
            aria-label={"Toggle #{entry.name}"}
            class="grid place-items-center text-subcontent hover:overlay-dark transition-colors"
          >
            <.icon
              name="hero-chevron-down-micro"
              class={[
                "size-4 transition-transform",
                entry.code in @open_codes && "rotate-180 text-brand"
              ]}
            />
          </button>
        </div>

        <div
          :if={Map.get(@by_parent, entry.code, []) != [] and entry.code in @open_codes}
          class={["mt-1", (@depth == 0 && "pl-[1.75rem]") || "pl-3"]}
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
      "relative flex flex-row items-center border border-outline bg-secondary text-content rounded-full",
      @class
    ]}>
      <div class="absolute w-1/3 h-full rounded-full border border-outline bg-brand left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 transition-[left]" />

      <button
        class="relative flex p-2 cursor-pointer w-1/3 rounded-full hover:overlay-dark"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4" />
      </button>

      <button
        class="relative flex p-2 cursor-pointer w-1/3 rounded-full hover:overlay-dark"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4" />
      </button>

      <button
        class="relative flex p-2 cursor-pointer w-1/3 rounded-full hover:overlay-dark"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4" />
      </button>
    </div>
    """
  end
end

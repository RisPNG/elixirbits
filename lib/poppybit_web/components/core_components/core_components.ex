defmodule PoppybitWeb.CoreComponents do
  @moduledoc """
  Provides shared UI components and their supporting behavior. Component markup lives in the sibling `core_components.html.heex` template.

  The foundation for styling is Tailwind CSS, a utility-first CSS framework. Here are useful references:

    * [Tailwind CSS](https://tailwindcss.com) - the foundational framework we build on. You will use it for layout, sizing, flexbox, grid, and spacing.

    * [Heroicons](https://heroicons.com) - see `icon/1` for usage.

    * [Phoenix.Component](https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html) - the component system used by Phoenix. Components such as `<.link>` are defined there. The shared `<.form>` below applies the application's validation default and uses Phoenix's form renderer.

  """

  # Component setup

  use Phoenix.Component
  import Phoenix.Component, except: [form: 1]
  use Gettext, backend: PoppybitWeb.Gettext

  alias Phoenix.LiveView.JS
  alias PoppybitWeb.CoreComponents.Calendar, as: CalendarUtils

  embed_templates "core_components.html", suffix: "_template"

  # Shared foundations

  # Icons

  @doc """
  Renders a [Heroicon](https://heroicons.com) or a [Tabler icon](https://tabler.io/icons).

  Heroicons come in three styles – outline, solid, and mini. By default, the outline style is used, but solid and mini may be applied by using the `-solid` and `-mini` suffix.

  Tabler icons use a `tabler-` prefix and include icons that Heroicons does not provide, such as a floppy disk. They come in outline and filled styles. Outline is the default, and `-filled` selects the filled style.

  You can customize the size and colors of the icons by setting width, height, and theme color classes.

  Icons are extracted from the `deps/heroicons` and `deps/tabler_icons` directories and bundled within your compiled app.css by the plugins in `assets/vendor/heroicons.js` and `assets/vendor/tabler.js`.

  ## Examples

      <.icon name="hero-x-mark" />
      <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      <.icon name="tabler-device-floppy" />
  """
  attr :name, :string, required: true
  attr :class, :any, default: "size-4"

  def icon(%{name: "hero-" <> _} = assigns) do
    core_components_template(assign(assigns, :component, :icon))
  end

  def icon(%{name: "tabler-" <> _} = assigns) do
    core_components_template(assign(assigns, :component, :icon))
  end

  # Visibility commands

  def show(js \\ %JS{}, selector) do
    JS.show(js,
      to: selector,
      time: 300,
      transition:
        {"transition-all ease-out duration-300", "opacity-0 scale-95", "opacity-100 scale-100"}
    )
  end

  def hide(js \\ %JS{}, selector) do
    JS.hide(js,
      to: selector,
      time: 200,
      transition:
        {"transition-all ease-in duration-200", "opacity-100 scale-100", "opacity-0 scale-95"}
    )
  end

  # Page structure

  # Pages and headings

  @doc """
  Renders a page with shared actions above and below its content. The actions slot receives `:top` or `:bottom` so controls can keep distinct IDs.
  """
  attr :class, :any, default: "space-y-6"
  attr :rest, :global
  slot :title, required: true
  slot :actions
  slot :inner_block, required: true

  def page(assigns) do
    core_components_template(assign(assigns, :component, :page))
  end

  @doc """
  Renders a section header, or a page header with `level={1}`.
  """
  attr :level, :integer, values: [1, 2, 3], default: 2
  slot :inner_block, required: true
  slot :actions

  def header(assigns) do
    core_components_template(assign(assigns, :component, :header))
  end

  # Panels and repeated entries

  @doc """
  Renders a page section on a quiet panel surface.

  Form sections and detail groups share this surface, with their own `<.header>` inside.

  ## Examples

      <.card>
        <.header>
          Identity
        </.header>
        ...
      </.card>
  """
  attr :id, :string, default: nil
  attr :class, :any, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  def card(assigns) do
    core_components_template(assign(assigns, :component, :card))
  end

  @doc """
  Renders an inset panel inside a `<.card>` for nested detail.

  ## Examples

      <.card_inset>
        <p>Changes to permission grants require superuser authority.</p>
      </.card_inset>
  """
  attr :id, :string, default: nil
  attr :class, :any, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  def card_inset(assigns) do
    core_components_template(assign(assigns, :component, :card_inset))
  end

  @doc """
  Renders a collapsible panel with a summary and content inside one surface.

  The summary accepts custom content beside a right-aligned chevron. Native details behavior provides mouse and keyboard interaction. `open` sets the initial state, and the browser retains subsequent changes across LiveView updates.

  ## Examples

      <.collapse id="billing-protection">
        <:summary>
          <span class="font-medium">Billing protection</span>
          <span class="block text-subcontent">3 of 4 services active</span>
        </:summary>
        <p>Fraud and abuse monitoring is on.</p>
      </.collapse>
  """
  attr :id, :string, default: nil
  attr :class, :any, default: nil
  attr :open, :boolean, default: false
  attr :rest, :global, include: ~w(name)
  slot :summary, required: true
  slot :inner_block, required: true

  def collapse(assigns) do
    core_components_template(assign(assigns, :component, :collapse))
  end

  attr :label, :string, required: true
  attr :index, :integer, required: true
  attr :columns, :integer, default: 1, values: [1, 2]
  attr :class, :any, default: nil
  slot :sequence
  slot :actions
  slot :inner_block, required: true

  def entry_panel(assigns) do
    core_components_template(assign(assigns, :component, :entry_panel))
  end

  # Actions and dialogs

  # Buttons

  @doc """
  Renders an action with optional navigation and visual emphasis.

  ## Examples

      <.button phx-click="toggle_details" aria-pressed={@show_details}>Details</.button>
      <.button variant={:primary} type="submit">Sign in</.button>
      <.button variant={:text} navigate={~p"/dashboard/register"}>Create an account</.button>

  ## Variant

  Without a variant, actions use the standard filled control appearance. `aria-pressed` for toggles and `aria-selected` for tabs give the default control its selected brand tint.

      <.button aria-pressed={@show_details} phx-click="toggle_details">Details</.button>

  Use `:text` for a text action, `:primary` for the preferred action, `:neutral` for an outlined secondary action, and `:danger` for destructive confirmations. These choices describe visual emphasis for both navigation and event actions.

      <.button variant={:text} phx-click="request_magic_link">Email me a magic link</.button>
      <.button variant={:text} navigate={~p"/dashboard/register"}>Create an account</.button>

  Navigation attributes render a link, while other actions render a button. Inline and hierarchical navigation links can use `<.link>` directly. Input-owned compact controls use native buttons with the shared base styling.
  """
  attr :rest, :global,
    include:
      ~w(href navigate patch method download name value disabled type target rel popovertarget popovertargetaction)

  attr :variant, :atom, values: [nil, :text, :primary, :neutral, :danger], default: nil

  attr :tooltip, :string,
    default: nil,
    doc: "when set, hovering the button reveals this text following the cursor"

  attr :class, :any, default: nil
  slot :inner_block, required: true

  def button(%{rest: rest} = assigns) do
    variant =
      case assigns.variant do
        nil -> "min-h-11 px-4 py-2 text-sm whitespace-nowrap button-default"
        :text -> "text-sm button-text"
        :primary -> "min-h-11 px-4 py-2 text-sm whitespace-nowrap button-primary"
        :neutral -> "min-h-11 px-4 py-2 text-sm whitespace-nowrap button-neutral"
        :danger -> "min-h-11 px-4 py-2 text-sm whitespace-nowrap button-danger"
      end

    assigns =
      assign(assigns, :class, [
        "button-base",
        variant,
        assigns[:class]
      ])

    if rest[:href] || rest[:navigate] || rest[:patch] do
      core_components_template(assign(assigns, :component, :button_link))
    else
      core_components_template(assign(assigns, :component, :button))
    end
  end

  @action_defaults [
    create: {"hero-plus", "Add new"},
    read: {"hero-eye", "View"},
    history: {"hero-clock", "History"},
    update: {"hero-pencil-square", "Update"},
    save: {"tabler-device-floppy", "Save"},
    send: {"tabler-send", "Send"},
    archive: {"hero-archive-box", "Archive"},
    delete: {"hero-trash", "Delete"},
    back: {"hero-arrow-left", "Back"}
  ]

  @doc """
  Renders a record action as a bordered icon button.

  Use this component for consistent action buttons in page headers, table rows, and repeated sub-forms.

  Destructive actions use the error color. Other actions use neutral colors. Hovering darkens each button's existing surface. For a domain-specific action without its own entry, pass `icon` to override the icon while keeping the button's shape and colors, and pass a `tooltip` that describes the action.

  ## Examples

      <.action_button action={:read} navigate={~p"/inventory/categories"} />
      <.action_button action={:history} patch={@audit.history_path} />
      <.action_button action={:archive} phx-click="request_delete" phx-value-id={c.id} />
      <.action_button action={:save} type="submit" />
      <.action_button action={:create} icon="tabler-calendar-plus" tooltip="Add" />
  """
  attr :action, :atom,
    required: true,
    values: Keyword.keys(@action_defaults)

  attr :icon, :string, default: nil, doc: "overrides the action's default icon"

  attr :tooltip, :string,
    default: nil,
    doc:
      "overrides the action's default tooltip and accessible label unless aria-label is supplied; an empty string hides the tooltip and keeps the action's label"

  attr :class, :any, default: nil
  attr :rest, :global, include: ~w(href navigate patch method download name value disabled type)

  def action_button(assigns) do
    {icon, tooltip} = Keyword.fetch!(@action_defaults, assigns.action)

    variant =
      if assigns.action in [:archive, :delete],
        do: :danger,
        else: :neutral

    assigns =
      assign(assigns,
        icon: assigns.icon || icon,
        tooltip: assigns.tooltip || tooltip,
        variant: variant,
        rest:
          assigns.rest
          |> Map.put_new(:type, "button")
          |> Map.put_new(
            :"aria-label",
            if(assigns.tooltip in [nil, ""], do: tooltip, else: assigns.tooltip)
          )
      )

    core_components_template(assign(assigns, :component, :action_button))
  end

  # Dialogs and confirmation

  @doc """
  Renders a server-driven modal, shown only while `show` is true.

  ## Examples

      <.modal :if={@to_delete} id="confirm-delete" on_cancel={JS.push("cancel_delete")}>
        <:title>Confirm deletion</:title>
        <p>This cannot be undone.</p>
      </.modal>
  """
  attr :id, :string, required: true
  attr :show, :boolean, default: true
  attr :label, :string, default: "Dialog"
  attr :on_cancel, JS, default: %JS{}
  slot :title
  slot :inner_block, required: true

  def modal(assigns) do
    core_components_template(assign(assigns, :component, :modal))
  end

  @doc """
  Renders the deletion confirmation and the additional role-assignment warning when needed.
  """
  attr :label, :string, required: true
  attr :name, :string, required: true
  attr :remove_assignments?, :boolean, default: false

  def delete_confirmation(assigns) do
    core_components_template(assign(assigns, :component, :delete_confirmation))
  end

  # Feedback

  # Flash notices

  @doc """
  Renders flash notices.

  ## Examples

      <.flash kind={:info} flash={@flash} />
      <.flash kind={:info} phx-mounted={show("#flash")}>Welcome Back!</.flash>
  """
  attr :id, :string, doc: "the optional id of flash container"
  attr :flash, :map, default: %{}, doc: "the map of flash messages to display"
  attr :title, :string, default: nil
  attr :icon, :string, default: nil
  attr :kind, :atom, values: [:info, :error, :warning], doc: "used for styling and flash lookup"
  attr :duration, :integer, default: nil
  attr :show_spinner, :boolean, default: false
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the flash container"

  slot :inner_block, doc: "the optional inner block that renders the flash message"

  def flash(assigns) do
    assigns =
      assigns
      |> assign_flash_payload()
      |> assign_new(:id, fn -> "flash-#{assigns.kind}" end)

    core_components_template(assign(assigns, :component, :flash))
  end

  attr :flash, :map, required: true
  attr :id, :string, default: nil
  attr :id_prefix, :string, default: nil

  def flash_group(assigns) do
    flash_ids =
      if is_binary(assigns[:id_prefix]) && String.trim(assigns.id_prefix) != "" do
        id_prefix =
          assigns.id_prefix
          |> String.trim()
          |> String.trim_trailing("-")

        %{
          group: "#{id_prefix}-flash-group",
          client_error: "#{id_prefix}-client-error",
          server_error: "#{id_prefix}-server-error"
        }
      else
        %{
          group: assigns[:id] || "flash-group",
          client_error: "client-error",
          server_error: "server-error"
        }
      end

    assigns = assign(assigns, :flash_ids, flash_ids)

    core_components_template(assign(assigns, :component, :flash_group))
  end

  defp assign_flash_payload(assigns) do
    flash_content = Phoenix.Flash.get(assigns.flash, assigns.kind)

    default_icon =
      case assigns.kind do
        :info -> "hero-information-circle"
        :error -> "hero-exclamation-circle"
        :warning -> "hero-exclamation-triangle"
      end

    if is_map(flash_content) do
      assign(assigns, %{
        title: Map.get(flash_content, :title) || Map.get(flash_content, "title") || assigns.title,
        msg:
          Map.get(flash_content, :msg) || Map.get(flash_content, "msg") ||
            Map.get(flash_content, :message) || Map.get(flash_content, "message"),
        icon:
          Map.get(flash_content, :icon) || Map.get(flash_content, "icon") || assigns.icon ||
            default_icon,
        duration:
          Map.get(flash_content, :duration) || Map.get(flash_content, "duration") ||
            assigns.duration,
        show_spinner:
          Map.get(
            flash_content,
            :show_spinner,
            Map.get(flash_content, "show_spinner", assigns.show_spinner)
          )
      })
    else
      assign(assigns, %{
        msg: flash_content,
        icon: assigns.icon || default_icon
      })
    end
  end

  # Listings

  # Tables and lists

  @doc """
  Renders a table with generic styling.

  ## Examples

      <.table id="users" rows={@users}>
        <:col :let={user} label="id">{user.id}</:col>
        <:col :let={user} label="username">{user.username}</:col>
      </.table>
  """
  attr :id, :string, required: true
  attr :rows, :list, required: true
  attr :row_id, :any, default: nil, doc: "the function for generating the row id"
  attr :row_click, :any, default: nil, doc: "the function for handling phx-click on each row"

  attr :row_item, :any,
    default: &Function.identity/1,
    doc: "the function for mapping each row before calling the :col and :action slots"

  slot :col, required: true do
    attr :label, :string
  end

  slot :action, doc: "the slot for showing user actions in the last table column"

  def table(assigns) do
    assigns =
      with %{rows: %Phoenix.LiveView.LiveStream{}} <- assigns do
        assign(assigns, row_id: assigns.row_id || fn {id, _item} -> id end)
      end

    core_components_template(assign(assigns, :component, :table))
  end

  @doc """
  Renders a data list.

  ## Examples

      <.list>
        <:item title="Title">{@post.title}</:item>
        <:item title="Views">{@post.views}</:item>
      </.list>
  """
  slot :item, required: true do
    attr :title, :string, required: true
  end

  def list(assigns) do
    core_components_template(assign(assigns, :component, :list))
  end

  # Forms and inputs

  @color_space_options Poppybit.CoreUtils.Parse.color_options()

  # Form defaults

  @doc """
  Renders a Phoenix form with browser constraint validation disabled by default.

  Server validation and Phoenix form data, slots, CSRF protection, HTTP methods, and multipart uploads retain their native behavior. Pass `novalidate={false}` to enable browser constraint validation for a particular form.

  ## Examples

      <.form for={@form} phx-change="validate" phx-submit="save">
        <.input field={@form[:email]} type="email" label="Email" required />
      </.form>
  """
  attr :for, :any, required: true
  attr :action, :string
  attr :as, :atom
  attr :csrf_token, :any
  attr :errors, :list
  attr :method, :string
  attr :multipart, :boolean, default: false

  attr :rest, :global,
    include: ~w(autocomplete name rel enctype novalidate target),
    default: %{novalidate: true}

  slot :inner_block, required: true

  def form(assigns) do
    Phoenix.Component.form(assigns)
  end

  # Input controls

  # Clause order follows matching precedence: shared states and specialized controls must stay ahead of the fallback.

  @doc """
  Renders an input with label and error messages.

  A `Phoenix.HTML.FormField` may be passed as argument, which is used to retrieve the input name, id, and values. Otherwise all attributes may be passed explicitly.

  ## Types

  This function accepts all HTML input types, considering that:

    * `type="select"` renders a native HTML select for single choices and a searchable dropdown with tags for multiple choices.

    * `type="combobox"` renders the PetalComponents searchable combobox.

    * `type="checkbox"` is used exclusively to render boolean values.

    * `upload={@uploads.thing}` turns the field into a live file field.

  See https://developer.mozilla.org/en-US/docs/Web/HTML/Element/input for more information.

  ## Examples

  ```heex
  <.input field={@form[:email]} type="email" />
  <.input name="my-input" errors={["oh no!"]} />
  ```

  ## Select type

  When using `type="select"`, you must pass the `options` and optionally a `value` to mark which option should be preselected.

  ```heex
  <.input field={@form[:user_type]} type="select" options={["Admin": "admin", "User": "user"]} />
  ```

  For more information on what kind of data can be passed to `options` see [`options_for_select`](https://hexdocs.pm/phoenix_html/Phoenix.HTML.Form.html#options_for_select/2).

  ## File type

  File fields keep picked files in the browser until submission. Pass `upload` for LiveView uploads and give `stored` the URLs already held on the record, wrapping a single-file value in a list. `selection` accepts `"single"` for one replacement, `"singles"` for a collection picked one file at a time, or `"multiple"` for a collection picked together. Without `selection`, LiveView's `max_entries` or a native multipart field's `multiple` determines the mode. The real upload configuration's `max_entries` remains the queue capacity; `"single"` requires `max_entries: 1`. Picking a single replacement hides the stored preview until the replacement is canceled or saved. With previews enabled, `"singles"` displays the file count in the picker and one preview with controls inside it to browse the collection; thumbnail filenames appear in the top-left corner on hover or keyboard focus, and the current position appears in the bottom-right corner on hover. Without previews, `"single"` and `"singles"` show the filename inside the input; `"singles"` also shows the current position and stacked navigation arrows.

  `preview` defaults to `false`, which shows filenames. Setting it to `true` supplies image previews and the browser's native PDF viewer. The `stored_preview` and `pending_preview` slots override media rendering for stored URLs and pending upload entries. `preview_as` defaults to `"thumbnail"` when previews are enabled and `"tag"` otherwise. Explicit `"tag"` hides the media and shows its filename chip; `"thumbnail"` supplies the media frame and corner clear button. Single and singles thumbnail filenames appear inside the top-left corner on hover or keyboard focus, while multiple thumbnail filenames stay below the frame. Both layouts reveal the clear button on hover or keyboard focus. Use `thumbnail_class` to size the displayed frame, and `preview_caption` or `pending_caption` to override filenames.

  `editor` defaults to `false`. `true` opens a free crop for image selections, `%{width: 512, height: 512}` requires that exact output size, and `%{ratio: 16 / 9}` requires that crop ratio. Maps enable editing and re-encode the accepted crop in the browser. Editing requires `preview: true`, a `"single"` or `"singles"` selection, and LiveView's `auto_upload` to remain `false`. An image preview's Edit button prepares a replacement for that image; edits to stored files submit the original URL as `<upload.name>_replacements[entry.ref]` so the save handler can replace the right stored item. PDFs and other file types skip the image editor. Canceling the editor preserves the previous selection.

  Give `preview_id` the ID of a `<.file_preview>` destination to place a single or singles preview elsewhere in the same LiveView. Keep the destination mounted, including when previews are turned off. The input still owns the upload configuration, stored files, editor, and all media and caption slots; LiveView's native portal renders that one preview collection into the destination. Multiple selection keeps its previews inline. The destination's `class` controls its placement and size; use `thumbnail_class="h-full w-full"` on the input when the destination sets the thumbnail dimensions.

  Either way a LiveView rendering a file field handles exactly two events: `"remove_upload"` with `phx-value-url` for a stored file, and `"cancel_upload"` with `phx-value-ref` for a picked one. The editable modes (`"enabled"`, `"text"`, and `"text-enabled"`) keep the picker and those buttons. Other visible modes keep the previews, remove those buttons, and hide and disable the file control, leaving the field read-only while preserving the browser's picked files for pending previews. Hidden modes apply to the entire field, including its previews. `"hidden-disabled"` keeps the hidden native input disabled and retains the previews so switching modes preserves picked files.

  ```heex
  <.input
    type="file"
    name="portrait"
    label="Portrait"
    upload={@uploads.portrait}
    stored={List.wrap(@portrait)}
    preview={true}
    editor={%{width: 512, height: 512}}
    thumbnail_class="size-20"
  />
  ```

  ```heex
  <.input
    type="file"
    upload={@uploads.portrait}
    stored={List.wrap(@portrait)}
    preview={true}
    preview_id="portrait-preview"
    thumbnail_class="h-full w-full"
  />

  <.file_preview id="portrait-preview" class="size-20" />
  ```

  ## Render as

  The `render_as` attribute controls how the control is rendered:

    * `"enabled"`: the real input (default)
    * `"disabled"`: a lookalike span with the disabled input visual. No input is rendered, so the value does not submit
    * `"like-enabled"`: a lookalike span with the enabled input visual. No input is rendered, so the value does not submit
    * `"like-disabled"`: a lookalike span with the disabled input visual plus the real input rendered hidden, so native input behavior (submission) still works
    * `"hidden"` / `"hidden-enabled"`: the real input rendered hidden, so native input behavior still works
    * `"hidden-disabled"`: nothing is rendered, except file fields retain their disabled input and previews inside a hidden field to preserve picked files
    * `"text"` / `"text-enabled"`: the real editable input with a plain text visual; picker controls retain their popups, passwords show plain text without a visibility action, checkbox and switch show clickable state sentences, and radio shows only its selected value while preserving submission
    * `"text-disabled"`: plain text plus the real input rendered hidden, so native input behavior (submission) still works
  """
  attr :id, :any, default: nil
  attr :name, :any
  attr :label, :string, default: nil
  attr :value, :any

  attr :timezone, :string,
    default: nil,
    doc: "the display timezone, which defaults to the Ash form's user timezone, then UTC"

  attr :tooltip, :string,
    default: nil,
    doc: "when set, hovering anywhere over the input reveals this text following the cursor"

  attr :type, :string,
    default: "text",
    values: ~w(checkbox color combobox date datetime-local email file month number password radio
               search select switch tel text textarea time url week hidden)

  attr :field, Phoenix.HTML.FormField,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"

  attr :form_field, :any,
    default: nil,
    doc: "internal: the original form field, preserved across the input/1 recursion"

  attr :errors, :list, default: []
  attr :checked, :boolean, doc: "the checked flag for checkbox inputs"
  attr :prompt, :string, default: nil, doc: "the prompt for select inputs"

  attr :country_placeholder, :string,
    default: "+00",
    doc: "the placeholder for a telephone field's country calling code selector"

  attr :options, :list,
    doc:
      "select and combobox options, or radio {label, value} tuples with optional description and disabled metadata in a third keyword list"

  attr :clearable, :boolean, default: true, doc: "allows clearing a single combobox selection"
  attr :max_items, :integer, default: nil, doc: "maximum number of combobox selections"

  attr :class, :any, default: nil, doc: "the input class to use over defaults"
  attr :error_class, :any, default: nil, doc: "the input error class to use over defaults"

  attr :render_as, :string,
    default: "enabled",
    values:
      ~w(enabled disabled like-enabled like-disabled hidden hidden-enabled hidden-disabled text text-enabled text-disabled)

  attr :variant, :string,
    default: "default",
    values: ~w(default alt card),
    doc:
      "checkbox and switch use \"default\" for a boxed field or \"alt\" for an inline control; radio uses \"default\" for circles or \"card\" for selectable cards"

  attr :upload, :any,
    default: nil,
    doc: "a `Phoenix.LiveView.UploadConfig` to render as a file field"

  attr :stored, :list,
    default: [],
    doc: "for a file field, the URLs of the files already held on the record"

  attr :selection, :string,
    default: nil,
    values: [nil, "single", "singles", "multiple"],
    doc:
      "for a file field, one replacement, a collection picked individually, or a collection picked together"

  attr :preview, :boolean,
    default: false,
    doc: "for a file field, shows built-in image and native PDF previews"

  attr :preview_id, :string,
    default: nil,
    doc:
      "for single or singles selection, the ID of a file_preview destination rendered elsewhere in the same LiveView"

  attr :editor, :any,
    default: false,
    doc:
      "with previews and single or singles selection, false, true for a free crop, or a map containing positive width and height or a positive ratio"

  attr :preview_as, :string,
    default: nil,
    values: [nil, "tag", "thumbnail"],
    doc:
      "how a file field draws each preview: \"tag\" for a removable chip, \"thumbnail\" for an image tile with a corner clear button"

  attr :thumbnail_class, :any,
    default: "h-36 w-full",
    doc: "the size of a thumbnail's media frame"

  slot :stored_preview, doc: "for a file field, overrides one stored file's media, given its URL"

  slot :pending_preview,
    doc: "for a file field, overrides one picked file's media, given its upload entry"

  slot :preview_caption, doc: "for a file field, renders a stored file's caption, given its URL"

  slot :pending_caption,
    doc: "for a file field, renders a picked file's caption, given its upload entry"

  attr :rest, :global,
    default: %{autocomplete: "off"},
    include: ~w(accept autocomplete capture cols disabled form list max maxlength min minlength
                 multiple pattern placeholder readonly required rows size step)

  # Field preparation

  def input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    {form_timezone, changed_fields, change_side, removed?} =
      case field.form.source do
        %AshPhoenix.Form{opts: opts, data: data} ->
          {get_in(opts[:context] || %{}, [:shared, :user_timezone]),
           data && Ash.Resource.get_metadata(data, :audit_changed_fields),
           data && Ash.Resource.get_metadata(data, :audit_change_side),
           data && Ash.Resource.get_metadata(data, :audit_removed?)}

        _ ->
          {nil, nil, nil, nil}
      end

    rest =
      if changed_fields && MapSet.member?(changed_fields, field.field) do
        assigns.rest
        |> Map.put(:"data-audit-changed", "true")
        |> Map.put(:"data-audit-side", to_string(change_side || :previous))
        |> Map.put(:"data-audit-removed", removed? && "true")
      else
        assigns.rest
      end

    rest =
      if rest[:"data-audit-changed"] in [true, "true"] do
        rest
        |> Map.put(:"data-audit-changed", "true")
        |> Map.put_new(:"data-audit-side", "previous")
        |> Map.put_new(
          :"aria-description",
          cond do
            removed? -> "Removed value"
            rest[:"data-audit-side"] == "current" -> "Different from the selected revision"
            true -> "Changed by this revision"
          end
        )
      else
        rest
      end

    assigns
    |> assign(
      field: nil,
      form_field: field,
      rest: rest,
      timezone: assigns.timezone || form_timezone || "Etc/UTC",
      id: assigns.id || field.id
    )
    |> assign(:errors, Enum.map(errors, &translate_error(&1)))
    |> assign_new(:name, fn ->
      if assigns.rest[:multiple], do: field.name <> "[]", else: field.name
    end)
    |> assign_new(:value, fn ->
      case {field.value, field.form.source} do
        {{:error, _reason}, %AshPhoenix.Form{raw_params: params}} ->
          Map.get(params, to_string(field.field))

        _ ->
          field.value
      end
    end)
    |> input()
  end

  # Tooltip wrapper

  def input(%{tooltip: tooltip} = assigns) when is_binary(tooltip) and tooltip != "" do
    core_components_template(assign(assigns, :component, :input_tooltip))
  end

  # File input state

  def input(%{type: type, upload: upload} = assigns) when type == "file" or not is_nil(upload) do
    selection =
      assigns.selection ||
        cond do
          upload -> if(upload.max_entries == 1, do: "single", else: "multiple")
          assigns.rest[:multiple] in [nil, false] -> "single"
          true -> "multiple"
        end

    if upload && selection == "single" && upload.max_entries != 1,
      do: raise(ArgumentError, "single selection requires max_entries: 1")

    editor =
      case assigns.editor do
        false ->
          false

        true ->
          true

        %{width: width, height: height} = options
        when map_size(options) == 2 and is_integer(width) and width > 0 and
               is_integer(height) and height > 0 ->
          options

        %{ratio: ratio} = options
        when map_size(options) == 1 and is_number(ratio) and ratio > 0 ->
          options

        _ ->
          raise ArgumentError,
                "editor must be false, true, %{width: positive_integer, height: positive_integer}, or %{ratio: positive_number}"
      end

    if editor != false and selection == "multiple",
      do: raise(ArgumentError, "image editing requires single or singles selection")

    if editor != false and not assigns.preview,
      do: raise(ArgumentError, "image editing requires preview: true")

    if (editor != false and upload) && upload.auto_upload?,
      do: raise(ArgumentError, "image editing requires auto_upload: false")

    entries = if upload, do: upload.entries, else: []
    file_count = length(assigns.stored) + length(entries)
    placeholder = assigns.rest[:placeholder]

    file_inline =
      (selection != "multiple" && (!assigns.preview || selection == "singles")) ||
        placeholder not in [nil, ""]

    file_steps = selection == "singles" && !assigns.preview
    file_detached = assigns.preview_id != nil && selection != "multiple"
    first_entry = List.first(entries)
    first_url = List.first(assigns.stored)

    editable =
      assigns.render_as in ["enabled", "text", "text-enabled", "hidden", "hidden-enabled"]

    editable_like =
      (editable || assigns.render_as == "like-enabled") &&
        assigns.rest[:disabled] in [nil, false] && assigns.rest[:readonly] in [nil, false]

    file_placeholder =
      if editable_like,
        do: placeholder || if(selection == "multiple", do: "Choose files", else: "Choose a file"),
        else: ""

    {file_name, file_caption, file_caption_value} =
      cond do
        selection == "single" && first_entry ->
          {first_entry.client_name, assigns.pending_caption, first_entry}

        first_url ->
          {if(String.starts_with?(first_url, "data:"),
             do: "File",
             else: Path.basename(URI.parse(first_url).path || first_url)
           ), assigns.preview_caption, first_url}

        first_entry ->
          {first_entry.client_name, assigns.pending_caption, first_entry}

        true ->
          {if(assigns[:value] in [nil, ""], do: file_placeholder, else: assigns.value), [], nil}
      end

    file_id = if upload, do: upload.ref, else: assigns.id || assigns[:name]
    preview_as = assigns.preview_as || if(assigns.preview, do: "thumbnail", else: "tag")
    text_look = assigns.render_as in ["text", "text-enabled", "text-disabled"]

    messages =
      if upload do
        entries
        |> Enum.flat_map(&upload_errors(upload, &1))
        |> Enum.concat(upload_errors(upload))
        |> Enum.uniq()
        |> Enum.map(fn
          :too_large -> "File is too large (max #{div(upload.max_file_size, 1_000_000)}MB)."
          :too_many_files -> "Too many files (max #{upload.max_entries})."
          :not_accepted -> "Unsupported file type."
          _other -> "Upload failed."
        end)
      else
        []
      end

    assigns =
      assigns
      |> assign(:file_id, file_id)
      |> assign(:selection, selection)
      |> assign(
        :file_upload,
        if(upload && selection != "multiple", do: %{upload | max_entries: 1}, else: upload)
      )
      |> assign(:file_entries, entries)
      |> assign(:file_has_value, file_count > 0 || assigns[:value] not in [nil, ""])
      |> assign(:file_has_placeholder, placeholder not in [nil, ""])
      |> assign(:file_inline, file_inline)
      |> assign(:file_steps, file_steps)
      |> assign(:file_detached, file_detached)
      |> assign(:file_name, file_name)
      |> assign(:file_caption, file_caption)
      |> assign(:file_caption_value, file_caption_value)
      |> assign(:file_position, "#{if(file_count > 0, do: 1, else: 0)}/#{file_count}")
      |> assign(
        :file_count_label,
        "#{file_count} #{if(file_count == 1, do: "file", else: "files")}"
      )
      |> assign(:file_entry_refs, Jason.encode!(Enum.map(entries, & &1.ref)))
      |> assign(:file_editor, Jason.encode!(editor))
      |> assign(:file_editor_enabled, editor != false)
      |> assign(:file_editable, editable)
      |> assign(:file_editable_like, editable_like)
      |> assign(:preview_as, preview_as)
      |> assign(:text_look, text_look)
      |> assign(
        :placeholder,
        if editable_like do
          if(assigns.label && !text_look && placeholder in [nil, ""], do: " ", else: placeholder)
        end
      )
      |> assign(:file_placeholder, file_placeholder)
      |> assign(
        :file_readonly_name,
        if(assigns[:value] in [nil, ""], do: file_placeholder, else: assigns.value)
      )
      |> assign(:errors, assigns.errors ++ messages)
      |> assign(
        :rest,
        if(!upload && selection == "multiple",
          do: Map.put(assigns.rest, :multiple, true),
          else: Map.delete(assigns.rest, :multiple)
        )
        |> Map.delete(:placeholder)
      )
      |> assign(
        :previews_class,
        if preview_as == "thumbnail" do
          [
            "grid gap-2",
            !file_detached && selection != "singles" && "mt-3",
            file_detached && "h-full",
            if(selection == "multiple",
              do: "grid-cols-[1fr_1fr_1fr_1fr]",
              else: "grid-cols-[1fr]"
            )
          ]
        else
          if(selection == "singles", do: "grid grid-cols-[1fr]", else: "flex flex-wrap gap-1 p-1")
        end
      )

    core_components_template(assign(assigns, :component, :input_file))
  end

  # Hidden and text appearances

  def input(%{render_as: "hidden-disabled"} = assigns) do
    ~H""
  end

  def input(%{render_as: render_as} = assigns) when render_as in ["hidden", "hidden-enabled"] do
    assigns = assign(assigns, :render_as, "enabled")

    core_components_template(assign(assigns, :component, :input_hidden_wrapper))
  end

  def input(%{render_as: render_as, type: "number"} = assigns)
      when render_as in ["enabled", "text", "text-enabled"] do
    placeholder = assigns.rest[:placeholder]
    text_look = render_as in ["text", "text-enabled"]
    base_id = assigns.id || assigns.name

    assigns =
      assigns
      |> assign(:id, base_id)
      |> assign(:number_id, "#{base_id}-number-input")
      |> assign(
        :number_steps_disabled,
        assigns.rest[:disabled] || assigns.rest[:readonly] ||
          String.downcase(to_string(assigns.rest[:step])) == "any"
      )
      |> assign(:text_look, text_look)
      |> assign(
        :placeholder,
        if assigns.rest[:disabled] in [nil, false] && assigns.rest[:readonly] in [nil, false] do
          if(assigns.label && placeholder in [nil, ""], do: " ", else: placeholder)
        end
      )
      |> assign(
        :rest,
        assigns.rest |> Map.delete(:placeholder) |> Map.put_new(:"phx-debounce", "blur")
      )

    core_components_template(assign(assigns, :component, :input_number_text))
  end

  def input(%{render_as: render_as, type: type} = assigns)
      when render_as in ["text", "text-enabled"] and
             type in ["email", "password", "search", "text", "url"] do
    rest =
      if assigns.rest[:disabled] in [nil, false] && assigns.rest[:readonly] in [nil, false],
        do: assigns.rest,
        else: Map.delete(assigns.rest, :placeholder)

    assigns =
      assigns
      |> assign(:render_as, "enabled")
      |> assign(:rest, Map.put_new(rest, :"phx-debounce", "blur"))
      |> assign(
        :text_input_class,
        assigns.class ||
          [
            "block w-full appearance-none bg-transparent border-0 text-sm text-content overflow-hidden text-ellipsis whitespace-nowrap focus:outline-none focus:ring-0 focus-visible:underline disabled:overlay-dark disabled:cursor-not-allowed disabled:text-subcontent",
            if(assigns[:label], do: "min-h-6 py-1", else: "min-h-11 text-center"),
            assigns.errors != [] && (assigns.error_class || "text-error")
          ]
      )

    core_components_template(assign(assigns, :component, :input_text))
  end

  # Color input state

  def input(%{type: "color"} = assigns) do
    editable = assigns.render_as in ["enabled", "text", "text-enabled"]
    text_look = assigns.render_as in ["text", "text-enabled", "text-disabled"]
    disabled_look = assigns.render_as in ["disabled", "like-disabled"]
    value = assigns[:value] || ""
    base_id = assigns.id || assigns.name
    placeholder = assigns.rest[:placeholder]

    color_state =
      case Poppybit.CoreUtils.Parse.inspect_color(value) do
        {:ok, state} -> state
        {:error, _reason} -> nil
      end

    format = color_state && color_state.format

    parent_form =
      case assigns[:form_field] do
        %Phoenix.HTML.FormField{form: form} -> form
        _ -> to_form(%{}, as: "_color_#{base_id}")
      end

    base_field_key =
      case assigns[:form_field] do
        %Phoenix.HTML.FormField{field: field} -> field
        _ -> :color
      end

    format_field_key = String.to_atom("#{base_field_key}_color_space")
    requested_format = format || parent_form[format_field_key].value

    {format_label, format} =
      Enum.find(@color_space_options, {"HEX", "hex"}, fn {_label, mode} ->
        mode == requested_format
      end)

    format_field = %{parent_form[format_field_key] | value: format}

    assigns =
      assigns
      |> assign(:value, value)
      |> assign(:id, base_id)
      |> assign(:color_id, "#{base_id}-color-input")
      |> assign(:color_picker_id, "#{base_id}-color-picker")
      |> assign(:color_popover_id, "#{base_id}-color-popover")
      |> assign(:color_error_id, "#{base_id}-color-error")
      |> assign(:color_editable, editable)
      |> assign(:color_format, format_label)
      |> assign(:color_format_field, format_field)
      |> assign(:color_format_id, "#{base_id}_color_space_select")
      |> assign(:color_format_options, @color_space_options)
      |> assign(:color_swatch, color_state && color_state.swatch)
      |> assign(:color_state, %{
        valid: color_state != nil || String.trim(value) == "",
        value: value,
        format: format,
        label: format_label,
        swatch: color_state && color_state.swatch,
        rgba: color_state && color_state.rgba,
        error:
          if(color_state == nil && String.trim(value) != "", do: "Enter a supported color value.")
      })
      |> assign(:text_look, text_look)
      |> assign(:disabled_look, disabled_look)
      |> assign(:include_hidden_input, assigns.render_as in ["like-disabled", "text-disabled"])
      |> assign(
        :placeholder,
        if (editable || assigns.render_as == "like-enabled") &&
             assigns.rest[:disabled] in [nil, false] && assigns.rest[:readonly] in [nil, false] do
          if(assigns.label && placeholder in [nil, ""], do: " ", else: placeholder)
        end
      )
      |> assign(
        :rest,
        assigns.rest
        |> Map.delete(:placeholder)
        |> Map.put_new(:"phx-debounce", "blur")
        |> Map.put(
          :"aria-describedby",
          Enum.join(
            Enum.reject([assigns.rest[:"aria-describedby"], "#{base_id}-color-error"], &is_nil/1),
            " "
          )
        )
      )

    core_components_template(assign(assigns, :component, :input_color))
  end

  # Text and choice displays

  def input(%{render_as: render_as, type: "textarea"} = assigns)
      when render_as in ["text", "text-enabled"] do
    rest =
      if assigns.rest[:disabled] in [nil, false] && assigns.rest[:readonly] in [nil, false],
        do: assigns.rest,
        else: Map.delete(assigns.rest, :placeholder)

    assigns =
      assigns
      |> assign(:render_as, "enabled")
      |> assign(:rest, Map.put_new(rest, :"phx-debounce", "blur"))
      |> assign(
        :text_input_class,
        assigns.class ||
          [
            "block w-full min-h-6 bg-transparent border-0 py-1 text-sm text-content whitespace-pre-wrap focus:outline-none focus:ring-0 focus-visible:underline disabled:overlay-dark disabled:cursor-not-allowed disabled:text-subcontent",
            assigns.errors != [] && (assigns.error_class || "text-error")
          ]
      )

    core_components_template(assign(assigns, :component, :input_textarea_text))
  end

  def input(%{render_as: render_as, type: type} = assigns)
      when render_as in ["text", "text-enabled", "text-disabled"] and
             type in ["checkbox", "switch"] do
    {checked_text, unchecked_text} =
      case type do
        "checkbox" -> {"enabled", "disabled"}
        "switch" -> {"on", "off"}
      end

    {checked_text, unchecked_text} =
      if assigns.label in [nil, ""],
        do: {String.capitalize(checked_text), String.capitalize(unchecked_text)},
        else: {checked_text, unchecked_text}

    text_editable = render_as in ["text", "text-enabled"]

    assigns =
      assigns
      |> assign_new(:checked, fn ->
        Phoenix.HTML.Form.normalize_value("checkbox", assigns[:value])
      end)
      |> assign(:checked_text, checked_text)
      |> assign(:unchecked_text, unchecked_text)
      |> assign(:text_editable, text_editable)
      |> assign(
        :text_rest,
        if(text_editable,
          do: %{for: assigns.id},
          else: Map.drop(assigns.rest, [:autocomplete, :placeholder])
        )
      )

    core_components_template(assign(assigns, :component, :input_radio_text))
  end

  def input(%{render_as: render_as, type: "radio"} = assigns)
      when render_as in ["text", "text-enabled"] do
    input(assign(assigns, :render_as, "text-disabled"))
  end

  def input(%{render_as: render_as, type: type} = assigns)
      when render_as in ["disabled", "like-enabled", "like-disabled"] and
             type in ["checkbox", "switch"] do
    assigns =
      assigns
      |> assign_new(:value, fn -> nil end)
      |> assign_new(:checked, fn ->
        Phoenix.HTML.Form.normalize_value("checkbox", assigns[:value])
      end)

    checked = assigns.checked
    disabled_look = render_as in ["disabled", "like-disabled"]
    display_alt = assigns.variant == "alt"

    box_class =
      case type do
        "checkbox" ->
          [
            "h-5 w-5 shrink-0 rounded-default border bg-center bg-no-repeat bg-[length:100%_100%]",
            disabled_look && "cursor-not-allowed",
            display_alt && disabled_look && "overlay-dark",
            checked &&
              "bg-control-check",
            case {checked, disabled_look} do
              {true, true} -> "bg-secondary border-secondary text-content"
              {true, false} -> "bg-brand border-brand text-brand-content"
              {false, _} -> "bg-transparent border-outline"
            end
          ]

        "switch" ->
          [
            "relative shrink-0 w-11 h-6 rounded-full border before:absolute before:top-[1px] before:left-[1px] before:h-5 before:w-5 before:rounded-full",
            disabled_look && "cursor-not-allowed",
            display_alt && disabled_look && "overlay-dark",
            checked && "before:translate-x-5",
            case {checked, disabled_look} do
              {true, true} ->
                "bg-secondary border-secondary before:bg-subcontent"

              {true, false} ->
                "bg-brand border-brand before:bg-brand-content"

              {false, _} ->
                "bg-transparent border-outline before:bg-subcontent"
            end
          ]
      end

    assigns =
      assigns
      |> assign(:disabled_look, disabled_look)
      |> assign(:display_alt, display_alt)
      |> assign(:box_class, box_class)
      |> assign(:span_rest, Map.drop(assigns.rest, [:autocomplete, :placeholder]))

    core_components_template(assign(assigns, :component, :input_boolean_display))
  end

  def input(%{render_as: render_as} = assigns)
      when render_as in [
             "disabled",
             "like-enabled",
             "like-disabled",
             "text-disabled"
           ] do
    assigns = assign_new(assigns, :value, fn -> nil end)

    display =
      case {assigns.type, assigns.value} do
        {type, value} when type in ["select", "combobox"] and is_list(value) ->
          value
          |> Enum.map(&option_display_label(&1, assigns[:options] || []))
          |> Enum.join(", ")

        {type, value} when type in ["select", "combobox"] ->
          option_display_label(value, assigns[:options] || [])

        {_type, value} ->
          value
      end

    display =
      case display do
        %DateTime{} = instant ->
          instant

        value when is_binary(value) and assigns.type in ~w(date datetime-local time week month) ->
          case DateTime.from_iso8601(value) do
            {:ok, instant, _offset} -> instant
            _ -> value
          end

        value ->
          value
      end

    display =
      case display do
        %DateTime{} = instant ->
          local = DateTime.shift_zone!(instant, assigns.timezone || "Etc/UTC")

          case assigns.type do
            "date" ->
              Calendar.strftime(local, "%Y-%m-%d")

            "time" ->
              Calendar.strftime(local, "%H:%M")

            "month" ->
              Calendar.strftime(local, "%Y-%m")

            "week" ->
              {year, week} = :calendar.iso_week_number(Date.to_erl(DateTime.to_date(local)))
              "#{year}-W#{String.pad_leading(Integer.to_string(week), 2, "0")}"

            _ ->
              Calendar.strftime(local, "%-d %b %Y, %H:%M %Z")
          end

        value ->
          value
      end

    filled = display not in [nil, ""]

    placeholder =
      if render_as == "like-enabled" && assigns.rest[:disabled] in [nil, false] &&
           assigns.rest[:readonly] in [nil, false] && assigns.label in [nil, ""],
         do: assigns.rest[:placeholder]

    disabled_look = render_as in ["disabled", "like-disabled"]
    text_look = render_as == "text-disabled"
    include_hidden_input = render_as in ["like-disabled", "text-disabled"]

    span_class =
      if text_look do
        # A label means the value is stacked under it and keeps its compact height. Without one, it sits in a row beside real fields, so it takes the field height and centers on it.
        stacked = assigns.type == "textarea" or assigns[:label] not in [nil, ""]

        [
          if(assigns.type == "textarea",
            do: "block whitespace-pre-wrap",
            else: "overflow-hidden text-ellipsis whitespace-nowrap"
          ),
          if(stacked,
            do: "block w-full min-h-6 py-1",
            else: "flex w-full min-h-11 items-center justify-center text-center"
          ),
          "text-sm bg-transparent",
          (filled && "text-content") || "text-subcontent",
          assigns.errors != [] && (assigns.error_class || "text-error")
        ]
      else
        [
          if(assigns.type == "textarea",
            do: "block whitespace-pre-wrap",
            else: "flex items-center overflow-hidden whitespace-nowrap"
          ),
          "w-full min-h-11 px-3 rounded-default border bg-transparent",
          (assigns.errors == [] || assigns.error_class) && "border-outline",
          if(filled || render_as != "like-enabled",
            do: [
              "input-floating-control",
              assigns.type == "textarea" && "input-floating-textarea"
            ],
            else: "py-2"
          ),
          cond do
            disabled_look -> "overlay-dark cursor-not-allowed text-subcontent"
            not filled and placeholder not in [nil, ""] -> "text-subcontent"
            true -> "text-content"
          end,
          assigns.errors != [] && (assigns.error_class || "border-error")
        ]
      end

    assigns =
      assigns
      |> assign(:display, if(filled, do: display, else: placeholder))
      |> assign(:text_look, text_look)
      |> assign(:include_hidden_input, include_hidden_input)
      |> assign(:span_class, span_class)
      |> assign(:span_rest, Map.drop(assigns.rest, [:autocomplete, :placeholder]))

    core_components_template(assign(assigns, :component, :input_display))
  end

  # Native controls and option pickers

  def input(%{type: "hidden"} = assigns) do
    core_components_template(assign(assigns, :component, :input_hidden))
  end

  def input(%{type: "checkbox", variant: "alt"} = assigns) do
    assigns =
      assign_new(assigns, :checked, fn ->
        Phoenix.HTML.Form.normalize_value("checkbox", assigns[:value])
      end)

    core_components_template(assign(assigns, :component, :input_checkbox_alt))
  end

  def input(%{type: "checkbox"} = assigns) do
    assigns =
      assign_new(assigns, :checked, fn ->
        Phoenix.HTML.Form.normalize_value("checkbox", assigns[:value])
      end)

    core_components_template(assign(assigns, :component, :input_checkbox))
  end

  def input(%{type: "radio"} = assigns) do
    assigns =
      assigns
      |> assign(
        :radio_options,
        Enum.map(assigns.options, fn
          {label, value} ->
            %{label: label, value: value, description: nil, disabled: false}

          {label, value, options} ->
            %{
              label: label,
              value: value,
              description: options[:description],
              disabled: options[:disabled] || false
            }
        end)
      )
      |> assign(
        :radio_group_rest,
        Map.take(assigns.rest, [:"aria-label", :"aria-labelledby", :"aria-describedby"])
      )
      |> assign(
        :radio_rest,
        Map.drop(assigns.rest, [:disabled, :"aria-label", :"aria-labelledby", :"aria-describedby"])
      )

    core_components_template(assign(assigns, :component, :input_radio))
  end

  def input(%{type: "switch", variant: "alt"} = assigns) do
    assigns =
      assign_new(assigns, :checked, fn ->
        Phoenix.HTML.Form.normalize_value("checkbox", assigns[:value])
      end)

    core_components_template(assign(assigns, :component, :input_switch_alt))
  end

  def input(%{type: "switch"} = assigns) do
    assigns =
      assign_new(assigns, :checked, fn ->
        Phoenix.HTML.Form.normalize_value("checkbox", assigns[:value])
      end)

    core_components_template(assign(assigns, :component, :input_switch))
  end

  def input(%{type: "combobox", rest: %{disabled: disabled}} = assigns)
      when disabled not in [false, nil] do
    options = assigns[:options] || []
    value = assigns[:value]

    display =
      case value do
        v when is_list(v) ->
          v |> Enum.map(&option_display_label(&1, options)) |> Enum.join(", ")

        v ->
          option_display_label(v, options)
      end

    hidden_name =
      if assigns.rest[:multiple],
        do: String.trim_trailing(assigns.name, "[]") <> "[]",
        else: assigns.name

    hidden_values =
      value
      |> List.wrap()
      |> Enum.reject(&(&1 in [nil, ""]))

    assigns =
      assigns
      |> assign(:display, display)
      |> assign(:hidden_name, hidden_name)
      |> assign(:hidden_values, hidden_values)
      |> assign(
        :div_attrs,
        assigns.rest
        |> Map.filter(fn {key, _value} ->
          key in [
            :role,
            :"aria-label",
            :"aria-labelledby",
            :"aria-describedby",
            :"aria-description"
          ] or
            String.starts_with?(to_string(key), "data-")
        end)
        |> then(fn attrs ->
          if map_size(attrs) > 0, do: Map.put_new(attrs, :role, "group"), else: attrs
        end)
      )

    core_components_template(assign(assigns, :component, :input_combobox_disabled))
  end

  def input(%{type: "select", rest: rest} = assigns)
      when not is_map_key(rest, :multiple) or rest.multiple in [false, nil] do
    assigns =
      assigns
      |> assign_new(:value, fn -> nil end)
      |> assign(:text_look, assigns.render_as in ["text", "text-enabled"])
      |> assign(
        :select_prompt,
        if(rest[:disabled] in [nil, false] && rest[:readonly] in [nil, false], do: assigns.prompt)
      )
      |> assign(
        :rest,
        if(rest[:disabled] in [nil, false] && rest[:readonly] in [nil, false],
          do: rest,
          else: Map.delete(rest, :placeholder)
        )
      )

    core_components_template(assign(assigns, :component, :input_select))
  end

  def input(%{type: type} = assigns) when type in ~w(select combobox) do
    text_look = assigns.render_as in ["text", "text-enabled"]
    placeholder = assigns.rest[:placeholder]

    value =
      case assigns[:value] do
        "" ->
          blank_choice? =
            assigns.options
            |> Enum.flat_map(fn
              {_label, entries} when is_list(entries) -> entries
              option -> [option]
            end)
            |> Enum.any?(fn
              {_label, value, _options} -> to_string(value) == ""
              {_label, value} -> to_string(value) == ""
              value -> to_string(value) == ""
            end)

          if blank_choice?, do: "", else: nil

        value ->
          value
      end

    assigns =
      assigns
      |> assign(:value, value)
      |> assign(:text_look, text_look)
      |> assign(:picker_id, assigns.id || assigns.name)
      |> assign(
        :picker_rest,
        assigns.rest
        |> Map.drop([
          :multiple,
          :required,
          :disabled,
          :readonly,
          :placeholder,
          :form,
          :autocomplete
        ])
        |> then(fn attrs ->
          if Enum.any?(
               [:"aria-label", :"aria-labelledby", :"aria-describedby"],
               &Map.has_key?(attrs, &1)
             ),
             do: Map.put_new(attrs, :role, "group"),
             else: attrs
        end)
      )
      |> assign(
        :placeholder,
        cond do
          assigns.rest[:disabled] not in [nil, false] ||
              assigns.rest[:readonly] not in [nil, false] ->
            nil

          text_look ->
            placeholder || assigns.prompt || "Choose an option"

          assigns.label && placeholder in [nil, ""] ->
            " "

          true ->
            placeholder || assigns.prompt || "Choose an option"
        end
      )

    core_components_template(assign(assigns, :component, :input_combobox))
  end

  # Textarea, date/time and telephone controls

  def input(%{type: "textarea"} = assigns) do
    editable_like =
      assigns.rest[:disabled] in [nil, false] && assigns.rest[:readonly] in [nil, false]

    rest = if editable_like, do: assigns.rest, else: Map.delete(assigns.rest, :placeholder)
    assigns = assign(assigns, :rest, Map.put_new(rest, :"phx-debounce", "blur"))

    if assigns[:label] do
      placeholder = assigns.rest[:placeholder]

      assigns =
        assigns
        |> assign(:rest, Map.delete(assigns.rest, :placeholder))
        |> assign(
          :placeholder,
          if(editable_like, do: if(placeholder in [nil, ""], do: " ", else: placeholder))
        )

      core_components_template(assign(assigns, :component, :input_textarea_labeled))
    else
      core_components_template(assign(assigns, :component, :input_textarea))
    end
  end

  def input(%{type: "date"} = assigns), do: vcalendar_input(assigns)
  def input(%{type: "datetime-local"} = assigns), do: vcalendar_input(assigns)
  def input(%{type: "time"} = assigns), do: vcalendar_input(assigns)
  def input(%{type: "week"} = assigns), do: vcalendar_input(assigns)
  def input(%{type: "month"} = assigns), do: vcalendar_input(assigns)

  def input(%{type: "tel"} = assigns) do
    {dial_code, number, iso} = Poppybit.CoreUtils.Parse.to_phone(assigns[:value] || "")

    parent_form =
      case assigns[:form_field] do
        %Phoenix.HTML.FormField{form: form} -> form
        _ -> to_form(%{}, as: "_tel_#{assigns[:id] || assigns[:name]}")
      end

    base_field_key =
      case assigns[:form_field] do
        %Phoenix.HTML.FormField{field: field} -> field
        _ -> :phone
      end

    country_field_key = String.to_atom("#{base_field_key}_country_code")
    country_field = %{parent_form[country_field_key] | value: iso}
    wrapper_id = "#{assigns[:id] || assigns[:name]}_tel_wrapper"

    composite_value =
      cond do
        dial_code && number != "" -> "#{dial_code}#{number}"
        dial_code -> dial_code
        true -> assigns[:value] || ""
      end

    placeholder = assigns.rest[:placeholder]

    assigns =
      assigns
      |> assign(:text_look, assigns.render_as in ["text", "text-enabled"])
      |> assign(
        :rest,
        assigns.rest |> Map.delete(:placeholder) |> Map.put_new(:"phx-debounce", "blur")
      )
      |> assign(
        :placeholder,
        if assigns.rest[:disabled] in [nil, false] && assigns.rest[:readonly] in [nil, false] do
          if(placeholder in [nil, ""], do: " ", else: placeholder)
        end
      )
      |> assign(
        :country_placeholder,
        if(assigns.rest[:disabled] in [nil, false] && assigns.rest[:readonly] in [nil, false],
          do: assigns.country_placeholder
        )
      )
      |> assign(:country_field, country_field)
      |> assign(:country_id, country_field.id)
      |> assign(:country_name, country_field.name)
      |> assign(:wrapper_id, wrapper_id)
      |> assign(:countries_json, Poppybit.CoreUtils.Options.Phones.dial_codes_json())
      |> assign(:country_options, Poppybit.CoreUtils.Options.Phones.options())
      |> assign(:number_value, number)
      |> assign(:composite_value, composite_value)

    core_components_template(assign(assigns, :component, :input_tel))
  end

  # Text input fallback

  def input(assigns) do
    editable_like =
      assigns.rest[:disabled] in [nil, false] && assigns.rest[:readonly] in [nil, false]

    rest = if editable_like, do: assigns.rest, else: Map.delete(assigns.rest, :placeholder)

    assigns =
      assigns
      |> assign(:rest, Map.put_new(rest, :"phx-debounce", "blur"))

    if assigns[:label] && assigns.type in ~w(color email file number password search text url) do
      placeholder = assigns.rest[:placeholder]

      assigns =
        assigns
        |> assign(:rest, Map.delete(assigns.rest, :placeholder))
        |> assign(
          :placeholder,
          if(editable_like, do: if(placeholder in [nil, ""], do: " ", else: placeholder))
        )

      core_components_template(assign(assigns, :component, :input_labeled))
    else
      core_components_template(assign(assigns, :component, :input_text_control))
    end
  end

  # Choice labels

  defp option_display_label(value, options) when value not in [nil, ""] do
    options
    |> Enum.flat_map(fn
      {_label, entries} when is_list(entries) -> entries
      option -> [option]
    end)
    |> Enum.find_value(to_string(value), fn opt ->
      {opt_value, opt_label} =
        case opt do
          {label, value, _options} -> {value, label}
          {l, v} -> {v, l}
          %{value: v, label: l} -> {v, l}
          %{"value" => v, "label" => l} -> {v, l}
          v -> {v, to_string(v)}
        end

      if opt_value == value or to_string(opt_value) == to_string(value),
        do: opt_label
    end)
  end

  defp option_display_label(value, _options) when value in [nil, ""], do: ""

  # Password controls

  attr :id, :any, required: true
  attr :disabled, :any, default: false

  defp password_visibility_toggle(assigns) do
    core_components_template(assign(assigns, :component, :password_visibility_toggle))
  end

  # Date and time pickers

  defp vcalendar_input(assigns) do
    timezone = assigns.timezone || "Etc/UTC"

    editable_like =
      assigns.rest[:disabled] in [nil, false] && assigns.rest[:readonly] in [nil, false]

    rest = if editable_like, do: assigns.rest, else: Map.delete(assigns.rest, :placeholder)

    value =
      case assigns[:value] do
        %DateTime{} = instant ->
          instant

        value when is_binary(value) ->
          case DateTime.from_iso8601(value) do
            {:ok, instant, _offset} -> instant
            _ -> value
          end

        value ->
          value
      end

    value =
      case value do
        %DateTime{} = instant ->
          local = DateTime.shift_zone!(instant, timezone)

          case assigns.type do
            "datetime-local" ->
              local |> DateTime.to_naive() |> NaiveDateTime.to_iso8601()

            "date" ->
              local |> DateTime.to_date() |> Date.to_iso8601()

            "time" ->
              Calendar.strftime(local, "%H:%M")

            "month" ->
              Calendar.strftime(local, "%Y-%m")

            "week" ->
              {year, week} = :calendar.iso_week_number(Date.to_erl(DateTime.to_date(local)))
              "#{year}-W#{String.pad_leading(Integer.to_string(week), 2, "0")}"
          end

        %Date{} = date ->
          Date.to_iso8601(date)

        %Time{} = time ->
          Time.to_iso8601(time)

        value ->
          Phoenix.HTML.Form.normalize_value("text", value)
      end

    assigns =
      assign(assigns,
        rest: rest,
        value: value,
        timezone: timezone,
        today: timezone |> DateTime.now!() |> DateTime.to_date() |> Date.to_iso8601(),
        text_look: assigns.render_as in ~w(text text-enabled)
      )

    if assigns[:label] do
      placeholder = assigns.rest[:placeholder]

      assigns =
        assigns
        |> assign(:rest, Map.delete(assigns.rest, :placeholder))
        |> assign(
          :placeholder,
          if editable_like do
            if(placeholder in [nil, ""] and not assigns.text_look, do: " ", else: placeholder)
          end
        )

      core_components_template(assign(assigns, :component, :input_calendar_labeled))
    else
      core_components_template(assign(assigns, :component, :input_calendar))
    end
  end

  # Color input events

  def on_mount(:inputs, _params, _session, socket) do
    socket =
      Phoenix.LiveView.attach_hook(socket, :core_input_options, :handle_event, fn
        "color_input", %{"id" => id, "selector_id" => selector_id} = params, socket ->
          colors = socket.private[:core_colors] || %{}
          value = Map.get(params, "value", "")
          format = Map.get(params, "format", "hex")
          operation = params["operation"]

          if operation == "release" do
            {:halt, %{},
             Phoenix.LiveView.put_private(socket, :core_colors, Map.delete(colors, id))}
          else
            source =
              case colors[id] do
                %{value: ^value, color: nil} -> {:ok, nil}
                %{value: ^value} = state -> {:ok, state}
                _ -> Poppybit.CoreUtils.Parse.inspect_color(value)
              end

            result =
              if String.ends_with?(id, "-color-input") and
                   selector_id == String.replace_suffix(id, "-color-input", "_color_space_select") and
                   Enum.any?(@color_space_options, fn {_label, mode} -> mode == format end) do
                case operation do
                  "validate" ->
                    source

                  "convert" ->
                    with {:ok, state} <- source do
                      if state && state.format != format,
                        do: Poppybit.CoreUtils.Parse.convert_color(state.color, format),
                        else: {:ok, state}
                    end

                  "pick" ->
                    previous =
                      case source do
                        {:ok, state} -> state
                        _ -> nil
                      end

                    with %{"r" => r, "g" => g, "b" => b, "a" => a}
                         when is_number(r) and is_number(g) and is_number(b) and is_number(a) <-
                           params["rgba"],
                         alpha =
                           if(previous && !params["alpha_changed"], do: previous.rgba.a, else: a),
                         {:ok, picked} <- Color.new([r / 255, g / 255, b / 255, alpha * 1.0]) do
                      Poppybit.CoreUtils.Parse.convert_color(picked, format)
                    else
                      _ -> {:error, "must be a supported color value"}
                    end

                  _ ->
                    {:error, "must be a supported color value"}
                end
              else
                {:error, "must be a supported color value"}
              end

            case result do
              {:ok, state} ->
                state =
                  state || %{value: value, format: format, swatch: nil, rgba: nil, color: nil}

                socket =
                  Phoenix.LiveView.put_private(socket, :core_colors, Map.put(colors, id, state))

                label =
                  Enum.find_value(@color_space_options, fn {label, mode} ->
                    if mode == state.format, do: label
                  end)

                {:halt, state |> Map.delete(:color) |> Map.merge(%{valid: true, label: label}),
                 socket}

              {:error, _reason} ->
                {:halt, %{valid: false, error: "Enter a supported color value."}, socket}
            end
          end

        _event, _params, socket ->
          {:cont, socket}
      end)

    {:cont, socket}
  end

  # Validation messages

  defp error(assigns) do
    core_components_template(assign(assigns, :component, :error))
  end

  @doc """
  Translates an error message using gettext.
  """
  def translate_error({msg, opts}) do
    # When using gettext, we typically pass the strings we want to translate as a static argument:
    #
    #     # Translate the number of files with plural rules
    #     dngettext("errors", "1 file", "%{count} files", count)
    #
    # However the error messages in our forms and APIs are generated dynamically, so we need to translate them by calling Gettext with our gettext backend as first argument. Translations are available in the errors.po file (as we use the "errors" domain).
    if count = opts[:count] do
      Gettext.dngettext(PoppybitWeb.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(PoppybitWeb.Gettext, "errors", msg, opts)
    end
  end

  @doc """
  Translates the errors for a field from a keyword list of errors.
  """
  def translate_errors(errors, field) when is_list(errors) do
    for {^field, {msg, opts}} <- errors, do: translate_error({msg, opts})
  end

  # File uploads and previews

  # Preview destination and collection

  @doc """
  Renders a destination for a file input's preview. Give the input the same `preview_id`, and keep this destination mounted in the same LiveView. The input owns the files, editing, captions, and media slots; the destination supplies their placement and styling.
  """
  attr :id, :string, required: true
  attr :class, :any, default: "h-36 w-full"
  attr :rest, :global

  def file_preview(assigns) do
    core_components_template(assign(assigns, :component, :file_preview))
  end

  defp file_previews(assigns) do
    core_components_template(assign(assigns, :component, :file_previews))
  end

  attr :input_id, :any, required: true
  attr :url, :string, default: nil
  attr :entry, :any, default: nil
  attr :preview, :boolean, default: false
  attr :selection, :string, required: true
  attr :preview_as, :string, required: true
  attr :thumbnail_class, :any, required: true
  attr :media_slot, :any, default: []
  attr :caption_slot, :any, default: []
  attr :editable, :boolean, default: false
  attr :edit_enabled, :boolean, default: false
  attr :disabled, :any, default: false
  attr :text_look, :boolean, default: false
  attr :hidden, :boolean, default: false
  attr :target, :any, default: nil

  defp file_preview_item(assigns) do
    {name, content_type, identity} =
      if assigns.entry do
        entry = assigns.entry

        content_type =
          if entry.client_type in [nil, ""],
            do: MIME.from_path(entry.client_name),
            else: entry.client_type

        {entry.client_name, content_type, entry.ref}
      else
        url = assigns.url

        content_type =
          if String.starts_with?(url, "data:") do
            url
            |> String.trim_leading("data:")
            |> String.split([";", ","], parts: 2)
            |> List.first()
          else
            MIME.from_path(URI.parse(url).path || url)
          end

        name =
          if String.starts_with?(url, "data:") do
            cond do
              String.starts_with?(content_type, "image/") -> "Image"
              content_type == "application/pdf" -> "PDF"
              true -> "File"
            end
          else
            Path.basename(URI.parse(url).path || url)
          end

        {name, content_type, Base.url_encode64(:crypto.hash(:sha256, url), padding: false)}
      end

    media_available =
      assigns.media_slot != [] or
        ((assigns.preview || assigns.selection != "multiple") and
           (String.starts_with?(content_type, "image/") or content_type == "application/pdf"))

    assigns =
      assigns
      |> assign(:file_name, name)
      |> assign(:content_type, content_type)
      |> assign(:identity, identity)
      |> assign(:media_available, media_available)
      |> assign(:caption_value, assigns.entry || assigns.url)
      |> assign(:caption_tag, if(assigns.text_look, do: "label", else: "span"))
      |> assign(:caption_rest, if(assigns.text_look, do: %{for: assigns.input_id}, else: %{}))
      |> assign(:caption_used, assigns.caption_slot != [] or assigns.media_slot == [])
      |> assign(
        :caption_hover,
        assigns.selection in ["single", "singles"] && assigns.preview &&
          assigns.preview_as == "thumbnail" &&
          media_available
      )

    core_components_template(assign(assigns, :component, :file_preview_item))
  end

  # Image editing

  def image_editor(assigns) do
    core_components_template(assign(assigns, :component, :image_editor))
  end

  # Event calendar

  # Rendering configuration

  @day_minutes 1440
  @base 1000
  @gutter 48
  @hour 60
  @header 40

  @event_styles %{
    brand: %{
      fill: "fill-brand",
      label_fill: "fill-brand-content",
      stroke: "stroke-brand",
      solid_bar: "bg-brand text-brand-content",
      outline_bar: "border border-brand bg-primary text-content",
      dot: "bg-brand"
    },
    info: %{
      fill: "fill-info",
      label_fill: "fill-content",
      stroke: "stroke-info",
      solid_bar: "bg-info text-content",
      outline_bar: "border border-info bg-primary text-content",
      dot: "bg-info"
    },
    success: %{
      fill: "fill-success",
      label_fill: "fill-content",
      stroke: "stroke-success",
      solid_bar: "bg-success text-content",
      outline_bar: "border border-success bg-primary text-content",
      dot: "bg-success"
    },
    warning: %{
      fill: "fill-warning",
      label_fill: "fill-content",
      stroke: "stroke-warning",
      solid_bar: "bg-warning text-content",
      outline_bar: "border border-warning bg-primary text-content",
      dot: "bg-warning"
    },
    error: %{
      fill: "fill-error",
      label_fill: "fill-content",
      stroke: "stroke-error",
      solid_bar: "bg-error text-content",
      outline_bar: "border border-error bg-primary text-content",
      dot: "bg-error"
    },
    neutral: %{
      fill: "fill-secondary",
      label_fill: "fill-content",
      stroke: "stroke-secondary",
      solid_bar: "bg-secondary text-content",
      outline_bar: "border border-secondary bg-primary text-content",
      dot: "bg-secondary"
    }
  }

  # Calendar

  @doc """
  Renders day, week, month, year, schedule, and resource views for a list of events. Emits `calendar_change` for navigation (`%{"view" => v, "date" => d}`) and event selection (`%{"event" => id}`). The consumer handles both kinds of event.

  Events are plain maps. Only these keys are read (extra keys are ignored, so the consumer can keep its own domain fields on the same map):

    * `id`: echoed back on selection
    * `title`: block label
    * `subtitle`: optional secondary label
    * `start` / `finish`: UTC `DateTime`s
    * `color`: a theme token (`:brand | :info | :success | :warning | :error | :neutral`)
    * `variant`: `:solid | :outline` (default `:solid`)
    * `resource_id`: matches a `resources[].id` for the resource view

  Event datetimes are supplied in UTC. `timezone` is applied uniformly for display.
  """
  attr :id, :string, default: "calendar"
  attr :events, :list, required: true
  attr :timezone, :string, default: "Etc/UTC"
  attr :now, :any, default: nil, doc: "current instant as a UTC DateTime, defaulting to now"
  attr :view, :atom, default: :week
  attr :cursor, :any, default: nil, doc: "focal Date, defaulting to today in `timezone`"

  attr :resources, :list,
    default: [],
    doc: "columns for the resource view: %{id, label, sublabel}"

  attr :active_event, :any, default: nil, doc: "id of the highlighted event"

  def calendar(assigns) do
    tz = assigns.timezone
    now_local = DateTime.shift_zone!(assigns.now || DateTime.utc_now(), tz)
    today = DateTime.to_date(now_local)

    events =
      Enum.map(assigns.events, fn event ->
        style = Map.get(@event_styles, Map.get(event, :color, :neutral), @event_styles.neutral)
        outline = Map.get(event, :variant, :solid) == :outline
        start = DateTime.shift_zone!(event.start, tz)
        finish = DateTime.shift_zone!(event.finish, tz)

        label =
          "#{event.title}, #{Calendar.strftime(start, "%-d %b %Y %-I:%M %p %Z")} to #{Calendar.strftime(finish, "%-d %b %Y %-I:%M %p %Z")}"

        event
        |> Map.put(:fill_class, if(outline, do: "fill-transparent", else: style.fill))
        |> Map.put(:label_fill_class, if(outline, do: "fill-content", else: style.label_fill))
        |> Map.put(:stroke_class, style.stroke)
        |> Map.put(:bar_class, if(outline, do: style.outline_bar, else: style.solid_bar))
        |> Map.put(:dot_class, style.dot)
        |> Map.put(:label, if(event[:subtitle], do: "#{label}, #{event.subtitle}", else: label))
        |> Map.put(:start, start)
        |> Map.put(:finish, finish)
        |> Map.put_new(:color, :neutral)
        |> Map.put_new(:variant, :solid)
        |> Map.put_new(:subtitle, nil)
      end)

    assigns =
      assigns
      |> assign(:cursor, assigns.cursor || today)
      |> assign(:today, today)
      |> assign(:now_local, now_local)
      |> assign(:events, events)

    core_components_template(assign(assigns, :component, :calendar))
  end

  # Navigation and view preparation

  attr :view, :atom, required: true
  attr :cursor, :any, required: true
  attr :today, :any, required: true

  defp cal_nav(assigns) do
    period_title =
      case assigns.view do
        :month ->
          Calendar.strftime(assigns.cursor, "%B %Y")

        :week ->
          days = CalendarUtils.week_days(assigns.cursor)

          "#{Calendar.strftime(List.first(days), "%-d %b")} to #{Calendar.strftime(List.last(days), "%-d %b %Y")}"

        :day ->
          Calendar.strftime(assigns.cursor, "%A, %-d %b %Y")

        :resource ->
          Calendar.strftime(assigns.cursor, "%A, %-d %b") <> " by resource"

        :year ->
          to_string(assigns.cursor.year)

        :schedule ->
          "#{Calendar.strftime(assigns.cursor, "%-d %b")} to #{Calendar.strftime(Date.add(assigns.cursor, 13), "%-d %b %Y")}"
      end

    assigns = assign(assigns, :period_title, period_title)
    core_components_template(assign(assigns, :component, :cal_nav))
  end

  attr :id, :string, required: true
  attr :columns, :list, required: true
  attr :now_col, :any, default: nil
  attr :now_minutes, :any, default: nil
  attr :active, :any, default: nil

  defp time_body(assigns) do
    ncols = length(assigns.columns)
    col_w = (@base - @gutter) / max(ncols, 1)

    assigns =
      assigns
      |> assign(:ncols, ncols)
      |> assign(:col_w, col_w)
      |> assign(:width, @base)
      |> assign(:gutter, @gutter)
      |> assign(:hour, @hour)
      |> assign(:day, @day_minutes)
      |> assign(:header, @header)
      |> assign(:now_x1, (assigns.now_col && @gutter + assigns.now_col * col_w) || @gutter)
      |> assign(:now_x2, (assigns.now_col && @gutter + (assigns.now_col + 1) * col_w) || nil)

    core_components_template(assign(assigns, :component, :time_body))
  end

  attr :events, :list, required: true
  attr :cursor, :any, required: true
  attr :today, :any, required: true

  defp month_body(assigns) do
    assigns = assign(assigns, :days, List.flatten(CalendarUtils.month_grid(assigns.cursor)))

    core_components_template(assign(assigns, :component, :month_body))
  end

  attr :events, :list, required: true
  attr :cursor, :any, required: true
  attr :today, :any, required: true

  defp year_body(assigns) do
    assigns =
      assign(
        assigns,
        :event_days,
        assigns.events
        |> Enum.flat_map(fn event ->
          Date.range(
            DateTime.to_date(event.start),
            DateTime.to_date(DateTime.add(event.finish, -1, :microsecond))
          )
          |> Enum.to_list()
        end)
        |> MapSet.new()
      )

    core_components_template(assign(assigns, :component, :year_body))
  end

  attr :events, :list, required: true
  attr :cursor, :any, required: true
  attr :active, :any, default: nil

  defp agenda_body(assigns) do
    {from, to} = CalendarUtils.window(:schedule, assigns.cursor)

    groups =
      from
      |> Date.range(to)
      |> Enum.map(fn day -> {day, CalendarUtils.events_on(assigns.events, day)} end)
      |> Enum.reject(fn {_day, events} -> events == [] end)

    assigns = assign(assigns, :groups, groups)

    core_components_template(assign(assigns, :component, :agenda_body))
  end

  # Time-grid layout

  defp time_columns(:week, cursor, events, _resources, today, now_local) do
    days = CalendarUtils.week_days(cursor)
    now_col = Enum.find_index(days, &(&1 == today))

    %{
      columns: Enum.map(days, &day_column(events, &1, today)),
      now_col: now_col,
      now_minutes: (now_col && now_local.hour * 60 + now_local.minute) || nil
    }
  end

  defp time_columns(:day, cursor, events, _resources, today, now_local) do
    %{
      columns: [day_column(events, cursor, today)],
      now_col: (cursor == today && 0) || nil,
      now_minutes: (cursor == today && now_local.hour * 60 + now_local.minute) || nil
    }
  end

  defp time_columns(:resource, cursor, events, resources, today, now_local) do
    day_events = CalendarUtils.events_on(events, cursor)

    columns =
      Enum.map(resources, fn resource ->
        %{
          label: resource.label,
          sublabel: resource[:sublabel] || "",
          today?: cursor == today,
          events:
            day_events
            |> Enum.filter(&(&1.resource_id == resource.id))
            |> CalendarUtils.lay_out_events()
        }
      end)

    %{
      columns: columns,
      now_col: nil,
      now_minutes: (cursor == today && now_local.hour * 60 + now_local.minute) || nil
    }
  end

  defp day_column(events, day, today) do
    %{
      label: Calendar.strftime(day, "%a"),
      sublabel: to_string(day.day),
      today?: day == today,
      events: events |> CalendarUtils.events_on(day) |> CalendarUtils.lay_out_events()
    }
  end

  defp event_box(event, col_index, col_w) do
    from_min = event.start_minute
    lanes = event.lanes
    lane_w = col_w / lanes

    %{
      x: @gutter + col_index * col_w + event.lane * lane_w + 1,
      y: from_min,
      w: lane_w - 2,
      h: event.display_finish_minute - from_min
    }
  end
end

# Flash delivery

defmodule PoppybitWeb.CoreComponents.Flash do
  @moduledoc false

  def put_flash(%Phoenix.LiveView.Socket{} = socket, kind, message) do
    socket.assigns.flash
    |> Map.keys()
    |> Enum.reduce(socket, &Phoenix.LiveView.clear_flash(&2, &1))
    |> Phoenix.LiveView.put_flash(kind, message)
    |> Phoenix.LiveView.push_event("flash:replace", %{kind: to_string(kind)})
  end

  def put_flash(%Plug.Conn{} = conn, kind, message) do
    conn
    |> Phoenix.Controller.clear_flash()
    |> Phoenix.Controller.put_flash(kind, message)
  end
end

# Upload persistence

defmodule PoppybitWeb.CoreComponents.Upload do
  @moduledoc "Persists public LiveView uploads outside the application release."

  def consume(socket, upload_name, scope) do
    Phoenix.LiveView.consume_uploaded_entries(socket, upload_name, fn %{path: path}, entry ->
      filename = Ash.UUID.generate() <> Path.extname(entry.client_name)
      directory = Path.join(Application.fetch_env!(:poppybit, :upload_directory), scope)
      File.mkdir_p!(directory)
      File.cp!(path, Path.join(directory, filename))
      {:ok, "/uploads/#{scope}/#{filename}"}
    end)
  end

  def delete(<<"/uploads/", path::binary>>) do
    if path != "" and Path.type(path) == :relative and
         Enum.all?(Path.split(path), &(&1 not in [".", "..", ""])) do
      path
      |> then(&Path.join(Application.fetch_env!(:poppybit, :upload_directory), &1))
      |> File.rm()
      |> case do
        :ok -> :ok
        {:error, :enoent} -> :ok
        error -> error
      end
    else
      {:error, :invalid_path}
    end
  end

  def delete(_url), do: {:error, :invalid_path}
end

# Calendar calculations

defmodule PoppybitWeb.CoreComponents.Calendar do
  @moduledoc false

  @day_minutes 1440
  @minimum_event_minutes 16

  # View selection

  @doc "The selectable calendar views as `{value, label}`, in display order."
  def views do
    [
      day: "Day",
      week: "Week",
      month: "Month",
      year: "Year",
      schedule: "Schedule",
      resource: "Resources"
    ]
  end

  @doc "Parses a view param string into a view atom, defaulting to `:week`."
  def parse_view("day"), do: :day
  def parse_view("month"), do: :month
  def parse_view("year"), do: :year
  def parse_view("schedule"), do: :schedule
  def parse_view("resource"), do: :resource
  def parse_view(_other), do: :week

  # Date windows and navigation

  @doc "The inclusive local date span `{from, to}` a view covers for `cursor`."
  def window(:month, cursor) do
    weeks = month_grid(cursor)
    {weeks |> List.first() |> List.first(), weeks |> List.last() |> List.last()}
  end

  def window(:week, cursor) do
    days = week_days(cursor)
    {List.first(days), List.last(days)}
  end

  def window(:day, cursor), do: {cursor, cursor}
  def window(:resource, cursor), do: {cursor, cursor}
  def window(:schedule, cursor), do: {cursor, Date.add(cursor, 13)}

  def window(:year, cursor),
    do: {Date.new!(cursor.year, 1, 1), Date.new!(cursor.year, 12, 31)}

  @doc "Moves `cursor` by `dir` (1 or -1) in the units of `view`."
  def shift(:month, cursor, dir) do
    month = cursor.month + dir

    cond do
      month < 1 -> %{cursor | year: cursor.year - 1, month: 12, day: 1}
      month > 12 -> %{cursor | year: cursor.year + 1, month: 1, day: 1}
      true -> %{cursor | month: month, day: 1}
    end
  end

  def shift(:week, cursor, dir), do: Date.add(cursor, dir * 7)
  def shift(:day, cursor, dir), do: Date.add(cursor, dir)
  def shift(:resource, cursor, dir), do: Date.add(cursor, dir)
  def shift(:schedule, cursor, dir), do: Date.add(cursor, dir * 14)
  def shift(:year, cursor, dir), do: %{cursor | year: cursor.year + dir, month: 1, day: 1}

  # Date grids

  @doc "Weeks (Monday-first) covering the whole month `date` falls in, each a list of 7 Dates."
  def month_grid(%Date{} = date) do
    first = Date.beginning_of_month(date)
    last = Date.end_of_month(date)

    Date.beginning_of_week(first, :monday)
    |> Date.range(Date.end_of_week(last, :monday))
    |> Enum.chunk_every(7)
  end

  @doc "The seven Dates (Monday-first) of the week `date` falls in."
  def week_days(%Date{} = date) do
    start = Date.beginning_of_week(date, :monday)
    Enum.map(0..6, &Date.add(start, &1))
  end

  # Event placement

  @doc "Clips events to a local day, excluding events that finish exactly at its start."
  def events_on(events, %Date{} = day) do
    Enum.flat_map(events, fn event ->
      start_of_day =
        case DateTime.new(day, ~T[00:00:00], event.start.time_zone) do
          {:ok, datetime} -> datetime
          {:ambiguous, first, _second} -> first
          {:gap, _before, following} -> following
        end

      end_of_day =
        case DateTime.new(Date.add(day, 1), ~T[00:00:00], event.start.time_zone) do
          {:ok, datetime} -> datetime
          {:ambiguous, first, _second} -> first
          {:gap, _before, following} -> following
        end

      if DateTime.compare(event.start, end_of_day) == :lt and
           DateTime.compare(event.finish, start_of_day) == :gt do
        start =
          if DateTime.compare(event.start, start_of_day) == :lt,
            do: start_of_day,
            else: event.start

        finish =
          if DateTime.compare(event.finish, end_of_day) == :gt, do: end_of_day, else: event.finish

        start_minute = start.hour * 60 + start.minute

        finish_minute =
          if DateTime.compare(finish, end_of_day) == :eq,
            do: @day_minutes,
            else: finish.hour * 60 + finish.minute

        finish_minute =
          if finish_minute <= start_minute,
            do: start_minute + DateTime.diff(finish, start, :second) / 60,
            else: finish_minute

        [
          Map.merge(event, %{
            start: start,
            finish: finish,
            start_minute: start_minute,
            finish_minute: finish_minute
          })
        ]
      else
        []
      end
    end)
  end

  @doc """
  Annotates local day segments with `:lane` and `:lanes` so visually overlapping events share a day column side by side: overlapping segments form a cluster, each event takes the first free lane, and every event in a cluster reports the cluster's total lane count for width. `:display_finish_minute` includes the minimum visible extent and is shared by lane allocation and rendering.
  """
  def lay_out_events(events) do
    events
    |> Enum.map(fn event ->
      Map.put(
        event,
        :display_finish_minute,
        min(max(event.finish_minute, event.start_minute + @minimum_event_minutes), @day_minutes)
      )
    end)
    |> Enum.sort_by(& &1.start_minute)
    |> cluster_events()
    |> Enum.flat_map(&assign_lanes/1)
  end

  # Overlap groups

  defp cluster_events(sorted) do
    Enum.chunk_while(
      sorted,
      {[], nil},
      fn
        event, {[], _max} ->
          {:cont, {[event], event.display_finish_minute}}

        event, {group, max_finish} ->
          if event.start_minute < max_finish do
            later =
              if event.display_finish_minute > max_finish,
                do: event.display_finish_minute,
                else: max_finish

            {:cont, {[event | group], later}}
          else
            {:cont, Enum.reverse(group), {[event], event.display_finish_minute}}
          end
      end,
      fn
        {[], _} -> {:cont, {[], nil}}
        {group, _} -> {:cont, Enum.reverse(group), {[], nil}}
      end
    )
  end

  defp assign_lanes(cluster) do
    {placed, lane_ends} =
      Enum.reduce(cluster, {[], []}, fn event, {placed, lane_ends} ->
        case Enum.find_index(lane_ends, &(&1 <= event.start_minute)) do
          nil ->
            {[{event, length(lane_ends)} | placed], lane_ends ++ [event.display_finish_minute]}

          index ->
            {[{event, index} | placed],
             List.replace_at(lane_ends, index, event.display_finish_minute)}
        end
      end)

    total = length(lane_ends)
    Enum.map(placed, fn {event, lane} -> Map.merge(event, %{lane: lane, lanes: total}) end)
  end
end

# Cinder styling

defmodule PoppybitWeb.CinderTheme do
  @moduledoc false
  use Cinder.Theme

  # Base layout and buttons

  set :container_class, ""

  set :controls_class, "gap-6 mb-6"

  set :button_class,
      "inline-grid place-items-center min-h-11 px-4 py-2 rounded-default text-sm font-medium whitespace-nowrap transition-colors focus:outline-none focus:ring-2 focus:ring-brand"

  set :button_primary_class, "button-primary"

  set :button_secondary_class, "button-neutral"

  set :button_danger_class, "button-danger"

  set :button_disabled_class, "overlay-dark text-subcontent pointer-events-none"

  # Feedback and loading

  set :error_container_class,
      "grid grid-cols-[1fr] p-4 rounded-default border border-error bg-error overlay-opacity-[0.12] text-content"

  set :error_message_class, ""

  set :loading_overlay_class, "absolute top-4 right-4"

  set :loading_container_class,
      "grid grid-cols-[1rem_max-content] items-center gap-2 text-sm text-brand"

  set :loading_spinner_class,
      "h-4 w-4 rounded-full border-2 border-current border-t-transparent animate-spin"

  set :loading_spinner_circle_class, ""

  set :loading_spinner_path_class, ""

  # Table, list and grid layouts

  set :table_wrapper_class, "listing-surface overflow-x-auto"

  set :table_class, "listing-table"

  set :thead_class, ""

  set :tbody_class, ""

  set :header_row_class, ""

  set :row_class, ""

  set :th_class, "listing-heading"

  set :td_class, "listing-cell"

  set :empty_class, "text-center py-8 text-subcontent"

  set :list_container_class, "space-y-3"

  set :list_item_class,
      "rounded-default panel-surface shadow-card p-5 text-content"

  set :list_item_clickable_class, "cursor-pointer hover:overlay-dark transition-colors"

  set :grid_container_class, "grid gap-4"

  set :grid_item_class,
      "rounded-default panel-surface shadow-card p-5 text-content"

  set :grid_item_clickable_class, "cursor-pointer hover:overlay-dark transition-colors"

  # Search and sorting

  set :search_input_class,
      "block w-full min-h-11 pl-10 px-3 pr-8 py-2 rounded-default border border-outline bg-transparent text-content disabled:overlay-dark disabled:text-subcontent focus:outline-none focus:border-brand focus:ring-2 focus:ring-brand"

  set :search_icon_class, "w-4 h-4"

  set :sort_indicator_class, "inline-grid place-items-center align-baseline"

  set :sort_arrow_wrapper_class, "inline-grid place-items-center"

  set :sort_asc_icon_class, "w-3 h-3 text-brand"

  set :sort_desc_icon_class, "w-3 h-3 text-brand"

  set :sort_none_icon_class, "w-3 h-3 text-subcontent"

  set :sort_container_class, ""

  set :sort_controls_class, "grid grid-cols-[max-content_1fr] items-center gap-3"

  set :sort_controls_label_class, "text-sm text-subcontent"

  set :sort_buttons_class,
      "grid grid-cols-[repeat(4,max-content)] items-center justify-start gap-2"

  set :sort_button_class,
      "inline-grid grid-cols-[max-content_0.75rem] items-center gap-1 min-h-11 px-4 py-2 rounded-default text-sm font-medium transition-colors focus:outline-none focus:ring-2 focus:ring-brand"

  set :sort_button_active_class,
      "border border-brand bg-brand overlay-opacity-[0.12] text-content hover:overlay-dark"

  set :sort_button_inactive_class, "button-neutral"

  # Filters

  set :filter_container_class, ""

  set :filter_header_class,
      "grid grid-cols-[1fr_max-content] items-center gap-3 [&:has(span[phx-click])]:mb-3 [&:has(button:not(.invisible))]:mb-3"

  set :filter_title_class, "[&:not([phx-click])]:sr-only"

  set :filter_toggle_class,
      "cursor-pointer select-none inline-grid grid-cols-[1rem_max-content_max-content] items-center gap-1 min-h-11 px-4 py-2 rounded-default text-sm! font-medium! button-neutral transition-colors"

  set :filter_count_class,
      "inline-grid place-items-center px-2 py-0.5 rounded-full text-xs font-medium bg-brand overlay-opacity-[0.12] text-content"

  set :filter_clear_all_class,
      "col-start-2 inline-grid place-items-center min-h-11 px-4 py-2 rounded-default text-sm font-medium button-neutral transition-colors focus:outline-none focus:ring-2 focus:ring-brand [&.invisible]:hidden"

  set :filter_label_class, "text-sm font-medium text-content whitespace-nowrap pb-1"

  set :filter_inputs_class,
      "grid grid-cols-[2fr_2fr_2fr] subgap-4 gap-y-3 min-h-11"

  set :filter_input_wrapper_class,
      "flex flex-col min-w-0 [&>.flex.items-center]:grid [&>.flex.items-center]:grid-cols-[1fr] [&>.flex.items-center]:relative"

  set :filter_clear_button_class,
      "absolute right-2 top-1/2 -translate-y-1/2 ml-0 inline-grid place-items-center px-2 py-1 rounded-default text-xs font-medium bg-transparent text-content hover:overlay-dark transition-colors [&.invisible]:hidden"

  set :filter_text_input_class,
      "block w-full min-h-11 px-3 pr-8 py-2 rounded-default border border-outline bg-transparent text-sm text-content disabled:overlay-dark disabled:text-subcontent focus:outline-none focus:border-brand focus:ring-2 focus:ring-brand"

  set :filter_date_input_class,
      "block w-full min-h-11 px-3 pr-8 py-2 rounded-default border border-outline bg-transparent text-sm text-content disabled:overlay-dark disabled:text-subcontent focus:outline-none focus:border-brand focus:ring-2 focus:ring-brand"

  set :filter_number_input_class,
      "block w-full min-h-11 px-3 pr-8 py-2 rounded-default border border-outline bg-transparent text-sm text-content disabled:overlay-dark disabled:text-subcontent focus:outline-none focus:border-brand focus:ring-2 focus:ring-brand [&::-webkit-outer-spin-button]:appearance-none [&::-webkit-inner-spin-button]:appearance-none [-moz-appearance:textfield]"

  set :filter_select_input_class,
      "grid! grid-cols-[1fr] w-full min-h-11 px-3 pr-8 py-2 rounded-default border border-outline bg-transparent text-sm text-content disabled:overlay-dark disabled:text-subcontent focus:outline-none focus:border-brand focus:ring-2 focus:ring-brand"

  set :filter_select_container_class, "relative"

  set :filter_select_dropdown_class,
      "absolute z-50 w-full mt-1 bg-surface border border-outline rounded-default shadow-lg max-h-60 overflow-auto"

  set :filter_select_option_class,
      "grid! grid-cols-[1fr] px-3 py-2 hover:option-surface cursor-pointer text-content"

  set :filter_select_label_class, "text-sm cursor-pointer select-none text-content"

  set :filter_select_empty_class, "px-3 py-2 text-subcontent italic text-sm"

  set :filter_select_arrow_class, ""

  set :filter_select_placeholder_class, "text-subcontent"

  set :filter_radio_group_container_class, "grid grid-cols-[1fr] gap-2 min-h-10 items-center"

  set :filter_radio_group_option_class, "grid grid-cols-[1rem_1fr] items-center gap-2"

  set :filter_radio_group_radio_class,
      "appearance-none h-4 w-4 rounded-full border border-outline bg-transparent text-content checked:border-brand checked:bg-brand checked:text-brand-content checked:bg-control-radio focus:outline-none focus:ring-2 focus:ring-brand disabled:overlay-dark disabled:cursor-not-allowed disabled:checked:bg-secondary disabled:checked:border-secondary disabled:checked:text-content"

  set :filter_radio_group_label_class, "text-sm cursor-pointer text-content"

  set :filter_checkbox_container_class, "grid grid-cols-[1rem_1fr] items-center gap-2 min-h-10"

  set :filter_checkbox_input_class,
      "appearance-none h-4 w-4 rounded-default border border-outline bg-transparent text-content checked:border-brand checked:bg-brand checked:text-brand-content checked:bg-control-check bg-center bg-no-repeat bg-[length:100%_100%] focus:outline-none focus:ring-2 focus:ring-brand disabled:overlay-dark disabled:cursor-not-allowed disabled:checked:bg-secondary disabled:checked:border-secondary disabled:checked:text-content"

  set :filter_checkbox_label_class, "text-sm cursor-pointer text-content"

  set :filter_multiselect_container_class, "relative"

  set :filter_multiselect_dropdown_class,
      "absolute z-50 w-full mt-1 bg-surface border border-outline rounded-default shadow-lg max-h-60 overflow-auto"

  set :filter_multiselect_option_class,
      "grid! grid-cols-[1rem_1fr] gap-x-2 px-3 py-2 hover:option-surface cursor-pointer text-content"

  set :filter_multiselect_checkbox_class,
      "appearance-none h-4 w-4 rounded-default border border-outline bg-transparent text-content checked:border-brand checked:bg-brand checked:text-brand-content checked:bg-control-check bg-center bg-no-repeat bg-[length:100%_100%] focus:outline-none focus:ring-2 focus:ring-brand disabled:overlay-dark disabled:cursor-not-allowed disabled:checked:bg-secondary disabled:checked:border-secondary disabled:checked:text-content"

  set :filter_multiselect_label_class,
      "text-sm cursor-pointer select-none text-content"

  set :filter_multiselect_empty_class, "px-3 py-2 text-subcontent italic text-sm"

  set :filter_multicheckboxes_container_class, "space-y-2"

  set :filter_multicheckboxes_option_class, "grid grid-cols-[1.25rem_1fr] items-center gap-2"

  set :filter_multicheckboxes_checkbox_class,
      "appearance-none h-5 w-5 rounded-default border border-outline bg-transparent text-content checked:border-brand checked:bg-brand checked:text-brand-content checked:bg-control-check bg-center bg-no-repeat bg-[length:100%_100%] focus:outline-none focus:ring-2 focus:ring-brand disabled:overlay-dark disabled:cursor-not-allowed disabled:checked:bg-secondary disabled:checked:border-secondary disabled:checked:text-content"

  set :filter_multicheckboxes_label_class, "text-sm cursor-pointer text-content"

  set :filter_range_container_class, "grid grid-cols-[1fr_1rem_1fr] items-center gap-2"

  set :filter_range_input_group_class, "min-w-0"

  set :filter_range_separator_class,
      "grid place-items-center text-sm font-medium text-subcontent"

  # Pagination and page size

  set :pagination_wrapper_class, "py-4"

  set :pagination_container_class,
      "grid grid-cols-[1fr_max-content] items-center gap-4 [&>.flex.items-center]:grid [&>.flex.items-center]:grid-cols-[max-content_max-content] [&>.flex.items-center]:justify-between [&>.flex.items-center]:gap-x-6 [&>.flex.items-center>*]:mx-0"

  set :pagination_info_class, "text-subcontent text-sm"

  set :pagination_count_class, "text-subcontent text-xs ml-2"

  set :pagination_nav_class,
      "grid grid-cols-[max-content] grid-flow-col auto-cols-max items-center justify-end gap-2 [&>button[phx-value-page]]:text-2xl [&>button[phx-value-page]]:leading-none"

  set :pagination_button_class,
      "inline-grid place-items-center min-h-11 min-w-11 px-3 rounded-default text-sm font-medium button-neutral transition-colors"

  set :pagination_current_class,
      "inline-grid place-items-center min-h-11 min-w-11 px-3 rounded-default border border-brand text-sm font-medium bg-brand overlay-opacity-[0.12] text-content"

  set :page_size_container_class,
      "grid grid-cols-[max-content] items-center [&>.flex.items-center]:grid [&>.flex.items-center]:grid-cols-[max-content_max-content_max-content] [&>.flex.items-center]:items-center [&>.flex.items-center]:gap-x-2 [&>.flex.items-center>*]:mx-0"

  set :page_size_label_class, "text-subcontent text-sm"

  set :page_size_dropdown_class,
      "inline-grid grid-cols-[max-content_1rem] items-center gap-2 min-h-11 px-3 rounded-default text-sm font-medium button-neutral shadow-none transition-colors cursor-pointer focus:outline-none focus:ring-2 focus:ring-brand [&>svg]:mx-0"

  set :page_size_dropdown_container_class,
      "bg-surface border border-outline rounded-default shadow-lg"

  set :page_size_option_class,
      "w-full text-left px-3 py-2 text-sm hover:option-surface cursor-pointer text-content"

  set :page_size_selected_class, "bg-brand overlay-opacity-[0.12] text-content"

  # Selection and bulk actions

  set :selection_checkbox_class,
      "appearance-none h-4 w-4 rounded-default border border-outline bg-transparent text-content checked:border-brand checked:bg-brand checked:text-brand-content checked:bg-control-check bg-center bg-no-repeat bg-[length:100%_100%] focus:outline-none focus:ring-2 focus:ring-brand disabled:overlay-dark disabled:cursor-not-allowed disabled:checked:bg-secondary disabled:checked:border-secondary disabled:checked:text-content"

  set :selected_row_class, "bg-brand overlay-opacity-[0.12]"

  set :grid_selection_overlay_class, "mb-2"

  set :selected_item_class, "ring-1 ring-brand"

  set :list_selection_container_class, "mb-2"

  set :bulk_actions_container_class,
      "grid grid-cols-[repeat(4,max-content)] gap-2 justify-end py-3 px-4"
end

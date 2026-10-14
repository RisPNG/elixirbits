defmodule ElixirbitsWeb.CoreComponents do
  @moduledoc """
  Provides core UI components.

  At first glance, this module may seem daunting, but its goal is to provide core building blocks for your application, such as tables, forms, and inputs. The components consist mostly of markup and are well-documented with doc strings and declarative assigns. You may customize and style them in any way you want, based on your application growth and needs.

  The foundation for styling is Tailwind CSS, a utility-first CSS framework. Here are useful references:

    * [Tailwind CSS](https://tailwindcss.com) - the foundational framework we build on. You will use it for layout, sizing, flexbox, grid, and spacing.

    * [Heroicons](https://heroicons.com) - see `icon/1` for usage.

    * [Phoenix.Component](https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html) - the component system used by Phoenix. Components such as `<.link>` are defined there. The shared `<.form>` below applies the application's validation default and uses Phoenix's form renderer.

  """
  use Phoenix.Component
  import Phoenix.Component, except: [form: 1]
  use Gettext, backend: ElixirbitsWeb.Gettext

  alias Phoenix.LiveView.JS

  @color_space_options Elixirbits.CoreUtils.Color.options()

  def on_mount(:inputs, _params, _session, socket) do
    socket =
      Phoenix.LiveView.attach_hook(socket, :core_input_options, :handle_event, fn
        "live_select_change", %{"id" => id} = params, socket ->
          if String.ends_with?(id, "_color_space_select") do
            options =
              Elixirbits.CoreUtils.Search.filter(
                @color_space_options,
                Map.get(params, "text", "")
              )

            Phoenix.LiveView.send_update(LiveSelect.Component, id: id, options: options)
            {:halt, socket}
          else
            {:cont, socket}
          end

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
                _ -> Elixirbits.CoreUtils.Color.inspect_color(value)
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
                        do: Elixirbits.CoreUtils.Color.convert_color(state.color, format),
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
                      Elixirbits.CoreUtils.Color.convert_color(picked, format)
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

                Phoenix.LiveView.send_update(LiveSelect.Component,
                  id: selector_id,
                  options: @color_space_options,
                  value: state.format
                )

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

    ~H"""
    <div
      :if={msg = render_slot(@inner_block) || @msg}
      id={@id}
      phx-click={JS.push("lv:clear-flash", value: %{key: @kind}) |> hide("##{@id}")}
      phx-hook={if @duration, do: "FlashAutoDismiss"}
      data-duration={@duration}
      role="alert"
      class="fixed top-4 right-4 z-50 flex flex-col gap-2"
      {@rest}
    >
      <div class={[
        "flex items-start gap-3 p-4 rounded-default border w-80 max-w-80 text-wrap shadow-sm",
        @kind == :info && "bg-info border-info text-content",
        @kind == :error && "bg-error border-error text-content",
        @kind == :warning && "bg-warning border-warning text-content"
      ]}>
        <.icon :if={@icon} name={@icon} class="size-5 shrink-0" />
        <div>
          <p :if={@title} class="font-semibold">{@title}</p>
          <p>
            {msg}
            <.icon
              :if={@show_spinner}
              name="hero-arrow-path"
              class="ml-1 size-3 motion-safe:animate-spin"
            />
          </p>
        </div>
        <div class="flex-1" />
        <button
          type="button"
          class="self-start rounded-default cursor-pointer hover:overlay-dark"
          aria-label={gettext("close")}
        >
          <.icon name="hero-x-mark" class="size-5" />
        </button>
      </div>
    </div>
    """
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

    ~H"""
    <div id={@flash_ids.group} aria-live="polite">
      <.flash kind={:info} flash={@flash} title={gettext("Success!")} duration={5000} />
      <.flash kind={:error} flash={@flash} title={gettext("Error!")} duration={8000} />
      <.flash kind={:warning} flash={@flash} title={gettext("Warning")} duration={8000} />

      <.flash
        id={@flash_ids.client_error}
        kind={:error}
        title={gettext("We can't find the internet")}
        show_spinner
        phx-disconnected={
          show(".phx-client-error ##{@flash_ids.client_error}") |> JS.remove_attribute("hidden")
        }
        phx-connected={hide("##{@flash_ids.client_error}") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
      </.flash>

      <.flash
        id={@flash_ids.server_error}
        kind={:error}
        title={gettext("Something went wrong!")}
        show_spinner
        phx-disconnected={
          show(".phx-server-error ##{@flash_ids.server_error}") |> JS.remove_attribute("hidden")
        }
        phx-connected={hide("##{@flash_ids.server_error}") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
      </.flash>
    </div>
    """
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

  @doc """
  Renders a button with navigation support.

  ## Examples

      <.button variant={:primary}>Send!</.button>
      <.button variant={:neutral} phx-click="go">Send!</.button>
      <.button variant={:neutral} navigate={~p"/"}>Home</.button>

  ## Variant

  A labeled action that needs a filled button takes a `variant` instead of hand-rolled classes, so it matches the icon buttons in height and tone: `:primary` for the preferred action, `:neutral` for a secondary action that needs button emphasis, and `:danger` for destructive confirmations.

      <.button variant={:primary} phx-click="complete">Complete &amp; post variances</.button>
      <.button variant={:neutral} phx-click="cancel_delete">Cancel</.button>

  Section tabs use `:primary` when selected and `:neutral` otherwise. Leaving `variant` unset supports intentional text actions, such as the subordinate magic-link sign-in option, with contextual text and hover/focus styling. Controls with their own shape, such as square toolbar icons, also leave the variant unset and use the shared button color utilities. Inline and hierarchical navigation links keep their text presentation through `<.link>`.
  """
  attr :rest, :global,
    include:
      ~w(href navigate patch method download name value disabled type target rel popovertarget popovertargetaction)

  attr :variant, :atom, values: [nil, :primary, :neutral, :danger], default: nil

  attr :tooltip, :string,
    default: nil,
    doc: "when set, hovering the button reveals this text following the cursor"

  attr :class, :any, default: nil
  slot :inner_block, required: true

  def button(%{rest: rest} = assigns) do
    variant =
      case assigns.variant do
        :primary -> "min-h-11 px-4 py-2 text-sm whitespace-nowrap button-primary"
        :neutral -> "min-h-11 px-4 py-2 text-sm whitespace-nowrap button-neutral"
        :danger -> "min-h-11 px-4 py-2 text-sm whitespace-nowrap button-danger"
        nil -> nil
      end

    assigns =
      assign(assigns, :class, [
        "inline-grid place-items-center rounded-default font-medium transition-colors focus:outline-none focus:ring-2 focus:ring-brand disabled:opacity-50 disabled:pointer-events-none",
        variant,
        assigns[:class]
      ])

    if rest[:href] || rest[:navigate] || rest[:patch] do
      ~H"""
      <.link class={@class} data-tooltip={@tooltip} {@rest}>
        {render_slot(@inner_block)}
      </.link>
      """
    else
      ~H"""
      <button class={@class} data-tooltip={@tooltip} {@rest}>
        {render_slot(@inner_block)}
      </button>
      """
    end
  end

  attr :label, :string, required: true
  attr :index, :integer, required: true
  attr :columns, :integer, default: 1, values: [1, 2]
  attr :class, :any, default: nil
  slot :actions
  slot :inner_block, required: true

  def entry_panel(assigns) do
    ~H"""
    <div class={[
      "flex flex-col gap-4 border-b border-outline pb-4",
      @columns == 2 && ((rem(@index, 2) == 1 && "border-l pl-6") || "pr-6"),
      @class
    ]}>
      <div class="grid grid-cols-[1fr_2.75rem] items-center gap-2 border-b border-outline pb-2">
        <p class="text-sm font-semibold text-content">{"#{@label} ##{@index + 1}"}</p>
        {render_slot(@actions)}
      </div>
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc """
  Renders a record action as a bordered icon button.

  Creating a record, adding a row, viewing, updating, saving, archiving, deleting, and leaving the page all use the same square bordered icon, so these controls look consistent in page headers, table rows, and repeated sub-forms.

  Destructive actions use the error color. Other actions use neutral colors. Hovering darkens each button's existing surface. For a domain-specific action without its own entry, pass `icon` to override the icon while keeping the button's shape and colors, and pass a `tooltip` that describes the action.

  ## Examples

      <.action_button action={:read} navigate={~p"/inventory/categories"} />
      <.action_button action={:archive} phx-click="request_delete" phx-value-id={c.id} />
      <.action_button action={:save} type="submit" />
      <.action_button action={:create} icon="tabler-calendar-plus" tooltip="Add" />
  """
  attr :action, :atom,
    required: true,
    values: [:create, :read, :update, :save, :send, :archive, :delete, :back]

  attr :icon, :string, default: nil, doc: "overrides the action's default icon"

  attr :tooltip, :string,
    default: nil,
    doc:
      "overrides the action's default tooltip and accessible label unless aria-label is supplied; an empty string hides the tooltip and keeps the action's label"

  attr :class, :any, default: nil
  attr :rest, :global, include: ~w(href navigate patch method download name value disabled type)

  def action_button(assigns) do
    {icon, tooltip} =
      case assigns.action do
        :create -> {"hero-plus", "Add new"}
        :read -> {"hero-eye", "View"}
        :update -> {"hero-pencil-square", "Update"}
        :save -> {"tabler-device-floppy", "Save"}
        :send -> {"tabler-send", "Send"}
        :archive -> {"hero-archive-box", "Archive"}
        :delete -> {"hero-trash", "Delete"}
        :back -> {"hero-arrow-left", "Back"}
      end

    tone =
      if assigns.action in [:archive, :delete],
        do: "button-danger",
        else: "button-neutral"

    assigns =
      assign(assigns,
        icon: assigns.icon || icon,
        tooltip: assigns.tooltip || tooltip,
        tone: tone,
        rest:
          assigns.rest
          |> Map.put_new(:type, "button")
          |> Map.put_new(
            :"aria-label",
            if(assigns.tooltip in [nil, ""], do: tooltip, else: assigns.tooltip)
          )
      )

    ~H"""
    <.button
      class={["size-11", @tone, @class]}
      tooltip={@tooltip}
      {@rest}
    >
      <.icon name={@icon} class="size-6" />
    </.button>
    """
  end

  @doc """
  Renders an input with label and error messages.

  A `Phoenix.HTML.FormField` may be passed as argument, which is used to retrieve the input name, id, and values. Otherwise all attributes may be passed explicitly.

  ## Types

  This function accepts all HTML input types, considering that:

    * The `type="select"` renders the project's LiveSelect-backed selector.

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
    values: ~w(checkbox color date datetime-local email file month number password radio
               search select switch tel text textarea time url week hidden)

  attr :field, Phoenix.HTML.FormField,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"

  attr :select_id, :string, default: nil, doc: "internal: the LiveSelect component ID"

  attr :form_field, :any,
    default: nil,
    doc: "internal: the original form field, preserved across the input/1 recursion"

  attr :errors, :list, default: []
  attr :checked, :boolean, doc: "the checked flag for checkbox inputs"
  attr :prompt, :string, default: nil, doc: "the prompt for select inputs"
  attr :options, :list, doc: "the options to pass to Phoenix.HTML.Form.options_for_select/2"

  attr :mode, :atom,
    default: :single,
    values: [:single, :tags, :quick_tags],
    doc: "the LiveSelect mode for select inputs"

  attr :class, :any, default: nil, doc: "the input class to use over defaults"
  attr :error_class, :any, default: nil, doc: "the input error class to use over defaults"

  attr :render_as, :string,
    default: "enabled",
    values:
      ~w(enabled disabled like-enabled like-disabled hidden hidden-enabled hidden-disabled text text-enabled text-disabled)

  attr :variant, :string,
    default: "default",
    values: ~w(default alt),
    doc:
      "the checkbox and switch layout: \"default\" boxes the control in a field with the label, \"alt\" drops the field outline and puts the label inline beside the control"

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
      "how a file field draws each preview: \"tag\" for a chip that clears like a LiveSelect tag, \"thumbnail\" for an image tile with a corner clear button"

  attr :thumbnail_class, :any,
    default: "h-36 w-full",
    doc: "the size of a thumbnail's media frame"

  slot :stored_preview, doc: "for a file field, overrides one stored file's media, given its URL"

  slot :pending_preview,
    doc: "for a file field, overrides one picked file's media, given its upload entry"

  slot :preview_caption, doc: "for a file field, renders a stored file's caption, given its URL"

  slot :pending_caption,
    doc: "for a file field, renders a picked file's caption, given its upload entry"

  @live_select_rest_global (if Code.ensure_loaded?(LiveSelect.Component) do
                              LiveSelect.Component.default_opts()
                              |> Keyword.keys()
                              |> Kernel.++([
                                :field,
                                :id,
                                :options,
                                :"phx-target",
                                :"phx-blur",
                                :"phx-focus",
                                :option,
                                :tag,
                                :clear_button,
                                :hide_dropdown,
                                :value_mapper,
                                :form
                              ])
                            else
                              []
                            end)

  attr :rest, :global,
    default: %{autocomplete: "off"},
    include:
      ~w(accept autocomplete capture cols disabled form list max maxlength min minlength
                 multiple pattern placeholder readonly required rows size step) ++
        (@live_select_rest_global |> Enum.map(&Atom.to_string/1))

  def input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    form_timezone =
      case field.form.source do
        %AshPhoenix.Form{opts: opts} -> get_in(opts[:context] || %{}, [:shared, :user_timezone])
        _ -> nil
      end

    assigns
    |> assign(
      field: nil,
      form_field: field,
      timezone: assigns.timezone || form_timezone || "Etc/UTC",
      id: assigns.id || field.id,
      select_id: assigns.id || "#{field.id}-ls"
    )
    |> assign(:errors, Enum.map(errors, &translate_error(&1)))
    |> assign_new(:name, fn ->
      if assigns.mode in [:tags, :quick_tags], do: field.name <> "[]", else: field.name
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

  def input(%{tooltip: tooltip} = assigns) when is_binary(tooltip) and tooltip != "" do
    ~H"""
    <div
      data-tooltip={@tooltip}
      class={
        @type in ["checkbox", "switch"] and
          (@variant == "alt" or @render_as in ["text", "text-enabled", "text-disabled"]) and "w-fit"
      }
    >
      {input(assign(assigns, :tooltip, nil))}
    </div>
    """
  end

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
    file_inline = selection != "multiple" && (!assigns.preview || selection == "singles")
    file_steps = selection == "singles" && !assigns.preview
    file_detached = assigns.preview_id != nil && selection != "multiple"
    first_entry = List.first(entries)
    first_url = List.first(assigns.stored)

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
          {assigns[:value] || assigns.rest[:placeholder] || "Choose a file", [], nil}
      end

    file_id = if upload, do: upload.ref, else: assigns.id || assigns[:name]
    preview_as = assigns.preview_as || if(assigns.preview, do: "thumbnail", else: "tag")
    text_look = assigns.render_as in ["text", "text-enabled", "text-disabled"]

    editable =
      assigns.render_as in ["enabled", "text", "text-enabled", "hidden", "hidden-enabled"]

    placeholder = assigns.rest[:placeholder]

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
      |> assign(:preview_as, preview_as)
      |> assign(:text_look, text_look)
      |> assign(:label_as_placeholder, placeholder in [nil, ""])
      |> assign(
        :file_placeholder,
        placeholder || if(selection == "multiple", do: "Choose files", else: "Choose a file")
      )
      |> assign(
        :file_readonly_name,
        assigns[:value] || placeholder ||
          if(selection == "multiple", do: "Choose files", else: "Choose a file")
      )
      |> assign(:errors, assigns.errors ++ messages)
      |> assign(
        :rest,
        if(!upload && selection == "multiple",
          do: Map.put(assigns.rest, :multiple, true),
          else: Map.delete(assigns.rest, :multiple)
        )
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

    ~H"""
    <div
      id={"#{@file_id}-file-input"}
      phx-hook="FileInput"
      data-file-preview={to_string(@preview)}
      data-file-preview-as={@preview_as}
      data-file-editor={@file_editor}
      data-file-selection={@selection}
      data-file-upload-name={@upload && @upload.name}
      data-file-entry-ref={List.first(@file_entries) && List.first(@file_entries).ref}
      data-file-entry-refs={@file_entry_refs}
      data-file-max-entries={@upload && @upload.max_entries}
      data-file-max-size={@upload && @upload.max_file_size}
      data-file-mode={@render_as}
      data-file-collection-id={"#{@file_id}-file-previews"}
      data-file-preview-id={(@file_detached && @preview_id) || nil}
      class={[
        "relative",
        @render_as in ["hidden", "hidden-enabled", "hidden-disabled"] && "hidden",
        @text_look && "group/upload"
      ]}
    >
      <div
        data-file-control
        class={[
          "relative group/file-control",
          !@file_editable && !@file_inline && "hidden",
          @file_inline &&
            [
              "grid items-center",
              cond do
                @file_steps -> "grid-cols-[minmax(0,1fr)_auto_1.75rem_1.75rem]"
                @preview && @upload -> "grid-cols-[minmax(0,1fr)]"
                true -> "grid-cols-[minmax(0,1fr)_1.75rem]"
              end,
              !@text_look &&
                [
                  "input-floating-wrapper min-h-11 rounded-default border bg-transparent text-content focus-within:border-brand focus-within:ring-2 focus-within:ring-brand",
                  (@errors == [] || @error_class) && "border-outline",
                  @errors != [] &&
                    (@error_class || "border-error focus-within:border-error focus-within:ring-error")
                ],
              @text_look && if(@label, do: "min-h-7", else: "min-h-11"),
              (@rest[:disabled] || @render_as in ["disabled", "like-disabled"]) &&
                "overlay-dark cursor-not-allowed text-subcontent"
            ]
        ]}
      >
        <label
          for={@file_id}
          class={[
            "min-w-0",
            if(@file_editable || @file_inline, do: "relative block", else: "hidden"),
            @text_look && "flex flex-col gap-1 cursor-pointer has-[:disabled]:cursor-not-allowed"
          ]}
        >
          <% input_class =
            if @text_look do
              "sr-only"
            else
              [
                @class ||
                  [
                    "block w-full min-h-11 px-3 rounded-default border bg-transparent text-content focus:outline-none focus:border-brand focus:ring-2 focus:ring-brand disabled:overlay-dark disabled:text-subcontent disabled:cursor-not-allowed",
                    if(@label, do: "input-floating-control", else: "py-2"),
                    (@errors == [] || @error_class) && "border-outline"
                  ],
                @errors != [] && (@error_class || "border-error focus:border-error focus:ring-error")
              ]
            end %>
          <.live_file_input
            :if={@upload}
            upload={@file_upload}
            {@rest}
            data-file-input
            disabled={@rest[:disabled] || not @file_editable}
            class={
              if @file_inline,
                do: ["sr-only peer", @label && !@text_look && "input-floating-control"],
                else: input_class
            }
          />
          <input
            :if={!@upload}
            type="file"
            id={@file_id}
            name={@name}
            {Map.delete(@rest, :placeholder)}
            data-file-input
            placeholder={
              if @label && !@text_look && @label_as_placeholder, do: " ", else: @rest[:placeholder]
            }
            disabled={@rest[:disabled] || not @file_editable}
            class={
              if @file_inline,
                do: ["sr-only peer", @label && !@text_look && "input-floating-control"],
                else: input_class
            }
          />
          <span
            :if={(@file_editable || @file_inline) && @label not in [nil, ""]}
            class={
              if @text_look,
                do: ["text-sm font-medium", (@errors != [] && "text-error") || "text-subcontent"],
                else: [
                  "input-floating-label",
                  !@label_as_placeholder && "input-floating-label-hidden",
                  @errors != [] && "input-floating-label-error"
                ]
            }
          >
            {@label}<span :if={@rest[:required]} aria-hidden="true" class="ml-1 text-error">*</span>
          </span>
          <span
            data-file-name
            data-file-readonly-name={if @file_inline && !@file_editable, do: ""}
            data-file-display={if @file_inline && !@text_look, do: ""}
            data-file-count={if @selection == "singles" && @preview && !@text_look, do: ""}
            data-file-default-name={
              if @file_inline && !@file_editable, do: @file_readonly_name, else: @file_placeholder
            }
            aria-live={if @selection == "singles", do: "polite"}
            class={[
              if(
                @file_inline ||
                  (@text_look && (@upload == nil || (@stored == [] && @file_entries == []))),
                do: "block",
                else: "hidden"
              ),
              "w-full text-sm overflow-hidden text-ellipsis whitespace-nowrap group-has-[input:focus-visible]/upload:underline",
              if(@file_inline && !@text_look,
                do: [
                  @class || "min-h-10.5 px-3 py-2.5",
                  "peer-focus-visible:underline",
                  @rest[:disabled] && "cursor-not-allowed"
                ],
                else: if(@label, do: "min-h-6 py-1", else: "min-h-11 content-center text-center")
              ),
              if(@rest[:disabled] || !@file_editable, do: "text-subcontent", else: "text-content"),
              @errors != [] && (@error_class || "text-error")
            ]}
          >{cond do
            @selection == "singles" && @preview -> @file_count_label
            @file_inline && @file_caption != [] -> render_slot(@file_caption, @file_caption_value)
            @file_inline -> @file_name
            true -> @file_placeholder
          end}</span>
        </label>
        <span
          :if={@file_steps}
          data-file-position
          class="px-1 text-sm whitespace-nowrap text-subcontent"
        >{@file_position}</span>
        <div
          :if={@upload == nil || (@file_inline && !@preview)}
          class={if @file_inline, do: "grid place-items-center", else: "contents"}
        >
          <.button
            type="button"
            data-file-clear
            hidden
            disabled={@rest[:disabled] || not @file_editable}
            aria-label="Clear selected file"
            class={[
              "grid size-7 place-items-center rounded-default text-error cursor-pointer focus-visible:outline-2 focus-visible:outline-brand disabled:cursor-not-allowed",
              !@file_inline && "absolute top-2 right-2 bg-primary"
            ]}
          ><.icon name="hero-x-mark-mini" class="size-5" /></.button>
        </div>
        <div
          :if={@file_steps}
          class={[
            "grid grid-cols-[1fr] grid-rows-[1fr_1fr] self-stretch border-l border-outline",
            @text_look &&
              "opacity-0 pointer-events-none group-hover/file-control:opacity-100 group-hover/file-control:pointer-events-auto has-[:focus-visible]:opacity-100 has-[:focus-visible]:pointer-events-auto"
          ]}
        >
          <.button
            type="button"
            data-file-cycle-input="next"
            data-file-next
            aria-label="Next file"
            aria-controls={@file_id}
            disabled={length(@stored) + length(@file_entries) < 2}
            class={[
              "grid min-h-3.5 place-items-center rounded-none text-subcontent cursor-pointer hover:text-content focus-visible:outline-2 focus-visible:outline-brand disabled:cursor-not-allowed",
              !@text_look && "rounded-tr-default hover:overlay-dark"
            ]}
          ><.icon name="hero-chevron-up-micro" class="size-3" /></.button>
          <.button
            type="button"
            data-file-cycle-input="previous"
            data-file-previous
            aria-label="Previous file"
            aria-controls={@file_id}
            disabled={length(@stored) + length(@file_entries) < 2}
            class={[
              "grid min-h-3.5 place-items-center rounded-none border-t border-outline text-subcontent cursor-pointer hover:text-content focus-visible:outline-2 focus-visible:outline-brand disabled:cursor-not-allowed",
              !@text_look && "rounded-br-default hover:overlay-dark"
            ]}
          ><.icon name="hero-chevron-down-micro" class="size-3" /></.button>
        </div>
      </div>
      <span
        :if={(not @file_editable && !@file_inline) and @label not in [nil, ""]}
        class="block text-sm font-medium text-subcontent"
      >
        {@label}<span :if={@rest[:required]} aria-hidden="true" class="ml-1 text-error">*</span>
      </span>
      <span
        :if={@upload == nil && !@file_inline && not @file_editable}
        data-file-readonly-name
        data-file-default-name={@file_readonly_name}
        class={[
          "block w-full overflow-hidden text-ellipsis whitespace-nowrap text-sm text-subcontent",
          if(@text_look,
            do: "min-h-6 py-1",
            else: [
              "min-h-11 rounded-default border border-outline bg-transparent px-3 py-2",
              @render_as in ["disabled", "like-disabled"] && "overlay-dark"
            ]
          )
        ]}
      >{if @selection == "singles", do: @file_count_label, else: @file_readonly_name}</span>
      <%= if @file_detached do %>
        <.portal
          id={"#{@file_id}-file-preview-portal"}
          target={"[id=#{Jason.encode!(@preview_id)}]"}
          class="contents"
        >
          {file_previews(assigns)}
        </.portal>
      <% else %>
        {file_previews(assigns)}
      <% end %>
      <div id={"#{@file_id}-file-replacements"} phx-update="ignore" data-file-replacements />
      <p data-file-error hidden role="alert" class="mt-2 text-sm text-error" />
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{render_as: "hidden-disabled"} = assigns) do
    ~H""
  end

  def input(%{render_as: render_as} = assigns) when render_as in ["hidden", "hidden-enabled"] do
    assigns = assign(assigns, :render_as, "enabled")

    ~H"""
    <div class="hidden">{input(assigns)}</div>
    """
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
      |> assign(:text_look, text_look)
      |> assign(:label_as_placeholder, placeholder in [nil, ""])
      |> assign(
        :placeholder,
        if(assigns.label && placeholder in [nil, ""], do: " ", else: placeholder)
      )
      |> assign(
        :rest,
        assigns.rest |> Map.delete(:placeholder) |> Map.put_new(:"phx-debounce", "blur")
      )

    ~H"""
    <div>
      <div
        id={@number_id}
        phx-hook="NumberInput"
        class={["relative", @text_look && "flex flex-col gap-1"]}
      >
        <label
          :if={@text_look && @label}
          for={@id}
          class={["text-sm font-medium", (@errors != [] && "text-error") || "text-subcontent"]}
        >
          {@label}<span :if={@rest[:required]} aria-hidden="true" class="ml-1 text-error">*</span>
        </label>
        <div class={[
          "number-input-control group/number grid grid-cols-[minmax(0,1fr)_1.75rem] items-center",
          !@text_look &&
            [
              "input-floating-wrapper min-h-11 ps-3 rounded-default border bg-transparent text-content focus-within:border-brand focus-within:ring-2 focus-within:ring-brand",
              (@errors == [] || @error_class) && "border-outline",
              @errors != [] &&
                (@error_class || "border-error focus-within:border-error focus-within:ring-error")
            ],
          @text_look && if(@label, do: "min-h-7", else: "min-h-11"),
          @rest[:disabled] && "overlay-dark cursor-not-allowed text-subcontent"
        ]}>
          <input
            type="number"
            id={@id}
            name={@name}
            value={Phoenix.HTML.Form.normalize_value("number", @value)}
            placeholder={@placeholder}
            class={
              @class ||
                [
                  "min-w-0 w-full appearance-none border-0 bg-transparent p-0 text-sm text-content focus:outline-none focus:ring-0 disabled:text-subcontent disabled:cursor-not-allowed",
                  if(@text_look,
                    do: [
                      "py-1 focus-visible:underline",
                      !@label && "text-center",
                      @errors != [] && (@error_class || "text-error")
                    ],
                    else: "input-floating-control"
                  )
                ]
            }
            {@rest}
          />
          <div class={[
            "grid grid-cols-[1fr] grid-rows-[1fr_1fr] self-stretch border-l border-outline",
            @text_look &&
              "opacity-0 pointer-events-none group-hover/number:opacity-100 group-hover/number:pointer-events-auto has-[:focus-visible]:opacity-100 has-[:focus-visible]:pointer-events-auto"
          ]}>
            <.button
              type="button"
              data-number-step="1"
              aria-label="Increase value"
              aria-controls={@id}
              disabled={@rest[:disabled] || @rest[:readonly] || @rest[:step] == "any"}
              class={[
                "grid min-h-3.5 place-items-center rounded-none text-subcontent cursor-pointer hover:text-content focus-visible:outline-2 focus-visible:outline-brand disabled:cursor-not-allowed",
                !@text_look && "rounded-tr-default hover:overlay-dark"
              ]}
            >
              <.icon name="hero-chevron-up-micro" class="size-3" />
            </.button>
            <.button
              type="button"
              data-number-step="-1"
              aria-label="Decrease value"
              aria-controls={@id}
              disabled={@rest[:disabled] || @rest[:readonly] || @rest[:step] == "any"}
              class={[
                "grid min-h-3.5 place-items-center rounded-none border-t border-outline text-subcontent cursor-pointer hover:text-content focus-visible:outline-2 focus-visible:outline-brand disabled:cursor-not-allowed",
                !@text_look && "rounded-br-default hover:overlay-dark"
              ]}
            >
              <.icon name="hero-chevron-down-micro" class="size-3" />
            </.button>
          </div>
        </div>
        <label
          :if={!@text_look && @label}
          for={@id}
          class={[
            "input-floating-label",
            !@label_as_placeholder && "input-floating-label-hidden",
            @errors != [] && "input-floating-label-error"
          ]}
        >
          {@label}<span :if={@rest[:required]} aria-hidden="true" class="ml-1 text-error">*</span>
        </label>
      </div>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{render_as: render_as, type: type} = assigns)
      when render_as in ["text", "text-enabled"] and
             type in ["email", "password", "search", "text", "url"] do
    assigns =
      assigns
      |> assign(:render_as, "enabled")
      |> assign(:rest, Map.put_new(assigns.rest, :"phx-debounce", "blur"))
      |> assign(
        :text_input_class,
        assigns.class ||
          [
            "block w-full appearance-none bg-transparent border-0 text-sm text-content overflow-hidden text-ellipsis whitespace-nowrap focus:outline-none focus:ring-0 focus-visible:underline disabled:overlay-dark disabled:cursor-not-allowed disabled:text-subcontent",
            if(assigns[:label], do: "min-h-6 py-1", else: "min-h-11 text-center"),
            assigns.errors != [] && (assigns.error_class || "text-error")
          ]
      )

    ~H"""
    <div>
      <label for={@id} class="flex flex-col gap-1">
        <span
          :if={@label}
          class={["text-sm font-medium", (@errors != [] && "text-error") || "text-subcontent"]}
        >
          {@label}<span
            :if={@rest[:required] && @label not in [nil, ""]}
            aria-hidden="true"
            class="ml-1 text-error"
          >*</span>
        </span>
        <input
          type={if @type == "password", do: "text", else: @type}
          name={@name}
          id={@id}
          value={Phoenix.HTML.Form.normalize_value(@type, @value)}
          class={@text_input_class}
          {@rest}
        />
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "color"} = assigns) do
    editable = assigns.render_as in ["enabled", "text", "text-enabled"]
    text_look = assigns.render_as in ["text", "text-enabled", "text-disabled"]
    disabled_look = assigns.render_as in ["disabled", "like-disabled"]
    value = assigns[:value] || ""
    base_id = assigns.id || assigns.name
    placeholder = assigns.rest[:placeholder]

    color_state =
      case Elixirbits.CoreUtils.Color.inspect_color(value) do
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
      |> assign(:label_as_placeholder, placeholder in [nil, ""])
      |> assign(
        :placeholder,
        if(assigns.label && placeholder in [nil, ""], do: " ", else: placeholder)
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

    ~H"""
    <div>
      <div
        id={@color_id}
        phx-hook="ColorInput"
        data-color-editable={to_string(@color_editable)}
        data-color-server-invalid={to_string(@errors != [])}
        data-color-space-name={@color_format_field.name}
        data-color-space-id={@color_format_id}
        data-color-state={Jason.encode!(@color_state)}
        class={["relative", @text_look && "flex flex-col gap-1"]}
      >
        <label
          :if={@text_look && @label}
          for={if @color_editable, do: @id}
          class={["text-sm font-medium", (@errors != [] && "text-error") || "text-subcontent"]}
        >
          {@label}<span
            :if={@rest[:required] && @label not in [nil, ""]}
            aria-hidden="true"
            class="ml-1 text-error"
          >*</span>
        </label>
        <div class={[
          "color-input-control grid grid-cols-[1.5rem_minmax(0,1fr)_4rem] items-center gap-2",
          !@text_look &&
            [
              "input-floating-wrapper min-h-11 ps-3 rounded-default border bg-transparent text-content focus-within:border-brand focus-within:ring-2 focus-within:ring-brand",
              !@color_editable && "pe-3",
              (@errors == [] || @error_class) && "border-outline",
              @errors != [] &&
                (@error_class || "border-error focus-within:border-error focus-within:ring-error")
            ],
          @text_look && if(@label, do: "min-h-6", else: "min-h-11"),
          (@disabled_look || @rest[:disabled]) && "overlay-dark cursor-not-allowed text-subcontent"
        ]}>
          <.button
            :if={@color_editable}
            type="button"
            aria-label="Choose color"
            aria-haspopup="dialog"
            popovertarget={@color_popover_id}
            data-color-trigger
            disabled={@rest[:disabled] || @rest[:readonly]}
            class="size-6 rounded-none cursor-pointer disabled:cursor-not-allowed"
          >
            <span
              data-color-swatch
              aria-hidden="true"
              class="color-input-swatch block size-full border border-outline"
              style={if @color_swatch, do: "--input-color: #{@color_swatch}"}
            />
          </.button>
          <span
            :if={!@color_editable}
            data-color-swatch
            aria-hidden="true"
            class="color-input-swatch block size-6 border border-outline"
            style={if @color_swatch, do: "--input-color: #{@color_swatch}"}
          />
          <input
            :if={@color_editable}
            type="text"
            id={@id}
            name={@name}
            value={@value}
            data-color-value
            placeholder={@placeholder}
            spellcheck="false"
            aria-invalid={if @errors != [], do: "true"}
            class={
              @class ||
                [
                  "min-w-0 w-full appearance-none bg-transparent border-0 p-0 text-sm text-content focus:outline-none focus:ring-0 disabled:text-subcontent disabled:cursor-not-allowed",
                  !@text_look && "input-floating-control",
                  @text_look && "py-1 focus-visible:underline"
                ]
            }
            {@rest}
          />
          <span
            :if={!@color_editable}
            id={if !@include_hidden_input, do: @id}
            data-color-value
            class={@class || "min-w-0 overflow-hidden text-ellipsis whitespace-nowrap text-sm"}
          >{@value}</span>
          <span
            :if={!@color_editable}
            data-color-format
            class="min-w-0 truncate text-sm text-content"
            aria-live="polite"
          >
            {@color_format}
          </span>
          <div
            :if={@color_editable}
            id={"#{@color_format_id}_dropdown"}
            phx-hook="SelectDropdown"
            data-color-space-select
            data-dropdown-min-width="18"
            class={[
              "min-w-0 self-stretch",
              !@text_look && "border-l border-outline"
            ]}
          >
            <label for={"#{@color_format_field.id}_text_input"} class="sr-only">Color space</label>
            <LiveSelect.live_select
              field={@color_format_field}
              id={@color_format_id}
              mode={:single}
              options={@color_format_options}
              value={@color_format_field.value}
              disabled={@rest[:disabled] not in [false, nil] || @rest[:readonly] not in [false, nil]}
              allow_clear={false}
              update_min_len={0}
              phx-focus="live_select_change"
              text_input_class={[
                "block w-full min-w-0 appearance-none border-0 bg-transparent text-content overflow-hidden text-ellipsis whitespace-nowrap focus:outline-none focus:ring-0 disabled:text-subcontent disabled:cursor-not-allowed",
                if(@text_look,
                  do: [
                    "text-sm !px-0 focus-visible:underline",
                    if(@label, do: "min-h-6 py-1", else: "min-h-11")
                  ],
                  else: "min-h-10.5 px-2 rounded-r-default"
                )
              ]}
              text_input_selected_class=""
              dropdown_class="select-dropdown rounded-default border border-outline bg-primary shadow-lg z-50 overflow-y-auto"
              option_class="select-none relative py-2 px-3 hover:overlay-light"
              available_option_class="cursor-pointer text-content"
              unavailable_option_class="cursor-not-allowed text-subcontent [&>div]:pointer-events-none"
              selected_option_class="cursor-pointer text-content bg-primary overlay-dark font-semibold order-first"
              active_option_class="overlay-light"
              container_class={
                if @text_look,
                  do: "input-text-wrapper relative flex flex-col w-full",
                  else: "relative flex flex-col w-full"
              }
              keep_label_on_select
              keep_options_on_select
              dropdown_selectable_priority
            />
          </div>
        </div>
        <label
          :if={!@text_look && @label}
          for={if @color_editable, do: @id}
          class={[
            "input-floating-label color-input-label",
            !@label_as_placeholder && "input-floating-label-hidden",
            @errors != [] && "input-floating-label-error",
            !@color_editable && @value != "" && "color-input-label-filled"
          ]}
        >
          {@label}<span
            :if={@rest[:required] && @label not in [nil, ""]}
            aria-hidden="true"
            class="ml-1 text-error"
          >*</span>
        </label>
        <div
          :if={@color_editable}
          id={@color_popover_id}
          popover="auto"
          role="dialog"
          aria-label="Choose color"
          data-color-popover
          class="color-input-popover rounded-default border border-outline bg-primary text-content"
        >
          <rgba-color-picker
            id={@color_picker_id}
            data-color-picker
            phx-update="ignore"
          />
        </div>
        <p
          id={@color_error_id}
          data-color-error
          hidden
          aria-live="polite"
          class="mt-2 text-sm text-error"
        />
        <input
          :if={@include_hidden_input}
          type="hidden"
          id={@id}
          name={@name}
          value={@value}
          {@rest}
        />
      </div>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{render_as: render_as, type: "textarea"} = assigns)
      when render_as in ["text", "text-enabled"] do
    assigns =
      assigns
      |> assign(:render_as, "enabled")
      |> assign(:rest, Map.put_new(assigns.rest, :"phx-debounce", "blur"))
      |> assign(
        :text_input_class,
        assigns.class ||
          [
            "block w-full min-h-6 bg-transparent border-0 py-1 text-sm text-content whitespace-pre-wrap focus:outline-none focus:ring-0 focus-visible:underline disabled:overlay-dark disabled:cursor-not-allowed disabled:text-subcontent",
            assigns.errors != [] && (assigns.error_class || "text-error")
          ]
      )

    ~H"""
    <div>
      <label for={@id} class="flex flex-col gap-1">
        <span
          :if={@label}
          class={["text-sm font-medium", (@errors != [] && "text-error") || "text-subcontent"]}
        >
          {@label}<span
            :if={@rest[:required] && @label not in [nil, ""]}
            aria-hidden="true"
            class="ml-1 text-error"
          >*</span>
        </span>
        <textarea id={@id} name={@name} class={@text_input_class} {@rest}>{Phoenix.HTML.Form.normalize_value("textarea", @value)}</textarea>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
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

    ~H"""
    <div>
      <.dynamic_tag
        tag_name={if @text_editable, do: "label", else: "span"}
        data-boolean-text
        class={[
          "group/boolean",
          @class ||
            [
              "block text-sm bg-transparent",
              if(@label in [nil, ""],
                do: "w-full min-h-11 content-center text-center",
                else: "w-fit min-h-6 py-1"
              ),
              if(@rest[:disabled], do: "text-subcontent cursor-not-allowed", else: "text-content"),
              @text_editable && @rest[:disabled] in [false, nil] && "cursor-pointer",
              @text_editable && "has-[input:focus-visible]:underline",
              @errors != [] && (@error_class || "text-error")
            ]
        ]}
        {@text_rest}
      >
        <input
          :if={@text_editable}
          type="hidden"
          name={@name}
          value="false"
          disabled={@rest[:disabled]}
          form={@rest[:form]}
        />
        <input
          :if={@text_editable}
          type="checkbox"
          id={@id}
          name={@name}
          value="true"
          checked={@checked}
          class="sr-only"
          {@rest}
        />
        {@label}{if @label not in [nil, ""], do: " is "}<span
          :if={@text_editable}
          data-boolean-state="checked"
          class="hidden group-has-[input:checked]/boolean:inline"
        >{@checked_text}</span><span
          :if={@text_editable}
          data-boolean-state="unchecked"
          class="group-has-[input:checked]/boolean:hidden"
        >{@unchecked_text}</span><span
          :if={!@text_editable}
          data-boolean-state={if @checked, do: "checked", else: "unchecked"}
        >{if @checked, do: @checked_text, else: @unchecked_text}</span><span
          :if={@rest[:required] && @label not in [nil, ""]}
          aria-hidden="true"
          class="ml-1 text-error"
        >*</span>
      </.dynamic_tag>
      <.error :for={msg <- @errors}>{msg}</.error>
      <div :if={!@text_editable} class="hidden">
        {input(assign(assigns, render_as: "enabled", label: nil))}
      </div>
    </div>
    """
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
              {true, false} -> "bg-brand border-brand text-content-inverse dark:text-content"
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
                "bg-brand border-brand before:bg-content-inverse dark:before:bg-content"

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

    ~H"""
    <div>
      <div
        id={if @render_as != "like-disabled", do: @id}
        class={[
          if(@display_alt,
            do: [
              "inline-grid items-center gap-2 text-sm font-medium",
              (@type == "switch" && "grid-cols-[2.75rem_1fr]") || "grid-cols-[1.25rem_1fr]",
              @type == "switch" && @label in [nil, ""] && "min-h-11 w-full justify-center"
            ],
            else: [
              "grid items-center gap-2 w-full min-h-11 px-3 rounded-default border bg-transparent",
              (@errors == [] || @error_class) && "border-outline",
              (@type == "switch" && "grid-cols-[1fr_2.75rem]") || "grid-cols-[1fr_1.25rem]",
              @disabled_look && "overlay-dark"
            ]
          ),
          @disabled_look && "cursor-not-allowed",
          @errors != [] && (@error_class || if(@display_alt, do: "text-error", else: "border-error"))
        ]}
        {@span_rest}
      >
        <span :if={@display_alt} class={@class || @box_class} />
        <span
          :if={!@display_alt || @label not in [nil, ""]}
          class={[
            "text-sm font-medium",
            (@disabled_look && "text-subcontent") || "text-content"
          ]}
        >
          {@label}<span
            :if={@rest[:required] && @label not in [nil, ""]}
            aria-hidden="true"
            class="ml-1 text-error"
          >*</span>
        </span>
        <span :if={!@display_alt} class={@class || @box_class} />
      </div>
      <.error :for={msg <- @errors}>{msg}</.error>
      <div :if={@render_as == "like-disabled"} class="hidden">
        {input(assign(assigns, render_as: "enabled", label: nil))}
      </div>
    </div>
    """
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
        {"select", value} when is_list(value) ->
          value
          |> Enum.map(&option_display_label(&1, assigns[:options] || []))
          |> Enum.join(", ")

        {"select", value} ->
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
    placeholder = assigns.rest[:placeholder]
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
          if(filled,
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
      |> assign(:label_as_placeholder, placeholder in [nil, ""])
      |> assign(:span_class, span_class)
      |> assign(:span_rest, Map.drop(assigns.rest, [:autocomplete, :placeholder]))

    ~H"""
    <div>
      <div :if={@text_look} class="flex flex-col gap-1">
        <span
          :if={@label}
          class={["text-sm font-medium", (@errors != [] && "text-error") || "text-subcontent"]}
        >
          {@label}<span
            :if={@rest[:required] && @label not in [nil, ""]}
            aria-hidden="true"
            class="ml-1 text-error"
          >*</span>
        </span>
        <span
          id={if !@include_hidden_input, do: @id}
          class={@class || @span_class}
          {@span_rest}
          phx-no-format
        >{@display}</span>
      </div>
      <div :if={!@text_look} class="relative block">
        <span
          id={if !@include_hidden_input, do: @id}
          class={@class || @span_class}
          {@span_rest}
          phx-no-format
        >{@display}</span>
        <span
          :if={@label}
          class={[
            "input-floating-label",
            !@label_as_placeholder && "input-floating-label-hidden",
            @errors != [] && "input-floating-label-error"
          ]}
        >
          {@label}<span
            :if={@rest[:required] && @label not in [nil, ""]}
            aria-hidden="true"
            class="ml-1 text-error"
          >*</span>
        </span>
      </div>
      <.error :for={msg <- @errors}>{msg}</.error>
      <div :if={@include_hidden_input} class="hidden">
        {input(assign(assigns, render_as: "enabled", label: nil))}
      </div>
    </div>
    """
  end

  def input(%{type: "hidden"} = assigns) do
    ~H"""
    <input type="hidden" id={@id} name={@name} value={@value} {@rest} />
    """
  end

  def input(%{type: "checkbox", variant: "alt"} = assigns) do
    assigns =
      assign_new(assigns, :checked, fn ->
        Phoenix.HTML.Form.normalize_value("checkbox", assigns[:value])
      end)

    ~H"""
    <div>
      <label
        for={@id}
        class={[
          "grid w-fit grid-cols-[1.25rem_1fr] items-center gap-2 text-sm font-medium text-content",
          "has-[:disabled]:cursor-not-allowed has-[:disabled]:text-subcontent",
          @errors != [] && (@error_class || "text-error")
        ]}
      >
        <input
          type="hidden"
          name={@name}
          value="false"
          disabled={@rest[:disabled]}
          form={@rest[:form]}
        />
        <input
          type="checkbox"
          id={@id}
          name={@name}
          value="true"
          checked={@checked}
          class={
            @class ||
              "appearance-none h-5 w-5 shrink-0 cursor-pointer rounded-default border border-outline bg-transparent text-content checked:bg-brand checked:border-brand checked:text-content-inverse dark:checked:text-content focus:outline-none focus:ring-2 focus:ring-brand disabled:overlay-dark disabled:cursor-not-allowed disabled:border-outline disabled:checked:bg-secondary disabled:checked:border-secondary disabled:checked:text-content checked:bg-control-check bg-center bg-no-repeat bg-[length:100%_100%]"
          }
          {@rest}
        />
        <span>{@label}<span
          :if={@rest[:required] && @label not in [nil, ""]}
          aria-hidden="true"
          class="ml-1 text-error"
        >*</span></span>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "checkbox"} = assigns) do
    assigns =
      assign_new(assigns, :checked, fn ->
        Phoenix.HTML.Form.normalize_value("checkbox", assigns[:value])
      end)

    ~H"""
    <div>
      <label
        for={@id}
        class={[
          "group cursor-pointer grid grid-cols-[1fr_1.25rem] items-center gap-2 w-full min-h-11 px-3 rounded-default border bg-transparent text-content focus-within:border-brand focus-within:ring-2 focus-within:ring-brand",
          (@errors == [] || @error_class) && "border-outline",
          "has-[:disabled]:overlay-dark has-[:disabled]:cursor-not-allowed has-[:disabled]:text-subcontent",
          @errors != [] &&
            (@error_class || "border-error focus-within:border-error focus-within:ring-error")
        ]}
      >
        <span class="text-sm font-medium text-content group-has-[:disabled]:text-subcontent">
          {@label}<span
            :if={@rest[:required] && @label not in [nil, ""]}
            aria-hidden="true"
            class="ml-1 text-error"
          >*</span>
        </span>
        <div class="flex items-center gap-2">
          <input
            type="hidden"
            name={@name}
            value="false"
            disabled={@rest[:disabled]}
            form={@rest[:form]}
          />
          <input
            type="checkbox"
            id={@id}
            name={@name}
            value="true"
            checked={@checked}
            class={
              @class ||
                "appearance-none h-5 w-5 shrink-0 rounded-default border border-outline bg-transparent text-content checked:bg-brand checked:border-brand checked:text-content-inverse dark:checked:text-content focus:ring-0 focus:outline-none disabled:cursor-not-allowed disabled:border-outline disabled:checked:bg-secondary disabled:checked:border-secondary disabled:checked:text-content checked:bg-control-check bg-center bg-no-repeat bg-[length:100%_100%]"
            }
            {@rest}
          />
        </div>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "radio"} = assigns) do
    ~H"""
    <fieldset id={@id} class="group">
      <legend
        :if={@label}
        class="mb-1 text-sm font-medium text-content group-has-[:disabled]:text-subcontent"
      >
        {@label}<span
          :if={@rest[:required] && @label not in [nil, ""]}
          aria-hidden="true"
          class="ml-1 text-error"
        >*</span>
      </legend>
      <div class="flex flex-col gap-3">
        <label
          :for={{option_label, option_value} <- @options}
          class={[
            "grid grid-cols-[1.25rem_1fr] items-center gap-2 text-sm text-content",
            "has-[:disabled]:cursor-not-allowed has-[:disabled]:text-subcontent",
            @errors != [] && (@error_class || "text-error")
          ]}
        >
          <input
            type="radio"
            name={@name}
            value={to_string(option_value)}
            checked={to_string(@value) == to_string(option_value)}
            class={
              @class ||
                "appearance-none h-5 w-5 shrink-0 cursor-pointer rounded-full border border-outline bg-transparent text-content checked:border-brand checked:bg-brand checked:text-content-inverse dark:checked:text-content focus:outline-none focus:ring-2 focus:ring-brand disabled:overlay-dark disabled:cursor-not-allowed disabled:checked:bg-secondary disabled:checked:border-secondary disabled:checked:text-content checked:bg-control-radio"
            }
            {@rest}
          />
          <span>{option_label}</span>
        </label>
      </div>
      <.error :for={msg <- @errors}>{msg}</.error>
    </fieldset>
    """
  end

  def input(%{type: "switch", variant: "alt"} = assigns) do
    assigns =
      assign_new(assigns, :checked, fn ->
        Phoenix.HTML.Form.normalize_value("checkbox", assigns[:value])
      end)

    ~H"""
    <div>
      <label
        for={@id}
        class={
          [
            "grid grid-cols-[2.75rem_1fr] items-center gap-2 text-sm font-medium text-content",
            "has-[:disabled]:cursor-not-allowed has-[:disabled]:text-subcontent",
            # Unlabeled means it sits in a row under its column heading, so it centers on the column and takes the field height.
            (@label in [nil, ""] && "min-h-11 w-full justify-center") || "w-fit",
            @errors != [] && (@error_class || "text-error")
          ]
        }
      >
        <input
          type="hidden"
          name={@name}
          value="false"
          disabled={@rest[:disabled]}
          form={@rest[:form]}
        />
        <input
          type="checkbox"
          id={@id}
          name={@name}
          value="true"
          checked={@checked}
          class={
            @class ||
              "peer appearance-none shrink-0 cursor-pointer w-11 h-6 rounded-full border border-outline bg-transparent text-content checked:bg-brand checked:border-brand checked:text-content-inverse dark:checked:text-content focus:outline-none focus:ring-2 focus:ring-brand disabled:overlay-dark disabled:cursor-not-allowed disabled:checked:bg-secondary disabled:checked:border-secondary disabled:checked:text-content transition-colors duration-200 ease-in-out relative before:absolute before:top-[1px] before:left-[1px] before:h-5 before:w-5 before:rounded-full before:bg-subcontent checked:before:translate-x-5 checked:before:bg-content-inverse dark:checked:before:bg-content disabled:checked:before:bg-subcontent before:transition-transform before:duration-200 before:ease-in-out"
          }
          {@rest}
        />
        <span :if={@label not in [nil, ""]}>{@label}<span
          :if={@rest[:required] && @label not in [nil, ""]}
          aria-hidden="true"
          class="ml-1 text-error"
        >*</span></span>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "switch"} = assigns) do
    assigns =
      assign_new(assigns, :checked, fn ->
        Phoenix.HTML.Form.normalize_value("checkbox", assigns[:value])
      end)

    ~H"""
    <div>
      <label
        for={@id}
        class={[
          "group cursor-pointer grid grid-cols-[1fr_2.75rem] items-center gap-2 w-full min-h-11 px-3 rounded-default border bg-transparent text-content focus-within:border-brand focus-within:ring-2 focus-within:ring-brand",
          (@errors == [] || @error_class) && "border-outline",
          "has-[:disabled]:overlay-dark has-[:disabled]:cursor-not-allowed has-[:disabled]:text-subcontent",
          @errors != [] &&
            (@error_class || "border-error focus-within:border-error focus-within:ring-error")
        ]}
      >
        <span class="text-sm font-medium text-content group-has-[:disabled]:text-subcontent">
          {@label}<span
            :if={@rest[:required] && @label not in [nil, ""]}
            aria-hidden="true"
            class="ml-1 text-error"
          >*</span>
        </span>
        <div class="flex items-center gap-2">
          <input
            type="hidden"
            name={@name}
            value="false"
            disabled={@rest[:disabled]}
            form={@rest[:form]}
          />
          <input
            type="checkbox"
            id={@id}
            name={@name}
            value="true"
            checked={@checked}
            class={
              @class ||
                "peer appearance-none shrink-0 w-11 h-6 rounded-full border border-outline bg-transparent text-content checked:bg-brand checked:border-brand checked:text-content-inverse dark:checked:text-content focus:outline-none focus:ring-0 disabled:cursor-not-allowed disabled:checked:bg-secondary disabled:checked:border-secondary disabled:checked:text-content transition-colors duration-200 ease-in-out relative before:absolute before:top-[1px] before:left-[1px] before:h-5 before:w-5 before:rounded-full before:bg-subcontent checked:before:translate-x-5 checked:before:bg-content-inverse dark:checked:before:bg-content disabled:checked:before:bg-subcontent before:transition-transform before:duration-200 before:ease-in-out"
            }
            {@rest}
          />
        </div>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "select", rest: %{disabled: disabled}} = assigns)
      when disabled not in [false, nil] do
    assigns = assign_new(assigns, :form_field, fn -> nil end)

    assigns =
      assign_new(assigns, :safe_field, fn ->
        if assigns.form_field do
          %{assigns.form_field | value: assigns[:value]}
        else
          %{
            to_form(%{assigns.name => assigns.value}, as: "dummy")[assigns.name]
            | id: assigns.id || assigns.name,
              name: assigns.name,
              errors: assigns[:errors] || []
          }
        end
      end)

    field = assigns.safe_field
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
      if assigns.mode in [:tags, :quick_tags], do: field.name <> "[]", else: field.name

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
        |> Map.take([:role, :"aria-label", :"aria-labelledby", :"aria-describedby"])
        |> then(fn attrs ->
          if map_size(attrs) > 0, do: Map.put_new(attrs, :role, "group"), else: attrs
        end)
      )

    ~H"""
    <div {@div_attrs}>
      <.input
        id={@id || @safe_field.id}
        name={@safe_field.name}
        type="text"
        label={assigns[:label]}
        render_as={@render_as}
        value={@display}
        disabled
        required={@rest[:required]}
        class={@class}
        error_class={@error_class}
        errors={@errors}
      />
      <input :for={v <- @hidden_values} type="hidden" name={@hidden_name} value={v} />
    </div>
    """
  end

  def input(%{type: "select"} = assigns) do
    assigns = assign_new(assigns, :form_field, fn -> nil end)

    assigns =
      assign_new(assigns, :safe_field, fn ->
        if assigns.form_field do
          %{assigns.form_field | value: assigns[:value]}
        else
          %{
            to_form(%{assigns.name => assigns.value}, as: "dummy")[assigns.name]
            | id: assigns.id || assigns.name,
              name: assigns.name,
              errors: assigns[:errors] || []
          }
        end
      end)

    field = assigns.safe_field

    {div_attrs, live_select_attrs} =
      Enum.split_with(assigns.rest, fn {k, _v} ->
        k = to_string(k)

        cond do
          k == "class" -> true
          k == "phx-click" -> true
          k == "phx-hook" -> true
          k == "role" -> true
          String.starts_with?(k, "aria-") -> true
          String.starts_with?(k, "phx-value-") -> true
          true -> false
        end
      end)

    custom_class =
      Enum.find_value(div_attrs, fn {k, v} ->
        if to_string(k) == "class", do: v
      end)

    div_attrs = Enum.reject(div_attrs, fn {k, _v} -> to_string(k) == "class" end)

    div_attrs =
      if Enum.any?(div_attrs, fn {key, _value} ->
           key in [:"aria-label", :"aria-labelledby", :"aria-describedby"]
         end) do
        Keyword.put_new(div_attrs, :role, "group")
      else
        div_attrs
      end

    hook_wrapper_id =
      if Enum.any?(div_attrs, fn {k, _v} -> to_string(k) == "phx-hook" end) do
        live_select_id =
          Enum.find_value(live_select_attrs, field.id, fn {k, v} ->
            if to_string(k) == "id" && v not in [nil, ""], do: v
          end)

        "lswrapper-" <> to_string(live_select_id)
      end

    live_select_attrs =
      live_select_attrs
      |> Keyword.take(@live_select_rest_global)
      |> Keyword.drop([:value])

    mode = assigns.mode

    live_select_attrs =
      Keyword.drop(live_select_attrs, [
        :field,
        :id,
        :options,
        :mode,
        :dropdown_class,
        :placeholder,
        :text_input_class,
        :text_input_selected_class,
        :option_class,
        :available_option_class,
        :unavailable_option_class,
        :selected_option_class,
        :active_option_class,
        :container_class,
        :clear_button_extra_class,
        :tag_class,
        :clear_tag_button_extra_class,
        :tags_container_extra_class,
        :keep_label_on_select
      ])
      |> Keyword.put_new(:allow_clear, true)
      |> Keyword.put_new(:"phx-focus", "live_select_change")
      |> Keyword.put_new(:dropdown_selectable_priority, true)

    live_select_attrs =
      if Keyword.has_key?(live_select_attrs, :value_mapper) do
        live_select_attrs
      else
        atom_values =
          assigns[:value]
          |> List.wrap()
          |> Enum.filter(&is_atom/1)

        matching_string_option? =
          atom_values != [] &&
            Enum.any?(assigns[:options] || [], fn
              {_label, value} when is_binary(value) ->
                Enum.any?(atom_values, &(value == to_string(&1)))

              %{value: value} when is_binary(value) ->
                Enum.any?(atom_values, &(value == to_string(&1)))

              %{"value" => value} when is_binary(value) ->
                Enum.any?(atom_values, &(value == to_string(&1)))

              value when is_binary(value) ->
                Enum.any?(atom_values, &(value == to_string(&1)))

              _ ->
                false
            end)

        if matching_string_option? do
          Keyword.put(live_select_attrs, :value_mapper, fn
            value when is_atom(value) -> to_string(value)
            value -> value
          end)
        else
          case field.form.source do
            %Ecto.Changeset{types: types} ->
              case Map.get(types, field.field) do
                :integer ->
                  Keyword.put(
                    live_select_attrs,
                    :value_mapper,
                    &Elixirbits.CoreUtils.Parse.to_integer/1
                  )

                _ ->
                  live_select_attrs
              end

            _ ->
              live_select_attrs
          end
        end
      end

    text_look = assigns.render_as in ["text", "text-enabled"]

    container_class =
      cond do
        text_look ->
          "input-text-wrapper relative flex flex-col w-full"

        !assigns[:label] ->
          "input-select-wrapper relative flex flex-col w-full"

        mode == :single ->
          "input-select-wrapper input-floating-wrapper relative flex flex-col w-full"

        true ->
          "input-select-wrapper input-floating-wrapper input-floating-wrapper-tags relative flex flex-col w-full"
      end

    placeholder = assigns.rest[:placeholder]
    label_as_placeholder = placeholder in [nil, ""]

    text_input_class =
      cond do
        text_look ->
          [
            "block w-full appearance-none bg-transparent border-0 text-sm text-content overflow-hidden text-ellipsis whitespace-nowrap focus:outline-none focus:ring-0 focus-visible:underline disabled:overlay-dark disabled:cursor-not-allowed disabled:text-subcontent",
            if(assigns[:label], do: "min-h-6 py-1", else: "min-h-11 text-center"),
            assigns.errors != [] && (assigns.error_class || "text-error")
          ]

        assigns[:label] ->
          [
            "input-floating-control block w-full min-h-11 px-3 rounded-default border bg-transparent text-content focus:outline-none focus:border-brand focus:ring-2 focus:ring-brand disabled:overlay-dark disabled:text-subcontent disabled:cursor-not-allowed",
            (assigns.errors == [] || assigns.error_class) && "border-outline"
          ]

        true ->
          [
            "block w-full min-h-11 px-3 py-2 rounded-default border bg-transparent text-content focus:outline-none focus:border-brand focus:ring-2 focus:ring-brand disabled:overlay-dark disabled:text-subcontent disabled:cursor-not-allowed",
            (assigns.errors == [] || assigns.error_class) && "border-outline"
          ]
      end

    assigns =
      assigns
      |> assign(:live_select_opts, live_select_attrs)
      |> assign(:div_attrs, div_attrs)
      |> assign(:custom_class, custom_class)
      |> assign(
        :hook_wrapper_id,
        hook_wrapper_id || "#{assigns.select_id || assigns.id || "#{field.id}-ls"}-dropdown"
      )
      |> assign(:mode, mode)
      |> assign(:container_class, container_class)
      |> assign(:text_look, text_look)
      |> assign(:text_input_class, text_input_class)
      |> assign(:label_as_placeholder, label_as_placeholder)
      |> assign(
        :placeholder,
        cond do
          text_look -> placeholder || assigns[:prompt]
          assigns[:label] -> if(label_as_placeholder, do: " ", else: placeholder)
          true -> assigns[:prompt]
        end
      )

    ~H"""
    <div class={@custom_class} {@div_attrs}>
      <label
        for={"#{@safe_field.id}_text_input"}
        class={if @text_look, do: "flex flex-col gap-1", else: "relative block"}
      >
        <span
          :if={@text_look && @label}
          class={["text-sm font-medium", (@errors != [] && "text-error") || "text-subcontent"]}
        >
          {@label}<span
            :if={@rest[:required] && @label not in [nil, ""]}
            aria-hidden="true"
            class="ml-1 text-error"
          >*</span>
        </span>
        <div id={@hook_wrapper_id} phx-hook="SelectDropdown">
          <LiveSelect.live_select
            field={@safe_field}
            id={@select_id || @id || "#{@safe_field.id}-ls"}
            mode={@mode}
            options={@options}
            text_input_class={[
              @class || @text_input_class,
              !@text_look && @errors != [] &&
                (@error_class || "border-error focus:border-error focus:ring-error")
            ]}
            text_input_selected_class=""
            dropdown_class="select-dropdown rounded-default border border-outline bg-primary shadow-lg z-50 overflow-y-auto"
            option_class="select-none relative py-2 px-3 hover:overlay-light"
            available_option_class="cursor-pointer text-content"
            unavailable_option_class="cursor-not-allowed text-subcontent [&>div]:pointer-events-none"
            selected_option_class="cursor-pointer text-content bg-primary overlay-dark font-semibold order-first"
            active_option_class="overlay-light"
            container_class={@container_class}
            clear_button_extra_class="right-9! top-1/2! -translate-y-1/2! flex items-center cursor-pointer text-error"
            tag_class="group/tag mr-1 mt-1 p-1.5 text-sm rounded-default border border-outline bg-secondary text-content flex items-center gap-1"
            clear_tag_button_extra_class="text-error cursor-pointer opacity-0 pointer-events-none group-hover/tag:opacity-100 group-hover/tag:pointer-events-auto focus-visible:opacity-100 focus-visible:pointer-events-auto"
            tags_container_extra_class="order-last flex flex-wrap"
            placeholder={@placeholder}
            keep_label_on_select
            {@live_select_opts}
          />
        </div>
        <span
          :if={!@text_look && @label}
          class={[
            "input-floating-label",
            !@label_as_placeholder && "input-floating-label-hidden",
            @errors != [] && "input-floating-label-error"
          ]}
        >
          {@label}<span
            :if={@rest[:required] && @label not in [nil, ""]}
            aria-hidden="true"
            class="ml-1 text-error"
          >*</span>
        </span>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "textarea"} = assigns) do
    assigns = assign(assigns, :rest, Map.put_new(assigns.rest, :"phx-debounce", "blur"))

    if assigns[:label] do
      placeholder = assigns.rest[:placeholder]
      label_as_placeholder = placeholder in [nil, ""]

      assigns =
        assigns
        |> assign(:rest, Map.delete(assigns.rest, :placeholder))
        |> assign(:placeholder, if(label_as_placeholder, do: " ", else: placeholder))
        |> assign(:label_as_placeholder, label_as_placeholder)

      ~H"""
      <div>
        <label for={@id} class="relative block">
          <textarea
            id={@id}
            name={@name}
            placeholder={@placeholder}
            class={[
              @class ||
                [
                  "input-floating-control input-floating-textarea block w-full px-3 rounded-default border bg-transparent text-content focus:outline-none focus:border-brand focus:ring-2 focus:ring-brand disabled:overlay-dark disabled:text-subcontent disabled:cursor-not-allowed",
                  (@errors == [] || @error_class) && "border-outline"
                ],
              @errors != [] && (@error_class || "border-error focus:border-error focus:ring-error")
            ]}
            {@rest}
          >{Phoenix.HTML.Form.normalize_value("textarea", @value)}</textarea>
          <span class={[
            "input-floating-label",
            !@label_as_placeholder && "input-floating-label-hidden",
            @errors != [] && "input-floating-label-error"
          ]}>
            {@label}<span
              :if={@rest[:required] && @label not in [nil, ""]}
              aria-hidden="true"
              class="ml-1 text-error"
            >*</span>
          </span>
        </label>
        <.error :for={msg <- @errors}>{msg}</.error>
      </div>
      """
    else
      ~H"""
      <div>
        <label for={@id} class="block">
          <textarea
            id={@id}
            name={@name}
            class={[
              @class ||
                [
                  "block w-full px-3 py-2 rounded-default border bg-transparent text-content focus:outline-none focus:border-brand focus:ring-2 focus:ring-brand disabled:overlay-dark disabled:text-subcontent disabled:cursor-not-allowed",
                  (@errors == [] || @error_class) && "border-outline"
                ],
              @errors != [] && (@error_class || "border-error focus:border-error focus:ring-error")
            ]}
            {@rest}
          >{Phoenix.HTML.Form.normalize_value("textarea", @value)}</textarea>
        </label>
        <.error :for={msg <- @errors}>{msg}</.error>
      </div>
      """
    end
  end

  def input(%{type: "date"} = assigns), do: vcalendar_input(assigns)
  def input(%{type: "datetime-local"} = assigns), do: vcalendar_input(assigns)
  def input(%{type: "time"} = assigns), do: vcalendar_input(assigns)
  def input(%{type: "week"} = assigns), do: vcalendar_input(assigns)
  def input(%{type: "month"} = assigns), do: vcalendar_input(assigns)

  def input(%{type: "tel"} = assigns) do
    {dial_code, number, iso} = Elixirbits.CoreUtils.Phones.parse(assigns[:value] || "")

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
    country_field = %{parent_form[country_field_key] | value: iso || ""}
    wrapper_id = "#{assigns[:id] || assigns[:name]}_tel_wrapper"

    countries_json =
      Elixirbits.CoreUtils.Phones.list_countries()
      |> Enum.into(%{}, fn c -> {c.iso, c.dial_code} end)
      |> Jason.encode!()

    composite_value =
      cond do
        dial_code && number != "" -> "#{dial_code}#{number}"
        dial_code -> dial_code
        true -> assigns[:value] || ""
      end

    placeholder = assigns.rest[:placeholder]
    label_as_placeholder = placeholder in [nil, ""]

    assigns =
      assigns
      |> assign(:text_look, assigns.render_as in ["text", "text-enabled"])
      |> assign(
        :rest,
        assigns.rest |> Map.delete(:placeholder) |> Map.put_new(:"phx-debounce", "blur")
      )
      |> assign(:placeholder, if(label_as_placeholder, do: " ", else: placeholder))
      |> assign(:label_as_placeholder, label_as_placeholder)
      |> assign(:country_field, country_field)
      |> assign(:country_id, country_field.id)
      |> assign(:country_name, country_field.name)
      |> assign(:wrapper_id, wrapper_id)
      |> assign(:countries_json, countries_json)
      |> assign(:country_options, Elixirbits.CoreUtils.Phones.options())
      |> assign(:number_value, number)
      |> assign(:composite_value, composite_value)

    ~H"""
    <div>
      <div
        id={@wrapper_id}
        phx-hook="TelInput"
        data-countries={@countries_json}
        data-country-name={@country_name}
        class={[
          "relative",
          @text_look && "flex flex-col gap-1",
          !@text_look &&
            [
              "[&>.input-floating-label]:!left-[4.75rem]",
              "[&:has(.input-floating-control:focus)>.input-floating-label]:!left-3",
              "[&:has(.input-floating-control:not(:placeholder-shown))>.input-floating-label]:!left-3"
            ]
        ]}
      >
        <label
          :if={@text_look && @label}
          for={@id}
          class={["text-sm font-medium", (@errors != [] && "text-error") || "text-subcontent"]}
        >
          {@label}<span
            :if={@rest[:required] && @label not in [nil, ""]}
            aria-hidden="true"
            class="ml-1 text-error"
          >*</span>
        </label>
        <input
          type="hidden"
          name={@name}
          value={@composite_value}
          disabled={@rest[:disabled]}
          form={@rest[:form]}
          data-tel-composite
        />
        <div class={
          if @text_look,
            do: "grid grid-cols-[4rem_1fr] gap-0",
            else: "input-floating-wrapper grid grid-cols-[4rem_auto] gap-0"
        }>
          <div
            id={"#{@country_id}_country_dropdown"}
            phx-hook="SelectDropdown"
            data-dropdown-min-width="18"
          >
            <LiveSelect.live_select
              field={@country_field}
              id={"#{@country_id}_country_select"}
              mode={:single}
              options={@country_options}
              value={@country_field.value}
              disabled={@rest[:disabled] not in [false, nil]}
              text_input_class={[
                if(@text_look,
                  do: [
                    "block w-full appearance-none border-0 bg-transparent text-sm text-content cursor-pointer focus:outline-none focus:ring-0 focus-visible:underline disabled:overlay-dark disabled:text-subcontent disabled:cursor-not-allowed !px-0",
                    if(@label, do: "min-h-6 py-1", else: "min-h-11")
                  ],
                  else:
                    "block w-full min-h-11 px-3 rounded-l-default border border-r-0 border-outline bg-transparent text-content focus:outline-none focus:border-brand focus:border-r-1 focus:ring-2 focus:ring-brand disabled:overlay-dark disabled:text-subcontent disabled:cursor-not-allowed !p-2"
                )
              ]}
              text_input_selected_class=""
              dropdown_class="select-dropdown rounded-default border border-outline bg-primary shadow-lg z-50 overflow-y-auto"
              option_class="select-none relative py-2 px-3 hover:overlay-light"
              available_option_class="cursor-pointer text-content"
              unavailable_option_class="cursor-not-allowed text-subcontent [&>div]:pointer-events-none"
              selected_option_class="cursor-pointer text-content bg-primary overlay-dark font-semibold order-first"
              active_option_class="overlay-light"
              container_class={
                if @text_look,
                  do: "input-text-wrapper relative flex flex-col w-full",
                  else: "relative flex flex-col w-full"
              }
              clear_button_extra_class="right-9! top-1/2! -translate-y-1/2! flex items-center cursor-pointer text-error"
              placeholder="+60"
              keep_label_on_select
              keep_options_on_select
              dropdown_selectable_priority
            />
          </div>
          <input
            type="tel"
            id={@id}
            value={@number_value}
            placeholder={@placeholder}
            data-tel-number
            class={[
              @class ||
                if(@text_look,
                  do: [
                    "block w-full appearance-none border-0 bg-transparent text-sm text-content overflow-hidden text-ellipsis whitespace-nowrap focus:outline-none focus:ring-0 focus-visible:underline disabled:overlay-dark disabled:cursor-not-allowed disabled:text-subcontent",
                    if(@label, do: "min-h-6 py-1", else: "min-h-11"),
                    @errors != [] && (@error_class || "text-error")
                  ],
                  else: [
                    "input-floating-control block w-full min-h-11 px-3 rounded-r-default border bg-transparent text-content focus:outline-none focus:border-brand focus:ring-2 focus:ring-brand disabled:overlay-dark disabled:text-subcontent disabled:cursor-not-allowed",
                    (@errors == [] || @error_class) && "border-outline"
                  ]
                ),
              !@text_look && @errors != [] &&
                (@error_class || "border-error focus:border-error focus:ring-error")
            ]}
            {@rest}
          />
        </div>
        <label
          :if={!@text_look}
          for={@id}
          class={[
            "input-floating-label",
            !@label_as_placeholder && "input-floating-label-hidden",
            @errors != [] && "input-floating-label-error"
          ]}
        >
          {@label}<span
            :if={@rest[:required] && @label not in [nil, ""]}
            aria-hidden="true"
            class="ml-1 text-error"
          >*</span>
        </label>
      </div>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  # All other inputs text, datetime-local, url, password, etc. are handled here...
  def input(assigns) do
    assigns =
      assigns
      |> assign(:rest, Map.put_new(assigns.rest, :"phx-debounce", "blur"))

    if assigns[:label] && assigns.type in ~w(color email file number password search text url) do
      placeholder = assigns.rest[:placeholder]
      label_as_placeholder = placeholder in [nil, ""]

      assigns =
        assigns
        |> assign(:rest, Map.delete(assigns.rest, :placeholder))
        |> assign(:placeholder, if(label_as_placeholder, do: " ", else: placeholder))
        |> assign(:label_as_placeholder, label_as_placeholder)

      ~H"""
      <div>
        <div
          id={@type == "password" && @id not in [nil, ""] && "#{@id}-password-wrapper"}
          phx-hook={@type == "password" && @id not in [nil, ""] && "PasswordVisibility"}
          class="relative block"
        >
          <label for={@id} class="block">
            <input
              type={@type}
              name={@name}
              id={@id}
              value={Phoenix.HTML.Form.normalize_value(@type, @value)}
              placeholder={@placeholder}
              class={[
                @class ||
                  [
                    "input-floating-control block w-full min-h-11 px-3 rounded-default border bg-transparent text-content focus:outline-none focus:border-brand focus:ring-2 focus:ring-brand disabled:overlay-dark disabled:text-subcontent disabled:cursor-not-allowed",
                    (@errors == [] || @error_class) && "border-outline",
                    @type == "password" && "pr-12"
                  ],
                @errors != [] && (@error_class || "border-error focus:border-error focus:ring-error")
              ]}
              {@rest}
            />
            <span class={[
              "input-floating-label",
              !@label_as_placeholder && "input-floating-label-hidden",
              @errors != [] && "input-floating-label-error"
            ]}>
              {@label}<span
                :if={@rest[:required] && @label not in [nil, ""]}
                aria-hidden="true"
                class="ml-1 text-error"
              >*</span>
            </span>
          </label>
          <.password_visibility_toggle
            :if={@type == "password" && @id not in [nil, ""]}
            id={@id}
            disabled={@rest[:disabled]}
          />
        </div>
        <.error :for={msg <- @errors}>{msg}</.error>
      </div>
      """
    else
      ~H"""
      <div>
        <div
          id={@type == "password" && @id not in [nil, ""] && "#{@id}-password-wrapper"}
          phx-hook={@type == "password" && @id not in [nil, ""] && "PasswordVisibility"}
          class="relative block"
        >
          <label for={@id} class="block">
            <span :if={@label} class="block text-sm font-medium text-content mb-1">{@label}<span
              :if={@rest[:required] && @label not in [nil, ""]}
              aria-hidden="true"
              class="ml-1 text-error"
            >*</span></span>
            <input
              type={@type}
              name={@name}
              id={@id}
              value={Phoenix.HTML.Form.normalize_value(@type, @value)}
              class={[
                @class ||
                  [
                    "block w-full min-h-11 px-3 py-2 rounded-default border bg-transparent text-content focus:outline-none focus:border-brand focus:ring-2 focus:ring-brand disabled:overlay-dark disabled:text-subcontent disabled:cursor-not-allowed",
                    (@errors == [] || @error_class) && "border-outline",
                    @type == "password" && "pr-12"
                  ],
                @errors != [] && (@error_class || "border-error focus:border-error focus:ring-error")
              ]}
              {@rest}
            />
          </label>
          <.password_visibility_toggle
            :if={@type == "password" && @id not in [nil, ""]}
            id={@id}
            disabled={@rest[:disabled]}
          />
        </div>
        <.error :for={msg <- @errors}>{msg}</.error>
      </div>
      """
    end
  end

  @doc """
  Renders a destination for a file input's preview. Give the input the same `preview_id`, and keep this destination mounted in the same LiveView. The input owns the files, editing, captions, and media slots; the destination supplies their placement and styling.
  """
  attr :id, :string, required: true
  attr :class, :any, default: "h-36 w-full"
  attr :rest, :global

  def file_preview(assigns) do
    ~H"""
    <div id={@id} data-file-preview-outlet class={@class} {@rest} />
    """
  end

  defp file_previews(assigns) do
    ~H"""
    <div
      id={"#{@file_id}-file-previews"}
      phx-hook="FilePreview"
      data-file-input-id={@file_id}
      data-file-detached={to_string(@file_detached)}
      data-file-preview-as={@preview_as}
      data-file-collection
      hidden={
        (!@preview && @selection != "multiple") ||
          (@file_detached && @render_as in ["hidden", "hidden-enabled", "hidden-disabled"])
      }
      class={[
        "group/file-previews relative",
        @file_detached && "w-full",
        @file_detached && @preview_as == "thumbnail" && "h-full",
        !@file_detached && @selection == "singles" &&
          if(@preview_as == "thumbnail", do: "mt-3", else: "mt-1")
      ]}
    >
      <.button
        :if={@selection == "singles" && @preview}
        type="button"
        data-file-cycle="previous"
        data-file-previous
        hidden={length(@stored) + length(@file_entries) < 2}
        aria-label="Previous file"
        class="grid size-7 place-items-center text-content cursor-pointer focus-visible:text-brand focus-visible:outline-none"
      ><.icon name="hero-chevron-left-mini" class="size-5" /></.button>
      <div
        data-file-preview-content
        class={["min-w-0", @file_detached && @preview_as == "thumbnail" && "h-full"]}
      >
        <div
          :if={@stored != [] or @file_entries != []}
          data-file-server-previews
          class={@previews_class}
        >
          <.file_preview_item
            :for={{url, index} <- Enum.with_index(@stored)}
            input_id={@file_id}
            url={url}
            preview={@preview}
            selection={@selection}
            preview_as={@preview_as}
            thumbnail_class={@thumbnail_class}
            media_slot={@stored_preview}
            caption_slot={@preview_caption}
            editable={@upload != nil && @file_editable}
            edit_enabled={@file_editor_enabled && @file_editable}
            disabled={@rest[:disabled]}
            text_look={@text_look}
            hidden={
              @selection != "multiple" &&
                (index > 0 || (@selection == "single" && @file_entries != []))
            }
            target={@rest[:"phx-target"]}
          />
          <.file_preview_item
            :for={{entry, index} <- Enum.with_index(@file_entries)}
            input_id={@file_id}
            entry={entry}
            preview={@preview}
            selection={@selection}
            preview_as={@preview_as}
            thumbnail_class={@thumbnail_class}
            media_slot={@pending_preview}
            caption_slot={@pending_caption}
            editable={@file_editable}
            edit_enabled={@file_editor_enabled && @file_editable}
            disabled={@rest[:disabled]}
            text_look={@text_look}
            hidden={
              @selection != "multiple" && (index > 0 || (@selection == "singles" && @stored != []))
            }
            target={@rest[:"phx-target"]}
          />
        </div>

        <div
          :if={@upload == nil && (@preview || @selection != "multiple")}
          id={"#{@file_id}-file-preview-frame"}
          data-file-preview-container
          data-file-preview-as={@preview_as}
          hidden
          class={[
            "relative rounded-default border border-outline",
            !@file_detached && @selection != "singles" && "mt-3",
            if(@preview_as == "thumbnail",
              do: ["bg-transparent", @thumbnail_class],
              else: [
                "grid grid-cols-[minmax(0,1fr)_auto] items-center gap-1 bg-secondary p-1.5",
                @selection == "singles" && "px-9"
              ]
            )
          ]}
        >
          <div
            id={"#{@file_id}-file-local-preview"}
            phx-update="ignore"
            data-file-preview-region
            class="contents"
          >
            <img
              data-file-preview-image
              hidden
              alt="Selected image"
              class="size-full rounded-default object-contain"
            />
            <iframe
              data-file-preview-pdf
              hidden
              title="Selected PDF"
              class="size-full rounded-default border-0"
            />
            <a
              data-file-preview-open
              hidden
              target="_blank"
              rel="noopener noreferrer"
              class="grid size-6 place-items-center rounded-default border border-outline bg-primary text-content hover:overlay-dark focus-visible:outline-2 focus-visible:outline-brand"
              aria-label="Open selected file"
            ><.icon name="hero-arrow-top-right-on-square-micro" class="size-4" /></a>
            <span data-file-preview-name hidden class="block truncate text-sm text-subcontent" />
            <span data-file-preview-caption data-file-caption hidden class="block truncate text-sm" />
            <.button
              type="button"
              data-file-edit
              hidden
              disabled={@rest[:disabled] || not @file_editable}
              aria-label="Edit selected image"
              class="grid min-h-7 place-items-center rounded-default border border-outline bg-primary px-2 text-sm text-content cursor-pointer hover:overlay-dark focus-visible:outline-2 focus-visible:outline-brand disabled:cursor-not-allowed"
            >Edit</.button>
          </div>
        </div>
      </div>
      <.button
        :if={@selection == "singles" && @preview}
        type="button"
        data-file-cycle="next"
        data-file-next
        hidden={length(@stored) + length(@file_entries) < 2}
        aria-label="Next file"
        class="grid size-7 place-items-center text-content cursor-pointer focus-visible:text-brand focus-visible:outline-none"
      ><.icon name="hero-chevron-right-mini" class="size-5" /></.button>
      <span
        :if={@selection == "singles" && @preview}
        data-file-position
        data-file-preview-position
        class="text-sm"
      >{@file_position}</span>
    </div>
    """
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

    ~H"""
    <div
      id={"#{@input_id}-file-#{@identity}"}
      data-file-item
      data-file-key={(@entry && @entry.ref) || @url}
      data-file-stored={@entry == nil}
      data-file-entry-ref={@entry && @entry.ref}
      data-file-url={@url}
      data-file-content-type={@content_type}
      data-file-item-name={@file_name}
      hidden={@hidden}
      class={["min-w-0", @hidden && "hidden"]}
    >
      <div
        data-file-preview-as={@preview_as}
        class={
          if @preview_as == "thumbnail" do
            [
              "group/preview relative rounded-default border border-outline bg-transparent",
              @thumbnail_class
            ]
          else
            [
              "group/preview relative grid items-center gap-1 rounded-default border border-outline bg-secondary p-1.5 text-sm text-content",
              if(@selection == "singles", do: "px-9", else: "mr-1 mt-1"),
              if(@preview && not @media_available,
                do: "grid-cols-[minmax(0,1fr)_auto_auto]",
                else: "grid-cols-[minmax(0,1fr)_auto]"
              )
            ]
          end
        }
      >
        <.dynamic_tag
          :if={@caption_hover}
          tag_name={@caption_tag}
          {@caption_rest}
          data-file-caption
          data-file-filename
          class="block truncate text-sm"
        >
          <%= if @caption_slot != [] do %>
            {render_slot(@caption_slot, @caption_value)}
          <% else %>
            {@file_name}
          <% end %>
        </.dynamic_tag>
        <.dynamic_tag
          :if={@media_available}
          tag_name={if @text_look, do: "label", else: "div"}
          {@caption_rest}
          class={[
            @preview_as == "thumbnail" && "size-full",
            @preview_as == "tag" && @caption_used && "hidden",
            @text_look && "block group-has-[input:focus-visible]/upload:underline",
            @text_look && if(@disabled, do: "cursor-not-allowed", else: "cursor-pointer")
          ]}
        >
          <%= cond do %>
            <% @media_slot != [] -> %>
              {render_slot(@media_slot, @caption_value)}
            <% @content_type == "application/pdf" -> %>
              <div
                id={"#{@input_id}-pdf-#{@identity}"}
                phx-hook="UploadPdfPreview"
                phx-update="ignore"
                data-pdf-url={@url}
                data-upload-ref={@entry && @entry.upload_ref}
                data-entry-ref={@entry && @entry.ref}
                class="relative size-full overflow-hidden rounded-default bg-transparent"
              >
                <iframe
                  data-pdf-viewer
                  title={"PDF preview of #{@file_name}"}
                  hidden
                  class="size-full border-0"
                />
                <p
                  data-pdf-status
                  role="status"
                  class="pointer-events-none absolute inset-0 grid place-items-center px-2 text-center text-sm text-subcontent"
                >
                  Loading PDF preview...
                </p>
                <a
                  data-pdf-open
                  target="_blank"
                  rel="noopener noreferrer"
                  aria-label={"Open #{@file_name}"}
                  data-tooltip={"Open #{@file_name}"}
                  hidden
                  class="absolute bottom-1 left-1 grid size-6 place-items-center rounded-default border border-outline bg-primary text-content hover:overlay-dark focus-visible:outline-2 focus-visible:outline-brand"
                ><.icon name="hero-arrow-top-right-on-square-micro" class="size-4" /></a>
              </div>
            <% @entry != nil -> %>
              <.live_img_preview
                entry={@entry}
                alt={@file_name}
                class="size-full rounded-default object-contain"
              />
            <% true -> %>
              <img src={@url} alt={@file_name} class="size-full rounded-default object-contain" />
          <% end %>
        </.dynamic_tag>
        <.dynamic_tag
          :if={not @media_available or (@preview_as == "tag" && @caption_used)}
          tag_name={@caption_tag}
          {@caption_rest}
          data-file-filename
          class={[
            "min-w-0 truncate",
            @preview_as == "thumbnail" &&
              "grid size-full place-items-center px-2 text-sm text-subcontent",
            @text_look && "group-has-[input:focus-visible]/upload:underline",
            @text_look && if(@disabled, do: "cursor-not-allowed", else: "cursor-pointer")
          ]}
        >
          <%= if @caption_slot != [] do %>
            {render_slot(@caption_slot, @caption_value)}
          <% else %>
            {@file_name}
          <% end %>
        </.dynamic_tag>
        <a
          :if={@preview && not @media_available}
          href={@url}
          data-file-open
          data-upload-ref={@entry && @entry.upload_ref}
          data-entry-ref={@entry && @entry.ref}
          aria-label={"Open #{@file_name}"}
          target="_blank"
          rel="noopener noreferrer"
          class={[
            "grid size-6 place-items-center rounded-default border border-outline bg-primary text-content hover:overlay-dark focus-visible:outline-2 focus-visible:outline-brand",
            @preview_as == "thumbnail" && "absolute bottom-1 left-1"
          ]}
        ><.icon name="hero-arrow-top-right-on-square-micro" class="size-4" /></a>
        <.button
          :if={@edit_enabled && @content_type in ~w(image/png image/jpeg image/gif image/webp)}
          type="button"
          data-file-edit={(@entry && @entry.ref) || @url}
          disabled={@disabled}
          aria-label={"Edit #{@file_name}"}
          class="grid min-h-7 place-items-center rounded-default border border-outline bg-primary px-2 text-sm text-content cursor-pointer hover:overlay-dark focus-visible:outline-2 focus-visible:outline-brand disabled:cursor-not-allowed"
        >Edit</.button>
        <.button
          :if={@editable}
          type="button"
          data-file-remove
          disabled={@disabled}
          phx-click={if @entry, do: "cancel_upload", else: "remove_upload"}
          phx-value-ref={@entry && @entry.ref}
          phx-value-url={@url}
          phx-target={@target}
          aria-label={if @entry, do: "Cancel #{@file_name}", else: "Remove file"}
          class={[
            "min-h-5 min-w-5 text-error cursor-pointer opacity-0 pointer-events-none group-hover/preview:opacity-100 group-hover/preview:pointer-events-auto focus-visible:opacity-100 focus-visible:pointer-events-auto disabled:opacity-0!",
            @preview_as == "thumbnail" && "absolute top-1 right-1"
          ]}
        ><.icon name="hero-x-mark-mini" class="size-5" /></.button>
      </div>
      <span
        :if={@media_slot != [] && !@caption_used && !@caption_hover}
        data-file-filename
        class="sr-only"
      >{@file_name}</span>
      <.dynamic_tag
        :if={!@caption_hover && @preview_as == "thumbnail" && @media_available && @caption_used}
        tag_name={@caption_tag}
        {@caption_rest}
        data-file-filename
        class={[
          "mt-1 block truncate text-sm text-subcontent",
          @text_look && if(@disabled, do: "cursor-not-allowed", else: "cursor-pointer")
        ]}
      >
        <%= if @caption_slot != [] do %>
          {render_slot(@caption_slot, @caption_value)}
        <% else %>
          {@file_name}
        <% end %>
      </.dynamic_tag>
    </div>
    """
  end

  attr :id, :any, required: true
  attr :disabled, :any, default: false

  defp password_visibility_toggle(assigns) do
    ~H"""
    <button
      id={"#{@id}-password-toggle"}
      type="button"
      disabled={@disabled}
      aria-label="Show password"
      aria-pressed="false"
      aria-controls={@id}
      data-password-toggle
      class="absolute right-2 top-1/2 grid h-9 w-9 -translate-y-1/2 place-items-center rounded-default text-subcontent hover:overlay-dark focus:outline-none focus:ring-2 focus:ring-brand disabled:cursor-not-allowed disabled:text-subcontent"
    >
      <span id={"#{@id}-password-eye"} data-password-show-icon>
        <.icon name="hero-eye" class="h-5 w-5" />
      </span>
      <span id={"#{@id}-password-eye-slash"} data-password-hide-icon hidden>
        <.icon name="hero-eye-slash" class="h-5 w-5" />
      </span>
    </button>
    """
  end

  defp vcalendar_input(assigns) do
    timezone = assigns.timezone || "Etc/UTC"

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
        value: value,
        timezone: timezone,
        today: timezone |> DateTime.now!() |> DateTime.to_date() |> Date.to_iso8601(),
        text_look: assigns.render_as in ~w(text text-enabled)
      )

    if assigns[:label] do
      placeholder = assigns.rest[:placeholder]
      label_as_placeholder = placeholder in [nil, ""]

      assigns =
        assigns
        |> assign(:rest, Map.delete(assigns.rest, :placeholder))
        |> assign(
          :placeholder,
          if(label_as_placeholder and not assigns.text_look, do: " ", else: placeholder)
        )
        |> assign(:label_as_placeholder, label_as_placeholder)

      ~H"""
      <div>
        <div class={if @text_look, do: "flex flex-col gap-1", else: "relative block"}>
          <label
            :if={@text_look}
            for={@id}
            class={["text-sm font-medium", (@errors != [] && "text-error") || "text-subcontent"]}
          >
            {@label}<span
              :if={@rest[:required] && @label not in [nil, ""]}
              aria-hidden="true"
              class="ml-1 text-error"
            >*</span>
          </label>
          <input
            type="text"
            name={@name}
            id={@id}
            value={@value}
            placeholder={@placeholder}
            data-vc-mode={@type}
            data-vc-value={@value || ""}
            data-vc-timezone={@timezone}
            data-vc-today={@today}
            phx-hook="VCalendar"
            phx-mounted={JS.ignore_attributes(["value", "aria-haspopup", "aria-expanded"])}
            readonly
            class={[
              @class ||
                if @text_look do
                  "block w-full min-h-6 py-1 appearance-none bg-transparent border-0 text-sm text-content overflow-hidden text-ellipsis whitespace-nowrap cursor-pointer focus:outline-none focus:ring-0 focus-visible:underline disabled:overlay-dark disabled:text-subcontent disabled:cursor-not-allowed"
                else
                  [
                    "input-floating-control block w-full min-h-11 px-3 rounded-default border bg-transparent text-content focus:outline-none focus:border-brand focus:ring-2 focus:ring-brand disabled:overlay-dark disabled:text-subcontent disabled:cursor-not-allowed",
                    (@errors == [] || @error_class) && "border-outline"
                  ]
                end,
              @errors != [] &&
                (@error_class ||
                   if(@text_look,
                     do: "text-error",
                     else: "border-error focus:border-error focus:ring-error"
                   ))
            ]}
            {@rest}
          />
          <span
            :if={not @text_look}
            class={[
              "input-floating-label",
              !@label_as_placeholder && "input-floating-label-hidden",
              @errors != [] && "input-floating-label-error"
            ]}
          >
            {@label}<span
              :if={@rest[:required] && @label not in [nil, ""]}
              aria-hidden="true"
              class="ml-1 text-error"
            >*</span>
          </span>
        </div>
        <.error :for={msg <- @errors}>{msg}</.error>
      </div>
      """
    else
      ~H"""
      <div>
        <input
          type="text"
          name={@name}
          id={@id}
          value={@value}
          data-vc-mode={@type}
          data-vc-value={@value || ""}
          data-vc-timezone={@timezone}
          data-vc-today={@today}
          phx-hook="VCalendar"
          phx-mounted={JS.ignore_attributes(["value", "aria-haspopup", "aria-expanded"])}
          readonly
          class={[
            @class ||
              if @text_look do
                "block w-full min-h-11 text-center appearance-none bg-transparent border-0 text-sm text-content overflow-hidden text-ellipsis whitespace-nowrap cursor-pointer focus:outline-none focus:ring-0 focus-visible:underline disabled:overlay-dark disabled:text-subcontent disabled:cursor-not-allowed"
              else
                [
                  "block w-full min-h-11 px-3 py-2 rounded-default border bg-transparent text-content focus:outline-none focus:border-brand focus:ring-2 focus:ring-brand disabled:overlay-dark disabled:text-subcontent disabled:cursor-not-allowed",
                  (@errors == [] || @error_class) && "border-outline"
                ]
              end,
            @errors != [] &&
              (@error_class ||
                 if(@text_look,
                   do: "text-error",
                   else: "border-error focus:border-error focus:ring-error"
                 ))
          ]}
          {@rest}
        />
        <.error :for={msg <- @errors}>{msg}</.error>
      </div>
      """
    end
  end

  defp option_display_label(value, options) when value not in [nil, ""] do
    Enum.find_value(options, to_string(value), fn opt ->
      {opt_value, opt_label} =
        case opt do
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

  # Helper used by inputs to generate form errors
  defp error(assigns) do
    ~H"""
    <p class="mt-1.5 flex gap-2 items-center text-sm text-error">
      <.icon name="hero-exclamation-circle" class="size-5" />
      {render_slot(@inner_block)}
    </p>
    """
  end

  @doc """
  Renders a page section on a raised card surface.

  Form sections and detail groups share this surface, with their own `<.header>` inside.

  ## Examples

      <.card>
        <.header>
          Identity
          <:subtitle>Venue name and registration numbers.</:subtitle>
        </.header>
        ...
      </.card>
  """
  attr :id, :string, default: nil
  attr :class, :any, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  def card(assigns) do
    ~H"""
    <section
      id={@id}
      class={[
        "flex flex-col rounded-default border border-outline bg-primary shadow-sm",
        @class
      ]}
      {@rest}
    >
      <div class="flex flex-col gap-4 p-6">
        {render_slot(@inner_block)}
      </div>
    </section>
    """
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
    ~H"""
    <div
      id={@id}
      class={["rounded-default border border-outline bg-secondary text-content p-4", @class]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc """
  Renders a header with title.
  """
  slot :inner_block, required: true
  slot :subtitle
  slot :actions

  def header(assigns) do
    ~H"""
    <header class={[@actions != [] && "grid grid-cols-[1fr_max-content] items-center gap-6", "pb-4"]}>
      <div>
        <h1 class="text-lg font-semibold leading-8">
          {render_slot(@inner_block)}
        </h1>
        <p :if={@subtitle != []} class="text-sm text-subcontent">
          {render_slot(@subtitle)}
        </p>
      </div>
      <div>{render_slot(@actions)}</div>
    </header>
    """
  end

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

    ~H"""
    <div class="listing-surface overflow-x-auto">
      <table class="listing-table">
        <thead>
          <tr>
            <th :for={col <- @col} class="listing-heading">{col[:label]}</th>
            <th :if={@action != []} class="listing-heading">
              <span class="sr-only">{gettext("Actions")}</span>
            </th>
          </tr>
        </thead>
        <tbody id={@id} phx-update={is_struct(@rows, Phoenix.LiveView.LiveStream) && "stream"}>
          <tr :for={row <- @rows} id={@row_id && @row_id.(row)}>
            <td
              :for={col <- @col}
              phx-click={@row_click && @row_click.(row)}
              class={["listing-cell", @row_click && "hover:cursor-pointer"]}
            >
              {render_slot(col, @row_item.(row))}
            </td>
            <td :if={@action != []} class={["listing-cell", "w-0"]}>
              <div
                class="grid grid-cols-[repeat(var(--action-count),max-content)] items-center gap-4"
                style={"--action-count: #{length(@action)}"}
              >
                <%= for action <- @action do %>
                  {render_slot(action, @row_item.(row))}
                <% end %>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    """
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
    ~H"""
    <ul class="flex flex-col divide-y divide-outline">
      <li :for={item <- @item} class="flex gap-4 p-3 items-center">
        <div class="flex-1">
          <div class="font-bold">{item.title}</div>
          <div>{render_slot(item)}</div>
        </div>
      </li>
    </ul>
    """
  end

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
    ~H"""
    <div
      :if={@show}
      id={@id}
      class="fixed inset-0 z-50 grid place-items-center p-4"
      phx-mounted={JS.push_focus() |> JS.focus_first(to: "##{@id}-content")}
      phx-remove={JS.pop_focus()}
      phx-window-keydown={JS.exec("data-cancel", to: "##{@id}")}
      phx-key="Escape"
      data-cancel={@on_cancel}
    >
      <div
        class="absolute inset-0 bg-dark"
        phx-click={JS.exec("data-cancel", to: "##{@id}")}
        aria-hidden="true"
      />
      <.focus_wrap
        id={"#{@id}-content"}
        role="dialog"
        aria-modal="true"
        aria-labelledby={@title != [] && "#{@id}-title"}
        aria-label={@title == [] && @label}
        class="relative z-10 w-full max-w-lg rounded-default border border-outline bg-primary p-6 shadow-lg"
      >
        <h2 :if={@title != []} id={"#{@id}-title"} class="mb-4 text-lg font-semibold text-content">
          {render_slot(@title)}
        </h2>
        {render_slot(@inner_block)}
      </.focus_wrap>
    </div>
    """
  end

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
    ~H"""
    <span class={[@name, @class]} />
    """
  end

  def icon(%{name: "tabler-" <> _} = assigns) do
    ~H"""
    <span class={[@name, @class]} />
    """
  end

  ## JS Commands

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
      Gettext.dngettext(ElixirbitsWeb.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(ElixirbitsWeb.Gettext, "errors", msg, opts)
    end
  end

  @doc """
  Translates the errors for a field from a keyword list of errors.
  """
  def translate_errors(errors, field) when is_list(errors) do
    for {^field, {msg, opts}} <- errors, do: translate_error({msg, opts})
  end
end

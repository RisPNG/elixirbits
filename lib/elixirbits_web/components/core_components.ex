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

  A labeled button that stands alongside `action_button/1` takes a `variant` instead of hand-rolled classes, so it matches the icon buttons in height and tone: `:primary` for the action a page exists to perform, `:neutral` for everything else, `:danger` for destructive confirmations.

      <.button variant={:primary} phx-click="complete">Complete &amp; post variances</.button>
      <.button variant={:neutral} phx-click="cancel_delete">Cancel</.button>

  Leaving `variant` unset keeps the bare button, for tiles, tabs, and other controls that are not part of the action family.
  """
  attr :rest, :global,
    include: ~w(href navigate patch method download name value disabled type target rel)

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

  Passing `upload` puts a strip of previews under the control, the way a `:quick_tags` select puts its tags under the input: the files already stored on the record, followed by the ones picked but not yet saved. Give `stored` the URLs held on the record, wrapping a single-file value in a list. Describe each preview with the `preview` slot (given a stored URL) and the `pending` slot (given an upload entry).

  `preview_as` controls the layout of each preview and its clear button. The default `"tag"` wraps the slot in the same chip a LiveSelect tag uses, with the clear button inline after the label. This suits previews that show only a name, such as a document. `"thumbnail"` lets the slot render the file content and places a round clear button in its top-right corner, which suits previews that show an image.

  Either way a LiveView rendering a file field handles exactly two events: `"remove_upload"` with `phx-value-url` for a stored file, and `"cancel_upload"` with `phx-value-ref` for a picked one. Any visible `render_as` other than `"enabled"` keeps the previews, removes those buttons, and hides and disables the file control, leaving the field read-only while preserving the browser's picked files for pending previews. Hidden modes apply to the entire field, including its previews. `"hidden-disabled"` keeps the hidden native input disabled and retains the previews so switching modes preserves picked files.

  ```heex
  <.input
    type="file"
    name="images"
    label="Images"
    upload={@uploads.images}
    stored={@images}
    preview_as="thumbnail"
  >
    <:preview :let={url}><img src={url} class="size-20 rounded-default object-cover" /></:preview>
    <:pending :let={entry}><.live_img_preview entry={entry} class="size-20" /></:pending>
  </.input>
  ```

  ## Render as

  The `render_as` attribute controls how the control is rendered:

    * `"enabled"`: the real input (default)
    * `"disabled"`: a lookalike span with the disabled input visual. No input is rendered, so the value does not submit
    * `"like-enabled"`: a lookalike span with the enabled input visual. No input is rendered, so the value does not submit
    * `"like-disabled"`: a lookalike span with the disabled input visual plus the real input rendered hidden, so native input behavior (submission) still works
    * `"hidden"` / `"hidden-enabled"`: the real input rendered hidden, so native input behavior still works
    * `"hidden-disabled"`: nothing is rendered, except live uploads retain their disabled input and previews inside a hidden field to preserve picked files
    * `"text"` / `"text-enabled"`: the real editable input with a plain text visual
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

  attr :preview_as, :string,
    default: "tag",
    values: ~w(tag thumbnail),
    doc:
      "how a file field draws each preview: \"tag\" for a chip that clears like a LiveSelect tag, \"thumbnail\" for an image tile with a corner clear button"

  slot :preview, doc: "for a file field, renders one stored file, given its URL"
  slot :pending, doc: "for a file field, renders one picked file, given its upload entry"

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
      class={@type in ["checkbox", "switch"] and @variant == "alt" and "w-fit"}
    >
      {input(assign(assigns, :tooltip, nil))}
    </div>
    """
  end

  def input(%{upload: upload} = assigns) when not is_nil(upload) do
    messages =
      upload.entries
      |> Enum.flat_map(&upload_errors(upload, &1))
      |> Enum.concat(upload_errors(upload))
      |> Enum.uniq()
      |> Enum.map(fn
        :too_large -> "File is too large (max #{div(upload.max_file_size, 1_000_000)}MB)."
        :too_many_files -> "Too many files (max #{upload.max_entries})."
        :not_accepted -> "Unsupported file type."
        _other -> "Upload failed."
      end)

    # A thumbnail shows the file, so its remove button sits at the corner of the image. A tag shows only a label, so its clear button works like a LiveSelect tag's.
    {previews_class, preview_class, clear_class, clear_icon_name, clear_icon_class} =
      if assigns.preview_as == "thumbnail" do
        {"grid grid-cols-[1fr_1fr_1fr_1fr] gap-2 mt-3", "relative",
         "absolute -top-2 -right-2 flex size-5 items-center justify-center rounded-full bg-error text-content hover:overlay-dark",
         "hero-x-mark", "size-3"}
      else
        {"flex flex-wrap gap-1 p-1",
         "mr-1 mt-1 p-1.5 text-sm rounded-default border border-outline bg-primary overlay-dark flex items-center gap-1",
         "min-h-5 min-w-5 text-error hover:overlay-dark cursor-pointer", "hero-x-mark-mini",
         "size-5"}
      end

    assigns =
      assigns
      |> assign(:errors, assigns.errors ++ messages)
      |> assign(:previews_class, previews_class)
      |> assign(:preview_class, preview_class)
      |> assign(:clear_class, clear_class)
      |> assign(:clear_icon_name, clear_icon_name)
      |> assign(:clear_icon_class, clear_icon_class)
      |> assign(:upload_editable, assigns.render_as in ["enabled", "hidden", "hidden-enabled"])

    ~H"""
    <div class={@render_as in ["hidden", "hidden-enabled", "hidden-disabled"] && "hidden"}>
      <label
        for={@upload.ref}
        class={if @upload_editable, do: "relative block", else: "hidden"}
      >
        <.live_file_input
          upload={@upload}
          {@rest}
          disabled={@rest[:disabled] || not @upload_editable}
          class={[
            @class ||
              [
                "input-floating-control block w-full min-h-11 px-3 rounded-default border bg-transparent text-content focus:outline-none focus:border-brand focus:ring-2 focus:ring-brand disabled:overlay-dark disabled:text-subcontent disabled:cursor-not-allowed",
                (@errors == [] || @error_class) && "border-outline"
              ],
            @errors != [] && (@error_class || "border-error focus:border-error focus:ring-error")
          ]}
        />
        <span
          :if={@upload_editable}
          class={["input-floating-label", @errors != [] && "input-floating-label-error"]}
        >
          {@label}<span
            :if={@rest[:required] && @label not in [nil, ""]}
            aria-hidden="true"
            class="ml-1 text-error"
          >*</span>
        </span>
      </label>

      <span
        :if={not @upload_editable and @label not in [nil, ""]}
        class="block text-sm font-medium text-subcontent"
      >
        {@label}<span
          :if={@rest[:required] && @label not in [nil, ""]}
          aria-hidden="true"
          class="ml-1 text-error"
        >*</span>
      </span>

      <div :if={@stored != [] or @upload.entries != []} class={@previews_class}>
        <div :for={url <- @stored} class={@preview_class}>
          {render_slot(@preview, url)}
          <.button
            :if={@upload_editable}
            type="button"
            disabled={@rest[:disabled]}
            phx-click="remove_upload"
            aria-label="Remove file"
            phx-value-url={url}
            class={@clear_class}
          >
            <.icon name={@clear_icon_name} class={@clear_icon_class} />
          </.button>
        </div>
        <div :for={entry <- @upload.entries} class={@preview_class}>
          {render_slot(@pending, entry)}
          <.button
            :if={@upload_editable}
            aria-label={"Cancel #{entry.client_name}"}
            type="button"
            disabled={@rest[:disabled]}
            phx-click="cancel_upload"
            phx-value-ref={entry.ref}
            class={@clear_class}
          >
            <.icon name={@clear_icon_name} class={@clear_icon_class} />
          </.button>
        </div>
      </div>

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

  def input(%{render_as: render_as, type: type} = assigns)
      when render_as in ["text", "text-enabled"] and
             type in ["email", "number", "search", "text", "url"] do
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
          type={@type}
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

  def input(%{render_as: render_as} = assigns) when render_as in ["text", "text-enabled"] do
    assigns
    |> assign(:render_as, "enabled")
    |> input()
  end

  def input(%{render_as: render_as, type: type} = assigns)
      when render_as in ["disabled", "like-enabled", "like-disabled", "text-disabled"] and
             type in ["checkbox", "switch"] do
    assigns =
      assigns
      |> assign_new(:value, fn -> nil end)
      |> assign_new(:checked, fn ->
        Phoenix.HTML.Form.normalize_value("checkbox", assigns[:value])
      end)

    checked = assigns.checked
    disabled_look = render_as in ["disabled", "like-disabled"]

    box_class =
      case type do
        "checkbox" ->
          [
            "h-5 w-5 shrink-0 rounded-default border bg-center bg-no-repeat bg-[length:100%_100%]",
            disabled_look && "cursor-not-allowed",
            checked &&
              "bg-control-check",
            case {checked, disabled_look} do
              {true, true} -> "bg-tertiary border-tertiary"
              {true, false} -> "bg-brand border-brand"
              {false, _} -> "bg-transparent border-outline"
            end
          ]

        "switch" ->
          [
            "relative shrink-0 w-11 h-6 rounded-full border before:absolute before:top-[1px] before:left-[1px] before:h-5 before:w-5 before:rounded-full",
            disabled_look && "cursor-not-allowed",
            checked && "before:translate-x-5",
            case {checked, disabled_look} do
              {true, true} -> "bg-tertiary border-tertiary before:bg-subcontent"
              {true, false} -> "bg-brand border-brand before:bg-content"
              {false, _} -> "bg-transparent border-outline before:bg-subcontent"
            end
          ]
      end

    assigns =
      assigns
      |> assign(:disabled_look, disabled_look)
      |> assign(:box_class, box_class)
      |> assign(:span_rest, Map.drop(assigns.rest, [:autocomplete, :placeholder]))

    ~H"""
    <div>
      <div
        id={if @render_as not in ["like-disabled", "text-disabled"], do: @id}
        class={[
          "grid items-center gap-2 w-full min-h-11 px-3 rounded-default border bg-transparent",
          (@errors == [] || @error_class) && "border-outline",
          (@type == "switch" && "grid-cols-[1fr_2.75rem]") || "grid-cols-[1fr_1.25rem]",
          @disabled_look && "overlay-dark cursor-not-allowed",
          @errors != [] && (@error_class || "border-error")
        ]}
        {@span_rest}
      >
        <span class={[
          "text-sm font-medium",
          (@disabled_look && "text-subcontent") || "text-content"
        ]}>
          {@label}<span
            :if={@rest[:required] && @label not in [nil, ""]}
            aria-hidden="true"
            class="ml-1 text-error"
          >*</span>
        </span>
        <span class={@class || @box_class} />
      </div>
      <.error :for={msg <- @errors}>{msg}</.error>
      <div :if={@render_as in ["like-disabled", "text-disabled"]} class="hidden">
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
          "inline-grid grid-cols-[1.25rem_1fr] items-center gap-2 text-sm font-medium text-content",
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
              "appearance-none h-5 w-5 shrink-0 cursor-pointer rounded-default border border-outline bg-transparent checked:bg-brand checked:border-brand focus:outline-none focus:ring-2 focus:ring-brand disabled:overlay-dark disabled:cursor-not-allowed disabled:border-outline disabled:checked:bg-tertiary disabled:checked:border-tertiary checked:bg-control-check bg-center bg-no-repeat bg-[length:100%_100%]"
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
                "appearance-none h-5 w-5 shrink-0 rounded-default border border-outline bg-transparent checked:bg-brand checked:border-brand focus:ring-0 focus:outline-none disabled:cursor-not-allowed disabled:border-outline disabled:checked:bg-tertiary disabled:checked:border-tertiary checked:bg-control-check bg-center bg-no-repeat bg-[length:100%_100%]"
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
                "appearance-none h-5 w-5 shrink-0 cursor-pointer rounded-full border border-outline bg-transparent checked:border-brand checked:bg-brand focus:outline-none focus:ring-2 focus:ring-brand disabled:overlay-dark disabled:cursor-not-allowed disabled:checked:bg-tertiary disabled:checked:border-tertiary checked:bg-control-radio"
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
            "inline-grid grid-cols-[2.75rem_1fr] items-center gap-2 text-sm font-medium text-content",
            "has-[:disabled]:cursor-not-allowed has-[:disabled]:text-subcontent",
            # Unlabeled means it sits in a row under its column heading, so it centers on the column and takes the field height.
            (@label in [nil, ""] && "min-h-11 w-full justify-center") || "",
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
              "peer appearance-none shrink-0 cursor-pointer w-11 h-6 rounded-full border border-outline bg-transparent checked:bg-brand checked:border-brand focus:outline-none focus:ring-2 focus:ring-brand disabled:overlay-dark disabled:cursor-not-allowed disabled:checked:bg-tertiary disabled:checked:border-tertiary transition-colors duration-200 ease-in-out relative before:absolute before:top-[1px] before:left-[1px] before:h-5 before:w-5 before:rounded-full before:bg-subcontent checked:before:translate-x-5 checked:before:bg-content disabled:checked:before:bg-subcontent before:transition-transform before:duration-200 before:ease-in-out"
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
                "peer appearance-none shrink-0 w-11 h-6 rounded-full border border-outline bg-transparent checked:bg-brand checked:border-brand focus:outline-none focus:ring-0 disabled:cursor-not-allowed disabled:checked:bg-tertiary disabled:checked:border-tertiary transition-colors duration-200 ease-in-out relative before:absolute before:top-[1px] before:left-[1px] before:h-5 before:w-5 before:rounded-full before:bg-subcontent checked:before:translate-x-5 checked:before:bg-content disabled:checked:before:bg-subcontent before:transition-transform before:duration-200 before:ease-in-out"
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

    container_class =
      if mode == :single do
        "input-floating-wrapper relative flex flex-col w-full"
      else
        "input-floating-wrapper input-floating-wrapper-tags relative flex flex-col w-full"
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

    if assigns[:label] do
      placeholder = assigns.rest[:placeholder]
      label_as_placeholder = placeholder in [nil, ""]

      assigns =
        assigns
        |> assign(:placeholder, if(label_as_placeholder, do: " ", else: placeholder))
        |> assign(:label_as_placeholder, label_as_placeholder)

      ~H"""
      <div class={@custom_class} {@div_attrs}>
        <label for={"#{@safe_field.id}_text_input"} class="relative block">
          <div id={@hook_wrapper_id} phx-hook="SelectDropdown">
            <LiveSelect.live_select
              field={@safe_field}
              id={@select_id || @id || "#{@safe_field.id}-ls"}
              mode={@mode}
              options={@options}
              text_input_class={[
                @class ||
                  [
                    "input-floating-control block w-full min-h-11 px-3 rounded-default border bg-transparent text-content focus:outline-none focus:border-brand focus:ring-2 focus:ring-brand disabled:overlay-dark disabled:text-subcontent disabled:cursor-not-allowed",
                    (@errors == [] || @error_class) && "border-outline"
                  ],
                @errors != [] &&
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
              clear_button_extra_class="right-9! top-1/2! -translate-y-1/2! flex items-center cursor-pointer text-error hover:overlay-dark"
              tag_class="mr-1 mt-1 p-1.5 text-sm rounded-default border border-outline bg-primary overlay-dark flex items-center gap-1"
              clear_tag_button_extra_class="text-error hover:overlay-dark cursor-pointer"
              tags_container_extra_class="order-last flex flex-wrap"
              placeholder={@placeholder}
              keep_label_on_select
              {@live_select_opts}
            />
          </div>
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
      <div class={@custom_class} {@div_attrs}>
        <label for={"#{@safe_field.id}_text_input"} class="block">
          <div id={@hook_wrapper_id} phx-hook="SelectDropdown">
            <LiveSelect.live_select
              field={@safe_field}
              id={@select_id || @id || "#{@safe_field.id}-ls"}
              mode={@mode}
              options={@options}
              text_input_class={[
                @class ||
                  [
                    "block w-full min-h-11 px-3 py-2 rounded-default border bg-transparent text-content focus:outline-none focus:border-brand focus:ring-2 focus:ring-brand disabled:overlay-dark disabled:text-subcontent disabled:cursor-not-allowed",
                    (@errors == [] || @error_class) && "border-outline"
                  ],
                @errors != [] &&
                  (@error_class || "border-error focus:border-error focus:ring-error")
              ]}
              text_input_selected_class=""
              dropdown_class="select-dropdown rounded-default border border-outline bg-primary shadow-lg z-50 overflow-y-auto"
              option_class="select-none relative py-2 px-3 hover:overlay-light"
              available_option_class="cursor-pointer text-content"
              unavailable_option_class="cursor-not-allowed text-subcontent [&>div]:pointer-events-none"
              selected_option_class="cursor-pointer text-content bg-primary overlay-dark font-semibold order-first"
              active_option_class="overlay-light"
              container_class="relative flex flex-col w-full"
              clear_button_extra_class="right-9! top-1/2! -translate-y-1/2! flex items-center cursor-pointer text-error hover:overlay-dark"
              tag_class="mr-1 mt-1 p-1.5 text-sm rounded-default border border-outline bg-primary overlay-dark flex items-center gap-1"
              clear_tag_button_extra_class="text-error hover:overlay-dark cursor-pointer"
              tags_container_extra_class="order-last flex flex-wrap"
              placeholder={@prompt}
              keep_label_on_select
              {@live_select_opts}
            />
          </div>
        </label>
        <.error :for={msg <- @errors}>{msg}</.error>
      </div>
      """
    end
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
          "[&>.input-floating-label]:!left-[4.75rem]",
          "[&:has(.input-floating-control:focus)>.input-floating-label]:!left-3",
          "[&:has(.input-floating-control:not(:placeholder-shown))>.input-floating-label]:!left-3"
        ]}
      >
        <input
          type="hidden"
          name={@name}
          value={@composite_value}
          disabled={@rest[:disabled]}
          form={@rest[:form]}
          data-tel-composite
        />
        <div class="input-floating-wrapper grid grid-cols-[4rem_auto] gap-0">
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
                "block w-full min-h-11 px-3 rounded-l-default border border-r-0 border-outline bg-transparent text-content focus:outline-none focus:border-brand focus:border-r-1 focus:ring-2 focus:ring-brand disabled:overlay-dark disabled:text-subcontent disabled:cursor-not-allowed !bg-none !p-2"
              ]}
              text_input_selected_class=""
              dropdown_class="select-dropdown rounded-default border border-outline bg-primary shadow-lg z-50 overflow-y-auto"
              option_class="select-none relative py-2 px-3 hover:overlay-light"
              available_option_class="cursor-pointer text-content"
              unavailable_option_class="cursor-not-allowed text-subcontent [&>div]:pointer-events-none"
              selected_option_class="cursor-pointer text-content bg-primary overlay-dark font-semibold order-first"
              active_option_class="overlay-light"
              container_class="relative flex flex-col w-full"
              clear_button_extra_class="right-9! top-1/2! -translate-y-1/2! flex items-center cursor-pointer text-error hover:overlay-dark"
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
                [
                  "input-floating-control block w-full min-h-11 px-3 rounded-r-default border bg-transparent text-content focus:outline-none focus:border-brand focus:ring-2 focus:ring-brand disabled:overlay-dark disabled:text-subcontent disabled:cursor-not-allowed",
                  (@errors == [] || @error_class) && "border-outline"
                ],
              @errors != [] &&
                (@error_class || "border-error focus:border-error focus:ring-error")
            ]}
            {@rest}
          />
        </div>
        <label
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
        today: timezone |> DateTime.now!() |> DateTime.to_date() |> Date.to_iso8601()
      )

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
        <div class="relative block">
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
                [
                  "input-floating-control block w-full min-h-11 px-3 rounded-default border bg-transparent text-content focus:outline-none focus:border-brand focus:ring-2 focus:ring-brand disabled:overlay-dark disabled:text-subcontent disabled:cursor-not-allowed",
                  (@errors == [] || @error_class) && "border-outline"
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
              [
                "block w-full min-h-11 px-3 py-2 rounded-default border bg-transparent text-content focus:outline-none focus:border-brand focus:ring-2 focus:ring-brand disabled:overlay-dark disabled:text-subcontent disabled:cursor-not-allowed",
                (@errors == [] || @error_class) && "border-outline"
              ],
            @errors != [] && (@error_class || "border-error focus:border-error focus:ring-error")
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

  Form sections, listings, and detail groups share this surface, with their own `<.header>` inside.

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
  Renders a recessed panel inside a `<.card>` for nested detail.

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
      class={["rounded-default border border-outline bg-primary overlay-dark p-4", @class]}
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

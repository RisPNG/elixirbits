defmodule ElixirbitsWeb.CoreComponents do
  @moduledoc """
  Provides core UI components.

  At first glance, this module may seem daunting, but its goal is to provide
  core building blocks for your application, such as tables, forms, and
  inputs. The components consist mostly of markup and are well-documented
  with doc strings and declarative assigns. You may customize and style
  them in any way you want, based on your application growth and needs.

  The foundation for styling is Tailwind CSS, a utility-first CSS framework.
  Here are useful references:

    * [Tailwind CSS](https://tailwindcss.com) - the foundational framework
      we build on. You will use it for layout, sizing, flexbox, grid, and
      spacing.

    * [Heroicons](https://heroicons.com) - see `icon/1` for usage.

    * [Phoenix.Component](https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html) -
      the component system used by Phoenix. Some components, such as `<.link>`
      and `<.form>`, are defined there.

  """
  use Phoenix.Component
  use Gettext, backend: ElixirbitsWeb.Gettext

  alias Phoenix.LiveView.JS

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
        "flex items-start gap-3 p-4 rounded-md border w-80 max-w-80 text-wrap shadow-sm",
        @kind == :info && "bg-info border-info text-content-alt",
        @kind == :error && "bg-error border-error text-content-alt",
        @kind == :warning && "bg-warning border-warning text-content-alt"
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
        <button type="button" class="group self-start cursor-pointer" aria-label={gettext("close")}>
          <.icon name="hero-x-mark" class="size-5 opacity-40 group-hover:opacity-70" />
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

      <.button class="px-4 py-2 text-sm bg-brand text-content-alt">Send!</.button>
      <.button phx-click="go" class="px-3 py-1.5 text-sm bg-primary-alt text-brand">Send!</.button>
      <.button navigate={~p"/"} class="px-4 py-2 text-sm bg-transparent text-content">Home</.button>
  """
  attr :rest, :global, include: ~w(href navigate patch method download name value disabled)
  attr :class, :any, default: nil
  slot :inner_block, required: true

  def button(%{rest: rest} = assigns) do
    assigns =
      assign(assigns, :class, [
        "inline-flex items-center justify-center rounded-md font-medium transition-colors focus:outline-none focus:ring-2 focus:ring-brand disabled:opacity-50 disabled:pointer-events-none",
        assigns[:class]
      ])

    if rest[:href] || rest[:navigate] || rest[:patch] do
      ~H"""
      <.link class={@class} {@rest}>
        {render_slot(@inner_block)}
      </.link>
      """
    else
      ~H"""
      <button class={@class} {@rest}>
        {render_slot(@inner_block)}
      </button>
      """
    end
  end

  @doc """
  Renders an input with label and error messages.

  A `Phoenix.HTML.FormField` may be passed as argument,
  which is used to retrieve the input name, id, and values.
  Otherwise all attributes may be passed explicitly.

  ## Types

  This function accepts all HTML input types, considering that:

    * You may also set `type="select"` to render a `<select>` tag

    * `type="checkbox"` is used exclusively to render boolean values

    * For live file uploads, see `Phoenix.Component.live_file_input/1`

  See https://developer.mozilla.org/en-US/docs/Web/HTML/Element/input
  for more information. Unsupported types, such as radio, are best
  written directly in your templates.

  ## Examples

  ```heex
  <.input field={@form[:email]} type="email" />
  <.input name="my-input" errors={["oh no!"]} />
  ```

  ## Select type

  When using `type="select"`, you must pass the `options` and optionally
  a `value` to mark which option should be preselected.

  ```heex
  <.input field={@form[:user_type]} type="select" options={["Admin": "admin", "User": "user"]} />
  ```

  For more information on what kind of data can be passed to `options` see
  [`options_for_select`](https://hexdocs.pm/phoenix_html/Phoenix.HTML.Form.html#options_for_select/2).

  ## Render as

  The `render_as` attribute controls how the control is rendered:

    * `"enabled"` - the real input (default)
    * `"disabled"` - a lookalike span with the disabled input visual; no input is rendered, so the value does not submit
    * `"like-enabled"` - a lookalike span with the enabled input visual; no input is rendered, so the value does not submit
    * `"like-disabled"` - a lookalike span with the disabled input visual plus the real input rendered hidden, so native input behaviour (submission) still works
    * `"hidden"` / `"hidden-enabled"` - the real input rendered hidden, so native input behaviour still works
    * `"hidden-disabled"` - nothing is rendered
  """
  attr :id, :any, default: nil
  attr :name, :any
  attr :label, :string, default: nil
  attr :value, :any

  attr :type, :string,
    default: "text",
    values: ~w(checkbox color date datetime-local email file month number password
               search select switch tel text textarea time url week hidden)

  attr :field, Phoenix.HTML.FormField,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"

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
    values: ~w(enabled disabled like-enabled like-disabled hidden hidden-enabled hidden-disabled)

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

    assigns
    |> assign(field: nil, form_field: field, id: assigns.id || field.id)
    |> assign(:errors, Enum.map(errors, &translate_error(&1)))
    |> assign_new(:name, fn ->
      if assigns.mode in [:tags, :quick_tags], do: field.name <> "[]", else: field.name
    end)
    |> assign_new(:value, fn -> field.value end)
    |> input()
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

    box_class =
      case type do
        "checkbox" ->
          [
            "h-5 w-5 shrink-0 rounded border bg-center bg-no-repeat bg-[length:100%_100%]",
            disabled_look && "cursor-not-allowed",
            checked &&
              "bg-[url('data:image/svg+xml,%3csvg%20viewBox=%220%200%2016%2016%22%20fill=%22white%22%20xmlns=%22http://www.w3.org/2000/svg%22%3e%3cpath%20d=%22M12.207%204.793a1%201%200%20010%201.414l-5%205a1%201%200%2001-1.414%200l-2-2a1%201%200%20011.414-1.414L6.5%209.086l4.293-4.293a1%201%200%20011.414%200z%22/%3e%3c/svg%3e')]",
            case {checked, disabled_look} do
              {true, true} -> "bg-tertiary border-tertiary-alt"
              {true, false} -> "bg-brand border-brand"
              {false, _} -> "bg-primary-alt border-primary-alt"
            end
          ]

        "switch" ->
          [
            "relative shrink-0 w-11 h-6 rounded-full border before:absolute before:top-[1px] before:left-[1px] before:h-5 before:w-5 before:rounded-full",
            disabled_look && "cursor-not-allowed",
            (checked && "bg-brand border-brand before:translate-x-5 before:bg-content-alt") ||
              "bg-primary-alt border-primary-alt before:bg-subcontent"
          ]
      end

    assigns =
      assigns
      |> assign(:disabled_look, disabled_look)
      |> assign(:box_class, box_class)
      |> assign(:span_rest, Map.drop(assigns.rest, [:autocomplete, :placeholder]))

    ~H"""
    <div class="mb-2">
      <div
        id={if @render_as != "like-disabled", do: @id}
        class={[
          "flex items-center justify-between w-full min-h-11 px-3 rounded-md border border-primary-alt",
          (@disabled_look && "cursor-not-allowed bg-primary-alt") || "bg-primary",
          @errors != [] && (@error_class || "border-error")
        ]}
        {@span_rest}
      >
        <span class={[
          "flex items-center gap-2 text-sm font-medium",
          (@disabled_look && "text-subcontent") || "text-content"
        ]}>
          {@label}
        </span>
        <span class={@class || @box_class} />
      </div>
      <.error :for={msg <- @errors}>{msg}</.error>
      <div :if={@render_as == "like-disabled"} class="hidden">
        {input(assign(assigns, :render_as, "enabled"))}
      </div>
    </div>
    """
  end

  def input(%{render_as: render_as} = assigns)
      when render_as in ["disabled", "like-enabled", "like-disabled"] do
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

    filled = display not in [nil, ""]
    placeholder = assigns.rest[:placeholder]
    disabled_look = render_as in ["disabled", "like-disabled"]

    span_class = [
      if(assigns.type == "textarea",
        do: "block whitespace-pre-wrap",
        else: "flex items-center overflow-hidden whitespace-nowrap"
      ),
      "w-full min-h-11 px-3 rounded-md border border-primary-alt",
      if(filled,
        do: ["input-floating-control", assigns.type == "textarea" && "input-floating-textarea"],
        else: "py-2"
      ),
      cond do
        disabled_look -> "cursor-not-allowed bg-primary-alt text-subcontent"
        not filled and placeholder not in [nil, ""] -> "bg-primary text-subcontent"
        true -> "bg-primary text-content"
      end,
      assigns.errors != [] && (assigns.error_class || "border-error")
    ]

    assigns =
      assigns
      |> assign(:display, if(filled, do: display, else: placeholder))
      |> assign(:filled, filled)
      |> assign(:disabled_look, disabled_look)
      |> assign(:label_as_placeholder, placeholder in [nil, ""])
      |> assign(:span_class, span_class)
      |> assign(:span_rest, Map.drop(assigns.rest, [:autocomplete, :placeholder]))

    ~H"""
    <div class="mb-2">
      <div class="relative block">
        <span
          id={if @render_as != "like-disabled", do: @id}
          class={@class || @span_class}
          {@span_rest}
          phx-no-format
        >{@display}</span>
        <span
          :if={@label}
          class={[
            "input-floating-label",
            !@label_as_placeholder && "input-floating-label-hidden",
            @errors != [] && "input-floating-label-error",
            @filled && @disabled_look && "input-floating-label-on-disabled"
          ]}
        >
          {@label}
        </span>
      </div>
      <.error :for={msg <- @errors}>{msg}</.error>
      <div :if={@render_as == "like-disabled"} class="hidden">
        {input(assign(assigns, :render_as, "enabled"))}
      </div>
    </div>
    """
  end

  def input(%{type: "hidden"} = assigns) do
    ~H"""
    <input type="hidden" id={@id} name={@name} value={@value} {@rest} />
    """
  end

  def input(%{type: "checkbox"} = assigns) do
    assigns =
      assign_new(assigns, :checked, fn ->
        Phoenix.HTML.Form.normalize_value("checkbox", assigns[:value])
      end)

    ~H"""
    <div class="mb-2">
      <label
        for={@id}
        class={[
          "group cursor-pointer flex items-center justify-between w-full min-h-11 px-3 rounded-md border border-primary-alt bg-primary text-content focus-within:border-brand focus-within:ring-2 focus-within:ring-brand",
          "has-[:disabled]:cursor-not-allowed has-[:disabled]:bg-primary-alt has-[:disabled]:text-subcontent",
          @errors != [] &&
            (@error_class || "border-error focus-within:border-error focus-within:ring-error")
        ]}
      >
        <span class="flex items-center gap-2 text-sm font-medium text-content group-has-[:disabled]:text-subcontent">
          {@label}
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
                "appearance-none h-5 w-5 shrink-0 rounded border border-primary-alt bg-primary-alt checked:bg-brand checked:border-brand focus:ring-0 focus:outline-none disabled:cursor-not-allowed disabled:bg-primary-alt disabled:border-primary-alt disabled:checked:bg-tertiary disabled:checked:border-tertiary-alt checked:bg-[url('data:image/svg+xml,%3csvg%20viewBox=%220%200%2016%2016%22%20fill=%22white%22%20xmlns=%22http://www.w3.org/2000/svg%22%3e%3cpath%20d=%22M12.207%204.793a1%201%200%20010%201.414l-5%205a1%201%200%2001-1.414%200l-2-2a1%201%200%20011.414-1.414L6.5%209.086l4.293-4.293a1%201%200%20011.414%200z%22/%3e%3c/svg%3e')] bg-center bg-no-repeat bg-[length:100%_100%]"
            }
            {@rest}
          />
        </div>
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
    <div class="mb-2">
      <label
        for={@id}
        class={[
          "group cursor-pointer flex items-center justify-between w-full min-h-11 px-3 rounded-md border border-primary-alt bg-primary text-content focus-within:border-brand focus-within:ring-2 focus-within:ring-brand",
          "has-[:disabled]:cursor-not-allowed has-[:disabled]:bg-primary-alt has-[:disabled]:text-subcontent",
          @errors != [] &&
            (@error_class || "border-error focus-within:border-error focus-within:ring-error")
        ]}
      >
        <span class="flex items-center gap-2 text-sm font-medium text-content group-has-[:disabled]:text-subcontent">
          {@label}
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
                "peer appearance-none shrink-0 w-11 h-6 rounded-full border border-primary-alt bg-primary-alt checked:bg-brand checked:border-brand focus:outline-none focus:ring-0 disabled:cursor-not-allowed transition-colors duration-200 ease-in-out relative before:absolute before:top-[1px] before:left-[1px] before:h-5 before:w-5 before:rounded-full before:bg-subcontent checked:before:translate-x-5 checked:before:bg-content-alt before:transition-transform before:duration-200 before:ease-in-out"
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
        assigns.form_field ||
          %{
            to_form(%{assigns.name => assigns.value}, as: "dummy")[assigns.name]
            | id: assigns.id || assigns.name,
              name: assigns.name,
              errors: assigns[:errors] || []
          }
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

    ~H"""
    <.input
      id={@id || @safe_field.id}
      name={@safe_field.name}
      type="text"
      label={assigns[:label]}
      value={@display}
      disabled
      class={@class}
      error_class={@error_class}
      errors={@errors}
    />
    <input :for={v <- @hidden_values} type="hidden" name={@hidden_name} value={v} />
    """
  end

  def input(%{type: "select"} = assigns) do
    assigns = assign_new(assigns, :form_field, fn -> nil end)

    assigns =
      assign_new(assigns, :safe_field, fn ->
        assigns.form_field ||
          %{
            to_form(%{assigns.name => assigns.value}, as: "dummy")[assigns.name]
            | id: assigns.id || assigns.name,
              name: assigns.name,
              errors: assigns[:errors] || []
          }
      end)

    field = assigns.safe_field

    {div_attrs, live_select_attrs} =
      Enum.split_with(assigns.rest, fn {k, _v} ->
        k = to_string(k)

        cond do
          k == "class" -> true
          k == "phx-click" -> true
          k == "phx-hook" -> true
          String.starts_with?(k, "phx-value-") -> true
          true -> false
        end
      end)

    custom_class =
      Enum.find_value(div_attrs, fn {k, v} ->
        if to_string(k) == "class", do: v
      end)

    div_attrs = Enum.reject(div_attrs, fn {k, _v} -> to_string(k) == "class" end)

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
        :selected_option_class,
        :active_option_class,
        :container_class,
        :clear_button_extra_class,
        :tag_class,
        :clear_tag_button_extra_class,
        :tags_container_extra_class,
        :keep_label_on_select
      ])

    dropdown_class =
      if mode == :single do
        "absolute top-full mt-1 w-full rounded-md border border-primary-alt bg-primary shadow-lg z-50 max-h-60 overflow-y-auto flex flex-col"
      else
        "absolute top-11 mt-1 w-full rounded-md border border-primary-alt bg-primary shadow-lg z-50 max-h-60 overflow-y-auto flex flex-col"
      end

    live_select_attrs =
      if Keyword.has_key?(live_select_attrs, :value_mapper) do
        live_select_attrs
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
      |> assign(:hook_wrapper_id, hook_wrapper_id)
      |> assign(:dropdown_class, dropdown_class)
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
      <div class={["mb-2", @custom_class]} {@div_attrs}>
        <label for={@id || @safe_field.id} class="relative block">
          <div id={@hook_wrapper_id}>
            <LiveSelect.live_select
              field={@safe_field}
              id={@safe_field.id}
              mode={@mode}
              options={@options}
              text_input_class={[
                @class ||
                  "input-floating-control block w-full min-h-11 px-3 rounded-md border border-primary-alt bg-primary text-content focus:outline-none focus:border-brand focus:ring-2 focus:ring-brand disabled:text-subcontent disabled:cursor-not-allowed disabled:bg-primary-alt",
                @errors != [] &&
                  (@error_class || "border-error focus:border-error focus:ring-error")
              ]}
              text_input_selected_class=""
              dropdown_class={@dropdown_class}
              option_class="cursor-pointer select-none relative py-2 px-3 text-content hover:bg-primary-alt"
              selected_option_class="cursor-pointer select-none relative py-2 px-3 text-content bg-primary-alt font-semibold hover:bg-primary-alt order-first"
              active_option_class="bg-primary-alt"
              container_class={@container_class}
              clear_button_extra_class="right-9! top-1/2! -translate-y-1/2! flex items-center cursor-pointer text-error hover:text-error-alt"
              tag_class="mr-1 mt-1 p-1.5 text-sm rounded-lg border border-primary-alt bg-primary-alt flex items-center gap-1"
              clear_tag_button_extra_class="text-error hover:text-error-alt cursor-pointer"
              tags_container_extra_class="order-last flex flex-wrap"
              placeholder={@placeholder}
              keep_label_on_select
              allow_clear
              {@live_select_opts}
            />
          </div>
          <span class={[
            "input-floating-label",
            !@label_as_placeholder && "input-floating-label-hidden",
            @errors != [] && "input-floating-label-error"
          ]}>
            {@label}
          </span>
        </label>
        <.error :for={msg <- @errors}>{msg}</.error>
      </div>
      """
    else
      ~H"""
      <div class={["mb-2", @custom_class]} {@div_attrs}>
        <label for={@id || @safe_field.id} class="block">
          <div id={@hook_wrapper_id}>
            <LiveSelect.live_select
              field={@safe_field}
              id={@safe_field.id}
              mode={@mode}
              options={@options}
              text_input_class={[
                @class ||
                  "block w-full min-h-11 px-3 py-2 rounded-md border border-primary-alt bg-primary text-content focus:outline-none focus:border-brand focus:ring-2 focus:ring-brand disabled:text-subcontent disabled:cursor-not-allowed disabled:bg-primary-alt",
                @errors != [] &&
                  (@error_class || "border-error focus:border-error focus:ring-error")
              ]}
              text_input_selected_class=""
              dropdown_class={@dropdown_class}
              option_class="cursor-pointer select-none relative py-2 px-3 text-content hover:bg-primary-alt"
              selected_option_class="cursor-pointer select-none relative py-2 px-3 text-content bg-primary-alt font-semibold hover:bg-primary-alt order-first"
              active_option_class="bg-primary-alt"
              container_class="relative flex flex-col w-full"
              clear_button_extra_class="right-9! top-1/2! -translate-y-1/2! flex items-center cursor-pointer text-error hover:text-error-alt"
              tag_class="mr-1 mt-1 p-1.5 text-sm rounded-lg border border-primary-alt bg-primary-alt flex items-center gap-1"
              clear_tag_button_extra_class="text-error hover:text-error-alt cursor-pointer"
              tags_container_extra_class="order-last flex flex-wrap"
              placeholder={@prompt}
              keep_label_on_select
              allow_clear
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
      <div class="mb-2">
        <label for={@id} class="relative block">
          <textarea
            id={@id}
            name={@name}
            placeholder={@placeholder}
            class={[
              @class ||
                "input-floating-control input-floating-textarea block w-full px-3 rounded-md border border-primary-alt bg-primary text-content focus:outline-none focus:border-brand focus:ring-2 focus:ring-brand disabled:text-subcontent disabled:cursor-not-allowed disabled:bg-primary-alt",
              @errors != [] && (@error_class || "border-error focus:border-error focus:ring-error")
            ]}
            {@rest}
          >{Phoenix.HTML.Form.normalize_value("textarea", @value)}</textarea>
          <span class={[
            "input-floating-label",
            !@label_as_placeholder && "input-floating-label-hidden",
            @errors != [] && "input-floating-label-error"
          ]}>
            {@label}
          </span>
        </label>
        <.error :for={msg <- @errors}>{msg}</.error>
      </div>
      """
    else
      ~H"""
      <div class="mb-2">
        <label for={@id} class="block">
          <textarea
            id={@id}
            name={@name}
            class={[
              @class ||
                "block w-full px-3 py-2 rounded-md border border-primary-alt bg-primary text-content focus:outline-none focus:border-brand focus:ring-2 focus:ring-brand disabled:text-subcontent disabled:cursor-not-allowed disabled:bg-primary-alt",
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
    <div class="mb-2">
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
        <input type="hidden" name={@name} value={@composite_value} data-tel-composite />
        <div class="input-floating-wrapper grid grid-cols-[4rem_auto] gap-0">
          <LiveSelect.live_select
            field={@country_field}
            id={"#{@country_id}_country_select"}
            mode={:single}
            options={@country_options}
            value={@country_field.value}
            text_input_class={[
              "block w-full min-h-11 px-3 rounded-l-md border border-r-0 border-primary-alt bg-primary text-content focus:outline-none focus:border-brand focus:border-r-1 focus:ring-2 focus:ring-brand !bg-none !p-2"
            ]}
            text_input_selected_class=""
            dropdown_class="absolute top-full left-0 mt-1 w-72 rounded-md border border-primary-alt bg-primary shadow-lg z-50 max-h-60 overflow-y-auto flex flex-col"
            option_class="cursor-pointer select-none relative py-2 px-3 text-content hover:bg-primary-alt"
            selected_option_class="cursor-pointer select-none relative py-2 px-3 text-content bg-primary-alt font-semibold hover:bg-primary-alt order-first"
            active_option_class="bg-primary-alt"
            container_class="relative flex flex-col w-full"
            clear_button_extra_class="right-9! top-1/2! -translate-y-1/2! flex items-center cursor-pointer text-error hover:text-error-alt"
            placeholder="+60"
            keep_label_on_select
            keep_options_on_select
          />
          <input
            type="tel"
            id={@id}
            value={@number_value}
            placeholder={@placeholder}
            data-tel-number
            class={[
              @class ||
                "input-floating-control block w-full min-h-11 px-3 rounded-r-md border border-primary-alt bg-primary text-content focus:outline-none focus:border-brand focus:ring-2 focus:ring-brand disabled:text-subcontent disabled:cursor-not-allowed disabled:bg-primary-alt",
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
          {@label}
        </label>
      </div>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  # All other inputs text, datetime-local, url, password, etc. are handled here...
  def input(assigns) do
    assigns = assign(assigns, :rest, Map.put_new(assigns.rest, :"phx-debounce", "blur"))

    if assigns[:label] && assigns.type in ~w(color email file number password search text url) do
      placeholder = assigns.rest[:placeholder]
      label_as_placeholder = placeholder in [nil, ""]

      assigns =
        assigns
        |> assign(:rest, Map.delete(assigns.rest, :placeholder))
        |> assign(:placeholder, if(label_as_placeholder, do: " ", else: placeholder))
        |> assign(:label_as_placeholder, label_as_placeholder)

      ~H"""
      <div class="mb-2">
        <label for={@id} class="relative block">
          <input
            type={@type}
            name={@name}
            id={@id}
            value={Phoenix.HTML.Form.normalize_value(@type, @value)}
            placeholder={@placeholder}
            class={[
              @class ||
                "input-floating-control block w-full min-h-11 px-3 rounded-md border border-primary-alt bg-primary text-content focus:outline-none focus:border-brand focus:ring-2 focus:ring-brand disabled:text-subcontent disabled:cursor-not-allowed disabled:bg-primary-alt",
              @errors != [] && (@error_class || "border-error focus:border-error focus:ring-error")
            ]}
            {@rest}
          />
          <span class={[
            "input-floating-label",
            !@label_as_placeholder && "input-floating-label-hidden",
            @errors != [] && "input-floating-label-error"
          ]}>
            {@label}
          </span>
        </label>
        <.error :for={msg <- @errors}>{msg}</.error>
      </div>
      """
    else
      ~H"""
      <div class="mb-2">
        <label for={@id} class="block">
          <span :if={@label} class="block text-sm font-medium text-content mb-1">{@label}</span>
          <input
            type={@type}
            name={@name}
            id={@id}
            value={Phoenix.HTML.Form.normalize_value(@type, @value)}
            class={[
              @class ||
                "block w-full min-h-11 px-3 py-2 rounded-md border border-primary-alt bg-primary text-content focus:outline-none focus:border-brand focus:ring-2 focus:ring-brand disabled:text-subcontent disabled:cursor-not-allowed disabled:bg-primary-alt",
              @errors != [] && (@error_class || "border-error focus:border-error focus:ring-error")
            ]}
            {@rest}
          />
        </label>
        <.error :for={msg <- @errors}>{msg}</.error>
      </div>
      """
    end
  end

  defp vcalendar_input(assigns) do
    if assigns[:label] do
      placeholder = assigns.rest[:placeholder]
      label_as_placeholder = placeholder in [nil, ""]

      assigns =
        assigns
        |> assign(:rest, Map.delete(assigns.rest, :placeholder))
        |> assign(:placeholder, if(label_as_placeholder, do: " ", else: placeholder))
        |> assign(:label_as_placeholder, label_as_placeholder)

      ~H"""
      <div class="mb-2">
        <div class="relative block">
          <input
            type="text"
            name={@name}
            id={@id}
            value={Phoenix.HTML.Form.normalize_value("text", @value)}
            placeholder={@placeholder}
            data-vc-mode={@type}
            phx-hook="VCalendar"
            phx-update="ignore"
            readonly
            class={[
              @class ||
                "input-floating-control block w-full min-h-11 px-3 rounded-md border border-primary-alt bg-primary text-content focus:outline-none focus:border-brand focus:ring-2 focus:ring-brand disabled:text-subcontent disabled:cursor-not-allowed disabled:bg-primary-alt",
              @errors != [] && (@error_class || "border-error focus:border-error focus:ring-error")
            ]}
            {@rest}
          />
          <span class={[
            "input-floating-label",
            !@label_as_placeholder && "input-floating-label-hidden",
            @errors != [] && "input-floating-label-error"
          ]}>
            {@label}
          </span>
        </div>
        <.error :for={msg <- @errors}>{msg}</.error>
      </div>
      """
    else
      ~H"""
      <div class="mb-2">
        <input
          type="text"
          name={@name}
          id={@id}
          value={Phoenix.HTML.Form.normalize_value("text", @value)}
          data-vc-mode={@type}
          phx-hook="VCalendar"
          phx-update="ignore"
          readonly
          class={[
            @class ||
              "block w-full min-h-11 px-3 py-2 rounded-md border border-primary-alt bg-primary text-content focus:outline-none focus:border-brand focus:ring-2 focus:ring-brand disabled:text-subcontent disabled:cursor-not-allowed disabled:bg-primary-alt",
            @errors != [] && (@error_class || "border-error focus:border-error focus:ring-error")
          ]}
          {@rest}
        />
        <.error :for={msg <- @errors}>{msg}</.error>
      </div>
      """
    end
  end

  defp option_display_label(value, _options) when value in [nil, ""], do: ""

  defp option_display_label(value, options) do
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
  Renders a header with title.
  """
  slot :inner_block, required: true
  slot :subtitle
  slot :actions

  def header(assigns) do
    ~H"""
    <header class={[@actions != [] && "flex items-center justify-between gap-6", "pb-4"]}>
      <div>
        <h1 class="text-lg font-semibold leading-8">
          {render_slot(@inner_block)}
        </h1>
        <p :if={@subtitle != []} class="text-sm text-subcontent">
          {render_slot(@subtitle)}
        </p>
      </div>
      <div class="flex-none">{render_slot(@actions)}</div>
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
    <table class="w-full text-left [&_tbody_tr:nth-child(even)]:bg-primary-alt">
      <thead>
        <tr>
          <th :for={col <- @col} class="px-3 py-2 font-semibold">{col[:label]}</th>
          <th :if={@action != []} class="px-3 py-2">
            <span class="sr-only">{gettext("Actions")}</span>
          </th>
        </tr>
      </thead>
      <tbody id={@id} phx-update={is_struct(@rows, Phoenix.LiveView.LiveStream) && "stream"}>
        <tr :for={row <- @rows} id={@row_id && @row_id.(row)}>
          <td
            :for={col <- @col}
            phx-click={@row_click && @row_click.(row)}
            class={["px-3 py-2", @row_click && "hover:cursor-pointer"]}
          >
            {render_slot(col, @row_item.(row))}
          </td>
          <td :if={@action != []} class="px-3 py-2 w-0 font-semibold">
            <div class="flex gap-4">
              <%= for action <- @action do %>
                {render_slot(action, @row_item.(row))}
              <% end %>
            </div>
          </td>
        </tr>
      </tbody>
    </table>
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
    <ul class="flex flex-col divide-y divide-primary-alt">
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
  Renders a [Heroicon](https://heroicons.com).

  Heroicons come in three styles – outline, solid, and mini.
  By default, the outline style is used, but solid and mini may
  be applied by using the `-solid` and `-mini` suffix.

  You can customize the size and colors of the icons by setting
  width, height, and background color classes.

  Icons are extracted from the `deps/heroicons` directory and bundled within
  your compiled app.css by the plugin in `assets/vendor/heroicons.js`.

  ## Examples

      <.icon name="hero-x-mark" />
      <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
  """
  attr :name, :string, required: true
  attr :class, :any, default: "size-4"

  def icon(%{name: "hero-" <> _} = assigns) do
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
    # When using gettext, we typically pass the strings we want
    # to translate as a static argument:
    #
    #     # Translate the number of files with plural rules
    #     dngettext("errors", "1 file", "%{count} files", count)
    #
    # However the error messages in our forms and APIs are generated
    # dynamically, so we need to translate them by calling Gettext
    # with our gettext backend as first argument. Translations are
    # available in the errors.po file (as we use the "errors" domain).
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

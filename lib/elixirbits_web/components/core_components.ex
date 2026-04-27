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
  attr :kind, :atom, values: [:info, :error], doc: "used for styling and flash lookup"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the flash container"

  slot :inner_block, doc: "the optional inner block that renders the flash message"

  def flash(assigns) do
    assigns = assign_new(assigns, :id, fn -> "flash-#{assigns.kind}" end)

    ~H"""
    <div
      :if={msg = render_slot(@inner_block) || Phoenix.Flash.get(@flash, @kind)}
      id={@id}
      phx-click={JS.push("lv:clear-flash", value: %{key: @kind}) |> hide("##{@id}")}
      role="alert"
      class="fixed top-4 right-4 z-50 flex flex-col gap-2"
      {@rest}
    >
      <div class={[
        "flex items-start gap-3 p-4 rounded-md border w-80 sm:w-96 max-w-80 sm:max-w-96 text-wrap shadow-sm",
        @kind == :info && "bg-info/10 border-info/30 text-info",
        @kind == :error && "bg-error/10 border-error/30 text-error"
      ]}>
        <.icon :if={@kind == :info} name="hero-information-circle" class="size-5 shrink-0" />
        <.icon :if={@kind == :error} name="hero-exclamation-circle" class="size-5 shrink-0" />
        <div>
          <p :if={@title} class="font-semibold">{@title}</p>
          <p>{msg}</p>
        </div>
        <div class="flex-1" />
        <button type="button" class="group self-start cursor-pointer" aria-label={gettext("close")}>
          <.icon name="hero-x-mark" class="size-5 opacity-40 group-hover:opacity-70" />
        </button>
      </div>
    </div>
    """
  end

  @doc """
  Renders a button with navigation support.

  ## Examples

      <.button>Send!</.button>
      <.button phx-click="go" variant="primary">Send!</.button>
      <.button navigate={~p"/"}>Home</.button>
  """
  attr :rest, :global, include: ~w(href navigate patch method download name value disabled)
  attr :class, :any, default: nil
  attr :variant, :string, default: nil
  attr :size, :string, default: nil
  slot :inner_block, required: true

  def button(%{rest: rest} = assigns) do
    base =
      "inline-flex items-center justify-center rounded-md font-medium transition-colors focus:outline-none focus:ring-2 focus:ring-accent/40 disabled:opacity-50 disabled:pointer-events-none"

    sizes = %{
      nil => "px-4 py-2 text-sm",
      "sm" => "px-3 py-1.5 text-sm",
      "xs" => "px-2 py-1 text-xs"
    }

    variants = %{
      nil => "bg-primary/15 text-primary hover:bg-primary/25",
      "primary" => "bg-primary text-primary-content hover:bg-primary/90",
      "soft" => "bg-primary/15 text-primary hover:bg-primary/25",
      "ghost" => "bg-transparent text-base-content hover:bg-base-200",
      "error" => "bg-error text-error-content hover:bg-error/90"
    }

    assigns =
      assign(assigns, :class, [
        base,
        Map.fetch!(sizes, assigns[:size]),
        Map.fetch!(variants, assigns[:variant]),
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
          "cursor-pointer flex items-center justify-between w-full min-h-11 px-3 rounded-md border border-base-300 bg-base-100 text-base-content focus-within:border-accent focus-within:ring-2 focus-within:ring-accent/20",
          "has-[:disabled]:opacity-50 has-[:disabled]:cursor-not-allowed has-[:disabled]:bg-base-200",
          @errors != [] &&
            (@error_class || "border-error focus-within:border-error focus-within:ring-error/20")
        ]}
      >
        <span class="flex items-center gap-2 text-sm font-medium text-base-content">
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
                "appearance-none h-5 w-5 shrink-0 rounded border border-base-300 bg-base-200 checked:bg-primary checked:border-primary focus:ring-0 focus:outline-none disabled:cursor-not-allowed checked:bg-[url('data:image/svg+xml,%3csvg%20viewBox=%220%200%2016%2016%22%20fill=%22white%22%20xmlns=%22http://www.w3.org/2000/svg%22%3e%3cpath%20d=%22M12.207%204.793a1%201%200%20010%201.414l-5%205a1%201%200%2001-1.414%200l-2-2a1%201%200%20011.414-1.414L6.5%209.086l4.293-4.293a1%201%200%20011.414%200z%22/%3e%3c/svg%3e')] bg-center bg-no-repeat bg-[length:100%_100%]"
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
          "cursor-pointer flex items-center justify-between w-full min-h-11 px-3 rounded-md border border-base-300 bg-base-100 text-base-content focus-within:border-accent focus-within:ring-2 focus-within:ring-accent/20",
          "has-[:disabled]:opacity-50 has-[:disabled]:cursor-not-allowed has-[:disabled]:bg-base-200",
          @errors != [] &&
            (@error_class || "border-error focus-within:border-error focus-within:ring-error/20")
        ]}
      >
        <span class="flex items-center gap-2 text-sm font-medium text-base-content">
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
                "peer appearance-none shrink-0 w-11 h-6 rounded-full border border-base-300 bg-base-200 checked:bg-primary checked:border-primary focus:outline-none focus:ring-0 disabled:cursor-not-allowed transition-colors duration-200 ease-in-out relative before:absolute before:top-[1px] before:left-[1px] before:h-5 before:w-5 before:rounded-full before:bg-base-content/40 checked:before:translate-x-5 checked:before:bg-base-100 before:transition-transform before:duration-200 before:ease-in-out"
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
        "absolute top-full mt-1 w-full rounded-md border border-base-300 bg-base-100 shadow-lg z-50 max-h-60 overflow-y-auto flex flex-col"
      else
        "absolute top-11 mt-1 w-full rounded-md border border-base-300 bg-base-100 shadow-lg z-50 max-h-60 overflow-y-auto flex flex-col"
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
                  "input-floating-control block w-full min-h-11 px-3 rounded-md border border-base-300 bg-base-100 text-base-content focus:outline-none focus:border-accent focus:ring-2 focus:ring-accent/20 disabled:opacity-50 disabled:cursor-not-allowed disabled:bg-base-200",
                @errors != [] &&
                  (@error_class || "border-error focus:border-error focus:ring-error/20")
              ]}
              text_input_selected_class=""
              dropdown_class={@dropdown_class}
              option_class="cursor-pointer select-none relative py-2 px-3 text-base-content hover:bg-base-200"
              selected_option_class="cursor-pointer select-none relative py-2 px-3 text-base-content bg-base-200 font-semibold hover:bg-base-300 order-first"
              active_option_class="bg-base-200"
              container_class={@container_class}
              clear_button_extra_class="absolute right-2 top-1/2 -translate-y-1/2 flex items-center cursor-pointer text-error hover:text-error/80"
              tag_class="mr-1 mt-1 p-1.5 text-sm rounded-lg border border-base-300 bg-base-200 flex items-center gap-1"
              clear_tag_button_extra_class="text-error hover:text-error/80 cursor-pointer"
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
                  "block w-full min-h-11 px-3 py-2 rounded-md border border-base-300 bg-base-100 text-base-content focus:outline-none focus:border-accent focus:ring-2 focus:ring-accent/20 disabled:opacity-50 disabled:cursor-not-allowed disabled:bg-base-200",
                @errors != [] &&
                  (@error_class || "border-error focus:border-error focus:ring-error/20")
              ]}
              text_input_selected_class=""
              dropdown_class={@dropdown_class}
              option_class="cursor-pointer select-none relative py-2 px-3 text-base-content hover:bg-base-200"
              selected_option_class="cursor-pointer select-none relative py-2 px-3 text-base-content bg-base-200 font-semibold hover:bg-base-300 order-first"
              active_option_class="bg-base-200"
              container_class="relative flex flex-col w-full"
              clear_button_extra_class="absolute right-2 top-1/2 -translate-y-1/2 flex items-center cursor-pointer text-error hover:text-error/80"
              tag_class="mr-1 mt-1 p-1.5 text-sm rounded-lg border border-base-300 bg-base-200 flex items-center gap-1"
              clear_tag_button_extra_class="text-error hover:text-error/80 cursor-pointer"
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
                "input-floating-control input-floating-textarea block w-full px-3 rounded-md border border-base-300 bg-base-100 text-base-content focus:outline-none focus:border-accent focus:ring-2 focus:ring-accent/20 disabled:opacity-50 disabled:cursor-not-allowed disabled:bg-base-200",
              @errors != [] && (@error_class || "border-error focus:border-error focus:ring-error/20")
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
                "block w-full px-3 py-2 rounded-md border border-base-300 bg-base-100 text-base-content focus:outline-none focus:border-accent focus:ring-2 focus:ring-accent/20 disabled:opacity-50 disabled:cursor-not-allowed disabled:bg-base-200",
              @errors != [] && (@error_class || "border-error focus:border-error focus:ring-error/20")
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

  # All other inputs text, datetime-local, url, password, etc. are handled here...
  def input(assigns) do
    if assigns[:label] && assigns.type in ~w(email number password search tel text url) do
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
                "input-floating-control block w-full min-h-11 px-3 rounded-md border border-base-300 bg-base-100 text-base-content focus:outline-none focus:border-accent focus:ring-2 focus:ring-accent/20 disabled:opacity-50 disabled:cursor-not-allowed disabled:bg-base-200",
              @errors != [] && (@error_class || "border-error focus:border-error focus:ring-error/20")
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
          <span :if={@label} class="block text-sm font-medium text-base-content mb-1">{@label}</span>
          <input
            type={@type}
            name={@name}
            id={@id}
            value={Phoenix.HTML.Form.normalize_value(@type, @value)}
            class={[
              @class ||
                "block w-full min-h-11 px-3 py-2 rounded-md border border-base-300 bg-base-100 text-base-content focus:outline-none focus:border-accent focus:ring-2 focus:ring-accent/20 disabled:opacity-50 disabled:cursor-not-allowed disabled:bg-base-200",
              @errors != [] && (@error_class || "border-error focus:border-error focus:ring-error/20")
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
            phx-hook=".VCalendar"
            phx-update="ignore"
            autocomplete="off"
            readonly
            class={[
              @class ||
                "input-floating-control block w-full min-h-11 px-3 rounded-md border border-base-300 bg-base-100 text-base-content focus:outline-none focus:border-accent focus:ring-2 focus:ring-accent/20 disabled:opacity-50 disabled:cursor-not-allowed disabled:bg-base-200",
              @errors != [] && (@error_class || "border-error focus:border-error focus:ring-error/20")
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
      <script :type={Phoenix.LiveView.ColocatedHook} name=".VCalendar">
        import {Calendar} from "vanilla-calendar-pro"

        const pad = (n) => String(n).padStart(2, "0")

        const parseInitial = (mode, value) => {
          if (!value) return {dates: [], time: ""}
          if (mode === "date") {
            return /^\d{4}-\d{2}-\d{2}$/.test(value) ? {dates: [value], time: ""} : {dates: [], time: ""}
          }
          if (mode === "datetime-local") {
            const m = value.match(/^(\d{4}-\d{2}-\d{2})[T ](\d{2}:\d{2})/)
            return m ? {dates: [m[1]], time: m[2]} : {dates: [], time: ""}
          }
          if (mode === "time") {
            return /^\d{2}:\d{2}$/.test(value) ? {dates: [], time: value} : {dates: [], time: ""}
          }
          if (mode === "week") {
            const m = value.match(/^(\d{4})-W(\d{2})$/)
            if (!m) return {dates: [], time: ""}
            const year = parseInt(m[1], 10)
            const week = parseInt(m[2], 10)
            const simple = new Date(Date.UTC(year, 0, 1 + (week - 1) * 7))
            const dow = simple.getUTCDay()
            const monday = new Date(simple)
            monday.setUTCDate(simple.getUTCDate() - ((dow + 6) % 7))
            const iso = `${monday.getUTCFullYear()}-${pad(monday.getUTCMonth() + 1)}-${pad(monday.getUTCDate())}`
            return {dates: [iso], time: ""}
          }
          if (mode === "month") {
            const m = value.match(/^(\d{4})-(\d{2})$/)
            return m ? {year: parseInt(m[1], 10), month: parseInt(m[2], 10) - 1} : {}
          }
          return {dates: [], time: ""}
        }

        const setValue = (input, value) => {
          input.value = value
          input.dispatchEvent(new Event("input", {bubbles: true}))
          input.dispatchEvent(new Event("change", {bubbles: true}))
        }

        if (typeof HTMLElement !== "undefined" && !HTMLElement.prototype._vcFocusPatched) {
          HTMLElement.prototype._vcFocusPatched = true
          const origFocus = HTMLElement.prototype.focus
          HTMLElement.prototype.focus = function(opts) {
            if (this.closest && this.closest("[data-vc=calendar]")) {
              return origFocus.call(this, { ...(opts || {}), preventScroll: true })
            }
            return origFocus.call(this, opts)
          }
        }

        export default {
          mounted() {
            const input = this.el
            const mode = input.dataset.vcMode
            const initial = parseInitial(mode, input.value)

            const markMode = (self) => {
              const main = self?.context?.mainElement
              if (main && main instanceof HTMLElement) {
                main.setAttribute("data-vc-mode", mode)
                main.classList.add(`vc-mode-${mode}`)
                const w = input.offsetWidth
                if (w > 0) {
                  main.style.minWidth = `${w}px`
                  main.style.width = `${w}px`
                }
              }
            }

            const base = {
              inputMode: true,
              openOnFocus: false,
              positionToInput: ["bottom", "left"],
              onInit: markMode,
              onShow: markMode,
              onUpdate: markMode,
            }

            const opts =
              mode === "date" ? {
                ...base,
                type: "default",
                selectionDatesMode: "single",
                selectedDates: initial.dates,
                onClickDate: (self) => {
                  const [d] = self.context.selectedDates
                  if (d) setValue(input, d)
                  self.hide()
                },
              }
              : mode === "datetime-local" ? {
                ...base,
                type: "default",
                selectionDatesMode: "single",
                selectionTimeMode: 24,
                selectedDates: initial.dates,
                selectedTime: initial.time || "00:00",
                onClickDate: (self) => {
                  const [d] = self.context.selectedDates
                  const t = self.context.selectedTime || "00:00"
                  if (d) setValue(input, `${d}T${t}`)
                },
                onChangeTime: (self) => {
                  const [d] = self.context.selectedDates
                  const t = self.context.selectedTime || "00:00"
                  if (d) setValue(input, `${d}T${t}`)
                },
              }
              : mode === "time" ? {
                ...base,
                type: "default",
                selectionDatesMode: false,
                selectionMonthsMode: false,
                selectionYearsMode: false,
                selectionTimeMode: 24,
                selectedTime: initial.time || "00:00",
                onChangeTime: (self) => {
                  setValue(input, self.context.selectedTime || "00:00")
                },
              }
              : mode === "week" ? {
                ...base,
                type: "default",
                selectionDatesMode: false,
                enableWeekNumbers: true,
                selectedDates: initial.dates,
                onClickWeekNumber: (self, weekNumber, year) => {
                  setValue(input, `${year}-W${pad(weekNumber)}`)
                  self.hide()
                },
              }
              : {
                ...base,
                type: "month",
                selectionDatesMode: false,
                selectionMonthsMode: true,
                selectedYear: initial.year,
                selectedMonth: initial.month,
                onClickMonth: (self) => {
                  const y = self.context.selectedYear
                  const m = self.context.selectedMonth
                  if (y != null && m != null) setValue(input, `${y}-${pad(m + 1)}`)
                  self.hide()
                },
              }

            this.calendar = new Calendar(input, opts)
            this.calendar.init()
          },
          destroyed() {
            this.calendar?.destroy()
          },
        }
      </script>
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
          phx-hook=".VCalendar"
          phx-update="ignore"
          autocomplete="off"
          readonly
          class={[
            @class ||
              "block w-full min-h-11 px-3 py-2 rounded-md border border-base-300 bg-base-100 text-base-content focus:outline-none focus:border-accent focus:ring-2 focus:ring-accent/20 disabled:opacity-50 disabled:cursor-not-allowed disabled:bg-base-200",
            @errors != [] && (@error_class || "border-error focus:border-error focus:ring-error/20")
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
        <p :if={@subtitle != []} class="text-sm text-base-content/70">
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
    <table class="w-full text-left [&_tbody_tr:nth-child(even)]:bg-base-200">
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
    <ul class="flex flex-col divide-y divide-base-300">
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
        {"transition-all ease-out duration-300",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95",
         "opacity-100 translate-y-0 sm:scale-100"}
    )
  end

  def hide(js \\ %JS{}, selector) do
    JS.hide(js,
      to: selector,
      time: 200,
      transition:
        {"transition-all ease-in duration-200", "opacity-100 translate-y-0 sm:scale-100",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"}
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

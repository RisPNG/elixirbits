This is a web application written using the Phoenix web framework. The following is a general rule you have to follow, it may not apply at all times and choose the correct guidelines depending on the instructions.

## Project guidelines

- Use the already included and available `:req` (`Req`) library for HTTP requests, **avoid** `:httpoison`, `:tesla`, and `:httpc`. Req is included by default and is the preferred HTTP client for Phoenix apps.

### Phoenix > v1.8 guidelines

- **Always** begin your LiveView templates with `<Layouts.app flash={@flash} ...>` which wraps all inner content.
- The `MyAppWeb.Layouts` module is aliased in the `my_app_web.ex` file, so you can use it without needing to alias it again.
- Anytime you run into errors with no `current_scope` assign:
  - You failed to follow the Authenticated Routes guidelines, or you failed to pass `current_scope` to `<Layouts.app>`.
  - **Always** fix the `current_scope` error by moving your routes to the proper `live_session` and ensure you pass `current_scope` as needed.
- Phoenix v1.8 moved the `<.flash_group>` component to the `Layouts` module. You are **forbidden** from calling `<.flash_group>` outside of the `layouts.ex` module.
- Out of the box, `core_components.ex` imports an `<.icon name="hero-x-mark" class="w-5 h-5"/>` component for hero icons. **Always** use the `<.icon>` component for icons, **never** use `Heroicons` modules or similar.
- **Always** use the imported `<.input>` component for form inputs from `core_components.ex` when available. `<.input>` is imported and using it will save steps and prevent errors.
- If you override the default input classes (`<.input class="myclass px-2 py-1 rounded-lg">)`) class with your own values, no default classes are inherited, so your custom classes must fully style the input.

### JS and CSS guidelines

- **Use Tailwind CSS classes and custom CSS rules** to create and build interfaces.
- Tailwindcss v4 **no longer needs a tailwind.config.js** and uses a new import syntax in `app.css`:
  ```elixir
    @import "tailwindcss" source(none);
    @source "../css";
    @source "../js";
    @source "../../lib/my_app_web";
  ```
- **Always use and maintain this import syntax** in the app.css file for projects generated with `phx.new`.
- **Never** use `@apply` when writing raw css.
- **Always** manually write your own tailwind-based components instead of using daisyUI for a unique, world-class design.
- Out of the box **only the app.js and app.css bundles are supported**.
  - You cannot reference an external vendor'd script `src` or link `href` in the layouts.
  - You must import the vendor deps into app.js and app.css to use them which means you **never write inline <script>custom js</script> tags** as well as **inline styles**.
## Elixir guidelines

- Elixir lists **do not support index based access via the access syntax**:
  """
    **Never do this (invalid)**:
      ```elixir
        i = 0
        mylist = ["blue", "green"]
        mylist[i]
      ```
    Instead, **always** use `Enum.at`, pattern matching, or `List` for index based list access, e.g.:
      ```elixir
        i = 0
        mylist = ["blue", "green"]
        Enum.at(mylist, i)
      ```
  """
- Elixir variables are immutable, but can be rebound, so for block expressions like `if`, `case`, `cond`, etc.. you *must* bind the result of the expression to a variable if you want to use it and you CANNOT rebind the result inside the expression, e.g.:
  """
    # INVALID - we are rebinding inside the `if` and the result never gets assigned:
      ```elixir
        if connected?(socket) do
          socket = assign(socket, :val, val)
        end
      ```

    # VALID - we rebind the result of the `if` to a new variable:
      ```elixir
        socket =
          if connected?(socket) do
            assign(socket, :val, val)
          end
      ```
  """
- **Never** nest multiple modules in the same file as it can cause cyclic dependencies and compilation errors.
- **Never** use map access syntax (`changeset[:field]`) on structs as they do not implement the Access behaviour by default. For regular structs, you **must** access the fields directly, such as `my_struct.field` or use higher level APIs that are available on the struct if they exist, `Ecto.Changeset.get_field/2` for changesets.
- Elixir's standard library has everything necessary for date and time manipulation. Familiarize yourself with the common `Time`, `Date`, `DateTime`, `ex_cldr`, and any other installed dependency interfaces by accessing their documentation as necessary. **Never** install additional dependencies unless asked for or there's no other reasonable choice.
- Don't use `String.to_atom/1` on user input (memory leak risk).
- Predicate function names should not start with `is_` and should end in a question mark. Names like `is_thing` should be reserved for guards.
- Elixir's builtin OTP primitives like `DynamicSupervisor` and `Registry`, require names in the child spec, such as `{DynamicSupervisor, name: MyApp.MyDynamicSup}`, then you can use `DynamicSupervisor.start_child(MyApp.MyDynamicSup, child_spec)`.
- Use `Task.async_stream(collection, callback, options)` for concurrent enumeration with back-pressure. The majority of times you will want to pass `timeout: :infinity` as option.

## Mix guidelines

- Read the docs and options before using tasks (by using `mix help task_name`).
- To debug test failures, run tests in a specific file with `mix test test/my_test.exs` or run all previously failed tests with `mix test --failed`.
- `mix deps.clean --all` is **almost never needed**. **Avoid** using it unless you have good reason.

## Test guidelines

- **Always use `start_supervised!/1`** to start processes in tests as it guarantees cleanup between tests.
- **Avoid** `Process.sleep/1` and `Process.alive?/1` in tests:
  - Instead of sleeping to wait for a process to finish, **always** use `Process.monitor/1` and assert on the DOWN message:
    ```elixir
      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}
    ```
   - Instead of sleeping to synchronize before the next call, **always** use `_ = :sys.get_state/1` to ensure the process has handled prior messages.
## Phoenix guidelines

- Remember Phoenix router `scope` blocks include an optional alias which is prefixed for all routes within the scope. **Always** be mindful of this when creating routes within a scope to avoid duplicate module prefixes.
- You **never** need to create your own `alias` for route definitions! The `scope` provides the alias, e.g.:
  ```elixir
    scope "/admin", AppWeb.Admin do
      pipe_through :browser

      live "/users", UserLive, :index
    end
  ```
  the UserLive route would point to the `AppWeb.Admin.UserLive` module.
- `Phoenix.View` no longer is needed or included with Phoenix, don't use it

## Phoenix HTML guidelines

- Phoenix templates **always** use `~H` or .html.heex files (known as HEEx), **never** use `~E`.
- **Always** use the imported `Phoenix.Component.form/1` and `Phoenix.Component.inputs_for/1` function to build forms. **Never** use `Phoenix.HTML.form_for` or `Phoenix.HTML.inputs_for` as they are outdated.
- When building forms **always** use the already imported `Phoenix.Component.to_form/2` (`assign(socket, form: to_form(...))` and `<.form for={@form} id="msg-form">`), then access those forms in the template via `@form[:field]`.
- **Always** add unique DOM IDs to key elements (like forms, buttons, etc) when writing templates, these IDs can later be used in tests (`<.form for={@form} id="product-form">`).
- For "app wide" template imports, you can import/alias into the `my_app_web.ex`'s `html_helpers` block, so they will be available to all LiveViews, LiveComponent's, and all modules that do `use MyAppWeb, :html` (replace "my_app" by the actual app name).
- Elixir supports `if/else` but **does NOT support `if/else if` or `if/elsif`**. **Never use `else if` or `elseif` in Elixir**, **always** use `cond` or `case` for multiple conditionals:
  """
    **Never do this (invalid)**:
      ```elixir
        <%= if condition do %>
          ...
        <% else if other_condition %>
          ...
        <% end %>
      ```
    Instead **always** do this:
      ```elixir
        <%= cond do %>
          <% condition -> %>
            ...
          <% condition2 -> %>
            ...
          <% true -> %>
            ...
        <% end %>
      ```
  """
- HEEx require special tag annotation if you want to insert literal curly's like `{` or `}`. If you want to show a textual code snippet on the page in a `<pre>` or `<code>` block you *must* annotate the parent tag with `phx-no-curly-interpolation`:
  """
      ```elixir
        <code phx-no-curly-interpolation>
          let obj = {key: "val"}
        </code>
      ```
    Within `phx-no-curly-interpolation` annotated tags, you can use `{` and `}` without escaping them, and dynamic Elixir expressions can still be used with `<%= ... %>` syntax.
  """
- HEEx class attrs support lists, but you must **always** use list `[...]` syntax. You can use the class list syntax to conditionally add classes, **always do this for multiple class values**:
  """
      ```elixir
        <a class={[
          "px-2 text-white",
          @some_flag && "py-5",
          if(@other_condition, do: "border-red-500", else: "border-blue-100"),
          ...
        ]}>Text</a>
      ```
    and **always** wrap `if`'s inside `{...}` expressions with parens, like done above (`if(@other_condition, do: "...", else: "...")`).

    and **never** do this, since it's invalid (note the missing `[` and `]`):
      ```elixir
        <a class={
          "px-2 text-white",
          @some_flag && "py-5"
        }> ...
        => Raises compile syntax error on invalid HEEx attr syntax
      ```
  """
- **Never** use `<% Enum.each %>` or non-for comprehensions for generating template content, instead **always** use `<%= for item <- @collection do %>`.
- HEEx HTML comments use `<%!-- comment --%>`. **Always** use the HEEx HTML comment syntax for template comments (`<%!-- comment --%>`).
- HEEx allows interpolation via `{...}` and `<%= ... %>`, but the `<%= %>` **only** works within tag bodies. **Always** use the `{...}` syntax for interpolation within tag attributes, and for interpolation of values within tag bodies. **Always** interpolate block constructs (if, cond, case, for) within tag bodies using `<%= ... %>`:
  """
    **Always** do this:
      ```elixir
        <div id={@id}>
          {@my_assign}
          <%= if @some_block_condition do %>
            {@another_assign}
          <% end %>
        </div>
      ```
    and **Never** do this – the program will terminate with a syntax error:
      ```elixir
        <%!-- THIS IS INVALID NEVER EVER DO THIS --%>
        <div id="<%= @invalid_interpolation %>">
          {if @invalid_block_construct do}
          {end}
        </div>
      ```
  """
## Phoenix LiveView guidelines

- **Never** use the deprecated `live_redirect` and `live_patch` functions, instead **always** use the `<.link navigate={href}>` and  `<.link patch={href}>` in templates, and `push_navigate` and `push_patch` functions LiveViews.
- **Avoid LiveComponent's** unless you have a strong, specific need for them.
- LiveViews should be named like `AppWeb.WeatherLive`, with a `Live` suffix. When you go to add LiveView routes to the router, the default `:browser` scope is **already aliased** with the `AppWeb` module, so you can just do `live "/weather", WeatherLive`.

### LiveView streams

- **Always** use LiveView streams for collections for assigning regular lists to avoid memory ballooning and runtime termination with the following operations:
  - basic append of N items - `stream(socket, :messages, [new_msg])`
  - resetting stream with new items - `stream(socket, :messages, [new_msg], reset: true)` (e.g. for filtering items)
  - prepend to stream - `stream(socket, :messages, [new_msg], at: -1)`
  - deleting items - `stream_delete(socket, :messages, msg)`
- When using the `stream/3` interfaces in the LiveView, the LiveView template must 1) always set `phx-update="stream"` on the parent element, with a DOM id on the parent element like `id="messages"` and 2) consume the `@streams.stream_name` collection and use the id as the DOM id for each child. For a call like `stream(socket, :messages, [new_msg])` in the LiveView, the template would be:
  ```elixir
    <div id="messages" phx-update="stream">
      <div :for={{id, msg} <- @streams.messages} id={id}>
        {msg.text}
      </div>
    </div>
  ```
- LiveView streams are *not* enumerable, so you cannot use `Enum.filter/2` or `Enum.reject/2` on them. Instead, if you want to filter, prune, or refresh a list of items on the UI, you **must refetch the data and re-stream the entire stream collection, passing reset: true**:
  ```elixir
    def handle_event("filter", %{"filter" => filter}, socket) do
      # re-fetch the messages based on the filter
      messages = list_messages(filter)

      {:noreply,
        socket
        |> assign(:messages_empty?, messages == [])
        # reset the stream with the new messages
        |> stream(:messages, messages, reset: true)}
    end
  ```
- LiveView streams *do not support counting or empty states*. If you need to display a count, you must track it using a separate assign. For empty states, you can use Tailwind classes:
  """
    ```elixir
      <div id="tasks" phx-update="stream">
        <div class="hidden only:block">No tasks yet</div>
        <div :for={{id, task} <- @streams.tasks} id={id}>
          {task.name}
        </div>
      </div>
    ```
    The above only works if the empty state is the only HTML block alongside the stream for-comprehension.
  """
- When updating an assign that should change content inside any streamed item(s), you MUST re-stream the items along with the updated assign:
  """
    ```elixir
      def handle_event("edit_message", %{"message_id" => message_id}, socket) do
        message = Chat.get_message!(message_id)
        edit_form = to_form(Chat.change_message(message, %{content: message.content}))

        # re-insert message so @editing_message_id toggle logic takes effect for that stream item
        {:noreply,
          socket
          |> stream_insert(:messages, message)
          |> assign(:editing_message_id, String.to_integer(message_id))
          |> assign(:edit_form, edit_form)}
      end
    ```

    And in the template:
      ```elixir
        <div id="messages" phx-update="stream">
          <div :for={{id, message} <- @streams.messages} id={id} class="flex group">
            {message.username}
            <%= if @editing_message_id == message.id do %>
              <%!-- Edit mode --%>
              <.form for={@edit_form} id="edit-form-#{message.id}" phx-submit="save_edit">
                ...
              </.form>
            <% end %>
          </div>
        </div>
      ```
  """
- **Never** use the deprecated `phx-update="append"` or `phx-update="prepend"` for collections.

### LiveView JavaScript interop

- Remember anytime you use `phx-hook="MyHook"` and that JS hook manages its own DOM, you **must** also set the `phx-update="ignore"` attribute.
- **Always** provide an unique DOM id alongside `phx-hook` otherwise a compiler error will be raised:
  """
    LiveView hooks come in two flavors, 1) colocated js hooks for "inline" scripts defined inside HEEx,
    and 2) external `phx-hook` annotations where JavaScript object literals are defined and passed to the `LiveSocket` constructor.
  """

#### Inline colocated js hooks

**Never** write raw embedded `<script>` tags in heex as they are incompatible with LiveView. Instead, **always use a colocated js hook script tag (`:type={Phoenix.LiveView.ColocatedHook}`) when writing scripts inside the template**:
  ```elixir
    <input type="text" name="user[phone_number]" id="user-phone-number" phx-hook=".PhoneNumber" />
    <script :type={Phoenix.LiveView.ColocatedHook} name=".PhoneNumber">
      export default {
        mounted() {
          this.el.addEventListener("input", e => {
            let match = this.el.value.replace(/\D/g, "").match(/^(\d{3})(\d{3})(\d{4})$/)
            if(match) {
              this.el.value = `${match[1]}-${match[2]}-${match[3]}`
            }
          })
        }
      }
    </script>
  ```
- colocated hooks are automatically integrated into the app.js bundle.
- colocated hooks names **MUST ALWAYS** start with a `.` prefix, i.e. `.PhoneNumber`.

#### External phx-hook

External JS hooks (`<div id="myhook" phx-hook="MyHook">`) must be placed in `assets/js/` and passed to the LiveSocket constructor:
  ```elixir
    const MyHook = {
      mounted() { ... }
    }
    let liveSocket = new LiveSocket("/live", Socket, {
      hooks: { MyHook }
    });
  ```

#### Pushing events between client and server

Use LiveView's `push_event/3` when you need to push events/data to the client for a phx-hook to handle. **Always** return or rebind the socket on `push_event/3` when pushing events:
  """
    ```elixir
      # re-bind socket so we maintain event state to be pushed
      socket = push_event(socket, "my_event", %{...})

      # or return the modified socket directly:
      def handle_event("some_event", _, socket) do
        {:noreply, push_event(socket, "my_event", %{...})}
      end
    ```

    Pushed events can then be picked up in a JS hook with `this.handleEvent`:
      ```elixir
        mounted() {
          this.handleEvent("my_event", data => console.log("from server:", data));
        }
      ```

    Clients can also push an event to the server and receive a reply with `this.pushEvent`:
      ```elixir
        mounted() {
          this.el.addEventListener("click", e => {
            this.pushEvent("my_event", { one: 1 }, reply => console.log("got reply from server:", reply));
          })
        }
      ```

    Where the server handled it via:
      ```
        def handle_event("my_event", %{"one" => 1}, socket) do
          {:reply, %{two: 2}, socket}
        end
      ```
  """

### LiveView tests

- `Phoenix.LiveViewTest` module and `LazyHTML` (included) for making your assertions.
- Form tests are driven by `Phoenix.LiveViewTest`'s `render_submit/2` and `render_change/2` functions.
- Come up with a step-by-step test plan that splits major test cases into small, isolated files. You may start with simpler tests that verify content exists, gradually add interaction tests.
- **Always reference the key element IDs you added in the LiveView templates in your tests** for `Phoenix.LiveViewTest` functions like `element/2`, `has_element/2`, selectors, etc..
- **Never** tests again raw HTML, **always** use `element/2`, `has_element/2`, and similar: `assert has_element?(view, "#my-form")`.
- Instead of relying on testing text content, which can change, favor testing for the presence of key elements.
- Focus on testing outcomes rather than implementation details.
- Be aware that `Phoenix.Component` functions like `<.form>` might produce different HTML than expected. Test against the output HTML structure, not your mental model of what you expect it to be.
- When facing test failures with element selectors, add debug statements to print the actual HTML, but use `LazyHTML` selectors to limit the output, e.g.:
  ```elixir
    html = render(view)
    document = LazyHTML.from_fragment(html)
    matches = LazyHTML.filter(document, "your-complex-selector")
    IO.inspect(matches, label: "Matches")
  ```

## Strict Guidelines

### Implementation Guidelines

- Refer to the codebase, other files, and functions to understand how things are done. Match existing patterns and conventions rather than inventing new ones.
- Always use the latest applicable documentation and best current knowledge for the versions already in this project, and look for and use the latest for everything else.
- Do not re-implement functionality that already exists in the codebase or in any existing utility/dependency/plugin/package functions. Check first.
- Check project existing utilities/dependencies/plugins/packages before writing new functions, a utility/dependency/plugin/package may already provide what you need. Use existing utility/dependency/plugin/package rather than reinventing their functionality.
- Do not overdo. Avoid adding excessive safeguards for unlikely cases. Raise an error or a terminal output instead. Adhere to `### Detailed Specifications for Abstraction / Helper / Function Creation Rules`.
- It is not necessary to create a helper function (or any kind of function in general) if it's only referenced once, instead, put it directly inline where it is used. For more detailed explanation, refer to `### Detailed Specifications for Abstraction / Helper / Function Creation Rules`.
- Question my method of approaching a problem when necessary, especially if it is not optimal or not sensible to implement.
- If you want to run any command, consider trying it with `mise exec -- ` appended first since most of my tools are configured under mise for proper version control.
- Never ever execute any `git`-related commands, what you see is what you work with.
- Never ever add new comments (this include docs, or anything alike) unless instructed to. However, you are allowed to modify comments when necessary for example when removing or adding a feature from a function to keep it accurate but follow a similar writing style.
- Always prefer using Tailwind's grid-cols when positioning elements, and adhere to `#### Detailed Specifications for Layout Grids`.
- When a reference implementation is provided or a similar implementation already exists within the system, default to reference fidelity over cleverness. Matching the existing structure, flow, processing, relative placement of the logic, layers, UI, and abstraction boundary down to the granular level. This is preferred over producing a different but equivalent implementation unless there is a strong reason not to.
- Always separate the frontend from the backend file-wise in the same folder (e.g. .ex and .html.heex files).
- Always use centrally defined project colours from the global CSS/theme layer. Do not introduce page-local or ad hoc colours. Colours should come from a centralized source so updates stay global and consistent.
- Do not use responsive utility variant classes like `grid-cols-[1fr] md:grid-cols-[1fr_1fr] xl:grid-cols-[1fr_1fr_1fr]`, and `w-16 md:w-32 lg:w-48`.
- Adhere to `#### Detailed Specifications for Abstraction / Helper / Function Creation Rules`.
- Adhere to `#### Detailed Specifications for Layout Grids`.
- Adhere to `#### Designing w/ Layout Grids`.
- You are required to run the following after every implementation:
    - `mise exec -- mix format`
    - `mise exec -- mix test`
    - `MIX_ENV=test mise exec -- mix dialyzer`
    - If anything fails whether it's related to the user proposed change or not, fix it and continue fixing it until everything passes. Do not move on to the next piece of work until tests pass. New changes must not break existing functionality.
- Use `mix precommit` alias when you are done with all changes and fix any pending issues.

#### Detailed Specifications for Abstraction / Helper / Function Creation Rules

- Anonymous functions are allowed only when written inline as direct callbacks/reference to existing Elixir/Phoenix existing functions and APIs. Other than this reason, you are not allowed to use or create anonymous functions ever. Every rule listed after this is mostly (if not all) for named functions only.
- A separate function is allowed for framework-required callback entrypoints or for named recursion when anonymous functions are disallowed. Outside of those cases, keep the logic inline.
- Do not create new functions unless there is a clear need.
- A new function is allowed, but evaluate extraction at the branch level, not just the module level, only if all of these is true:
  - If logic is only used inside one event branch, one case branch, one cond branch, or one callback path, keep it inline in that branch.
  - If different branches only look similar but are tied to different IDs, fields, or business rules, keep them separate and inline.
  - Before creating any new function, first ask the following questions. If the answer to all 3 is no, keep it inline:
    - Is this reused or referenced more than once?
    - Is this a real domain concept?
    - Does extraction improve clarity more than it increases indirection?
    - and one of these is true:
      - the exact logic is used in 2 or more places.
      - the logic represents a real domain concept with its own meaning.
      - the framework requires separation.
      - the inline version would be materially harder to read or maintain.
- Do not extract branch-specific logic into a helper just because it is a few lines long or looks reusable.
- Do not extract single-branch logic.
- Do not extract single-ID logic.
- Do not extract single-callback logic.
- Only extract when reuse is real, not speculative.
- Do not create helpers unless they are reused or they encapsulate genuine domain behavior.
- If you create a new helper, explicitly justify why inline code was not sufficient.
- When a function already exists for a concern, prefer expanding that utility into the canonical implementation rather than introducing parallel logic at the call site.
- When multiple implementations perform the same technical operation, prefer consolidating that operation into one existing shared utility/module rather than duplicating the logic across feature modules:
  - If the same low-level operation appears in 2 or more places, move it into the most appropriate shared utility that already owns that concern.
  - Prefer strengthening an existing utility/module over creating a new feature-specific helper/service.
  - Shared infrastructure concerns should be a one standardized implementation path.
  - Do not keep multiple equivalent implementations of the same technical operation unless there is a real behavioral difference that must remain separate.
  - If a shared utility already exists for that concern, extend it there instead of re-implementing the logic locally.
  - If you choose not to consolidate duplicated logic into the shared utility, explicitly justify the behavioral difference that prevents standardization.
- Single-use wrappers around existing functions are not allowed.
- Thin wrappers that's so slight in functionality, or immediately forward to an existing function are not allowed.
- Small one-off transformations of data should stay inline.
- Do not extract code into a helper if the helper does not remove meaningful complexity from the caller.
- A helper must make the call site read at a higher level of abstraction than the code it replaces.
- If the extracted function only forwards parameters, performs a tiny one-off transformation, or wraps a single obvious expression, keep it inline.
- If reading the helper body is required to understand the caller immediately, the extraction is not helpful and should not be done.
- Do not extract a helper whose name merely restates the implementation without adding domain meaning.
- Prefer inline code when the logic is short, local, and easier to understand in place than by jumping to another function.
- A valid helper should do at least one of these:
  - hide multi-step logic
  - encode a real business/domain concept
  - remove repeated non-trivial logic
  - satisfy a framework requirement
- Helpers that only reduce line count but increase indirection are not allowed.
- Before extracting, apply this test:
  - Does the caller become simpler to understand without opening the helper?
  - Does the helper name communicate domain meaning, not just mechanics?
  - Is the body more than a trivial pass-through or obvious expression?
  - If any answer is no, keep it inline.
- Reuse alone is not enough to justify a helper.
- Repeated trivial mechanics must still stay inline unless they are an existing shared utility already used across the codebase.
- Do not create private helpers for primitive normalization.
- Generic technical cleanup is not a domain concept.
- Helpers are presumed invalid unless they encode real business meaning or are already established shared utilities in the codebase.
- If the logic is still understandable only as a low-level operation, keep it inline even when repeated in multiple places.
- A helper must raise the abstraction level from mechanics to meaning.
- If the helper only standardizes syntax-level cleanup, it is not a valid helper.
- The consolidation rules do not apply to primitive local mechanics, syntax cleanup, or inline callback logic.
- Do not move trivial repeated local mechanics into shared utilities/modules.
- If you think that the helper functions that you are going to create might be useful throughout the entire project going forward, consider building them inside `core_utils` or expand similar functions that already exists in `core_utils`. However, this requires confirmation from me and has to be consulted before implementation.

#### Detailed Specifications for Layout Grids

- Always use Tailwind `grid-cols-[...]` with explicit `fr`/fixed-width values instead of preset classes like `grid-cols-2`, `grid-cols-3`, etc.
- Always use explicit bracketed grid columns such as `grid-cols-[1fr_1fr]` or `grid-cols-[2.75rem_1fr_1fr_2.75rem]`.
- Do not use Tailwind preset grid column counts like `grid-cols-2`, `grid-cols-3`, `grid-cols-4`, etc., unless I explicitly ask for it.
- Use `rem` for fixed elements like action/button/sequence columns.
- Only if the same grid column definition is reused/referenced more than once within the same related section/component/template, define it once in a variable such as `items_grid_cols` and reuse/reference it. Otherwise define it inline.:
  """
    **Never do this (invalid)**:
      ```elixir
        three_field_grid_cols = "grid grid-cols-[1fr_1fr_1fr]"

        <div class={three_field_grid_cols}>
          <.input field={f[:input_1]} type="text" label="Input 1" />
          <.input field={f[:input_2]} type="text" label="Input 2" />
          <.input field={f[:input_3]} type="text" label="Input 3" />
        </div>

        <div class={three_field_grid_cols}>
          <.input field={f[:input_1]} type="text" label="Input 1" />
          <.input field={f[:input_2]} type="text" label="Input 2" />
          <.input field={f[:input_3]} type="text" label="Input 3" />
        </div>

        <div class={three_field_grid_cols}>
          <.input field={f[:input_1]} type="text" label="Input 1" />
          <.input field={f[:input_2]} type="text" label="Input 2" />
          <.input field={f[:input_3]} type="text" label="Input 3" />
        </div>
      ```
    Just because the string happens to match, do not extract unrelated repeated grid definitions into a shared variable.

    However, the following is **valid**:
      ```elixir
        <% items_grid_cols = "grid-cols-[2.75rem_1fr_1fr_2.75rem]" %>
        ...
        <div class={"w-full grid #{items_grid_cols} gap-2 pb-2 pt-2 border-b-[1px] border-b-white"}>
          <div class="text-center">No.</div>
          <div class="ps-1">Code</div>
          <div class="ps-1">Name</div>
          <div>Delete</div>
        </div>
        <.inputs_for :let={item_f} field={f[:items]}>
          <div
            id={"item-#{item_f.index}"}
            class={"w-full grid #{items_grid_cols} gap-2 pb-2 border-b-[1px] border-b-white"}
          >
            <.input field={item_f[:number]} type="text"/>
            <.input field={item_f[:code]} type="text"/>
            <.input field={item_f[:name]} type="text"/>
              <.button
                type="button"
                phx-click="remove_item"
                phx-value-number={item_f[:number].value}
              >
                <.icon name="hero-trash" />
              </.button>
          </div>
        </.inputs_for>
      ```
    The above is **valid** because the `items_grid_cols` variable repeated usages are part of the same logical layout block.
  """
- Only extract a grid column variable when the repeated usages are part of the same logical layout block. Do not extract unrelated repeated grid definitions into a shared variable just because the string happens to match.
- Keep the variable local and on top of the file where it is used.
- When editing an existing file, normalize any touched repeated grid layout in that same section to this pattern.

#### Designing w/ Layout Grids

- Compose each section on a fixed even grid. Think in `1x`, `2x`, and clean half-blocks, not arbitrary widths.
- Preserve the visual center seam. Rows should feel like balanced left/right bands, not drift into uneven 3-part compositions.
- Prefer layouts that resolve in multiples of `2`. If the structure starts feeling like `3` uneven groups, the rhythm is probably wrong.
- Fields may span across neighboring fields, but only in whole grid units. Their left and right edges must land on real grid lines used by the rows around them.
- A field should not start or stop at the middle of a field above or below unless that midpoint is part of a deliberate, symmetric subdivision in both rows.
- Cross-row alignment matters more than strict field order. Reorder within the section if needed to keep edges clean.
- Wide fields are used to absorb space cleanly, not just because they can be wider.
- Empty space should collect only at the far right edge of the final row. Avoid holes in the middle, bottom-right appendices, or orphan closing rows.
- Similar-density fields should keep a steady rhythm. Dates, short enums, codes, and numeric fields should usually sit in consistent-width slots.
- A good span feels anchored to the surrounding grid.
- Another acceptable case is an internal split that stays self-contained and symmetric.
- A bad span is one where the upper row cuts awkwardly across the lower row’s field boundaries.
- If the occupied area forms a staircase, inverted `L`, or dangling last-row hook, the layout is not balanced.

### Description / Explanation / Analysis Guidelines

When asked to describe, explain, or analyze, do it fully and completely in its entirety, every line, every function, every module, and everything that interacts with it or has any relation to it. Always look and use for the latest documentation for everything. Never ever execute any `git`-related commands, what you see is what you work with.

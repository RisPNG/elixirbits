This is a web application written using the Phoenix web framework.

How to read this file: everything under `## Strict Guidelines` is binding at all times. The framework guidelines apply whenever you work in that area. When two rules seem to conflict, the more specific rule wins; if it is still ambiguous, ask me before proceeding. Comments inside this file's code examples (e.g. `<%!-- 3 fields, name wider --%>`) annotate the examples for the reader of this file -- they are not an instruction to write comments in generated code.

For Elixir/Phoenix syntax, dependencies, and tooling, always refer to the documentation (hexdocs.pm and others) matching the versions specified in `.tool-versions` and `mix.exs`; for anything not specified there, use the latest documentation.

## Project guidelines

- This project is heavily inspired by the references in `../sig-portal/`. However, you may take ideas from these references because it's how I like them, but not the code, mostly the logic.

### Phoenix >= v1.8 guidelines

- Out of the box, `core_components.ex` imports a component for Heroicons, such as `<.icon name="hero-x-mark" class="w-5 h-5" />`. **Always** use the `<.icon>` component for icons, **never** use `Heroicons` modules or similar.
- **Always** use the imported `<.input>` component for form inputs from `core_components.ex` when available. `<.input>` is imported and using it will save steps and prevent errors.
  - For select inputs, always use `type="live-select"` -- a custom type defined in `core_components.ex`.
- If you override the default input classes with your own values, no default classes are inherited, so your custom classes must fully style the input.

### JS and CSS guidelines

- **Use Tailwind CSS classes and custom CSS rules** to create and build interfaces.
- **Always** manually write your own tailwind-based components instead of using daisyUI for design.
- Out of the box **only the app.js and app.css bundles are supported**.
  - You cannot reference an external vendor'd script `src` or link `href` in the layouts.
  - You must import the vendor deps into app.js and app.css to use them, which means you **never write inline `<script>custom js</script>` tags** or **inline styles**.

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
          else
            socket
          end
      ```
  """
- Elixir's standard library has everything necessary for date and time manipulation. Familiarize yourself with the common `Time`, `Date`, `DateTime`, and any other installed dependency interfaces by accessing their documentation as necessary. **Never** install additional dependencies unless asked for or there's no other reasonable choice.
- Don't use `String.to_atom/1` on user input (memory leak risk).
- Predicate function names should not start with `is_` and should end in a question mark. Names like `is_thing` should be reserved for guards.
- For long-running operations -- `Task` functions (especially `Task.async_stream/3` and `Task.await/2`) and batch `Repo` calls (large inserts, updates, deletes, backfills) -- pass `timeout: :infinity` instead of guessing a larger finite timeout. Do not add it to ordinary request-path queries; if a normal query times out, fix the query first.

## Mix guidelines

- `mix deps.clean --all` is **almost never needed**. **Avoid** using it unless you have good reason.

## Phoenix HTML guidelines

- Phoenix templates **always** use `~H` or .html.heex files (known as HEEx), **never** use `~E`.

## Phoenix LiveView guidelines

- LiveViews should be named like `AppWeb.WeatherLive`, with a `Live` suffix. When you go to add LiveView routes to the router, the default `:browser` scope is **already aliased** with the `AppWeb` module, so you can just do `live "/weather", WeatherLive`.

### LiveView tests

- Come up with a step-by-step test plan that splits major test cases into small, isolated files. You may start with simpler tests that verify content exists, gradually add interaction tests.
- Instead of relying on testing text content, which can change, favor testing for the presence of key elements.
- Focus on testing outcomes rather than implementation details.

## Strict Guidelines

### Implementation Guidelines

- Refer to the codebase, other files, and functions to understand how things are done. Match existing patterns and conventions rather than inventing new ones.
- Always use the documentation matching the versions of the tools and dependencies specified in this project (`.tool-versions`, `mix.exs`) when applicable; for everything else, look for and use the latest documentation.
- Do not re-implement functionality that already exists in the codebase or in an existing utility/dependency/plugin/package. Check first, and use the existing implementation rather than reinventing it.
- Do not overdo. Avoid adding excessive safeguards for unlikely cases -- raise an error or print to the terminal instead.
- Question my method of approaching a problem when necessary, especially if it is not optimal or not sensible to implement.
- If you want to run any command, consider trying it with `mise exec -- ` prepended first since most of my tools are configured under mise for proper version control.
- New resources should:
  - always include `timestamps()` (`inserted_at` and `updated_at`) unless there is a strong reason not to.
  - default string columns to text, unless a more specific type is needed like citext or an extension-specific type.
  - default to UUIDv7 primary keys, unless the resource or dependency has a stronger reason to use another key strategy.
  - explicitly decide whether it needs AshPaperTrail, AshEvents, AshArchival, and AshStateMachine, especially when user didn't specify. Always recap to the user simply with example what each of the options mean.
- All database/resource operations are preferably required to go through Ash actions to ensure that Paper Trail, Event Sourcing, and Archival works as expected. However, direct Repo and SQL query calls are always allowed when it is intentional and acceptable.
- When creating migrations, always use `mix ecto.gen.migration` and keep a single migration file per feature branch, which excludes the master/main and testing branches.
- Never execute mutating `git` commands (`add`, `commit`, `push`, `checkout`, `restore`, `reset`, `stash`, `rebase`, `merge`, etc.) unless I explicitly instruct it. Read-only `git` commands (`status`, `diff`, `log`, `show`, `blame`) are allowed when useful. What you see is what you work with -- never use `git` to discard or rewrite changes.
- Never add new comments (this includes docs such as `@doc`/`@moduledoc`, or anything alike) unless instructed to. However, you are allowed to modify existing comments when necessary -- for example, to keep them accurate after adding or removing functionality -- following a similar writing style.
- Always prefer using Tailwind's grid-cols when positioning elements.
- When a reference implementation is provided or a similar implementation already exists within the system, default to reference fidelity over cleverness: match the existing structure, flow, processing, relative placement of the logic, layers, UI, and abstraction boundary down to the granular level. This is preferred over producing a different but equivalent implementation unless there is a strong reason not to.
- Always separate the frontend from the backend file-wise in the same folder (e.g. `.ex` and `.html.heex` files).
- Always use centrally defined project colours from the global CSS/theme layer. Do not introduce page-local, color-mixes, opacity, or ad hoc colours. Colours should come from a centralized source so updates stay global and consistent.
- Do not use responsive utility variant classes like `grid-cols-[1fr] md:grid-cols-[1fr_1fr] xl:grid-cols-[1fr_1fr_1fr]` or `w-16 md:w-32 lg:w-48`.
- Adhere to `#### Abstraction / Helper / Function Creation Rules` and `#### Layout Grids` below.
- You are required to run the following after every implementation:
  - `mise exec -- mix format`
  - `mise exec -- mix test`
  - `MIX_ENV=test mise exec -- mix dialyzer`
  - If anything fails, whether it's related to the requested change or not, fix it and continue fixing it until everything passes. Do not move on to the next piece of work until tests pass. New changes must not break existing functionality. When you fix failures unrelated to the requested change, list those fixes separately in your response.
- Use `mix precommit` alias when you are done with all changes and fix any pending issues.

#### Abstraction / Helper / Function Creation Rules

The default is inline. A new named function is the exception and must earn its place under the rules below; when in doubt, keep the logic inline.

##### Definitions used by these rules

- **Trivial mechanics**: logic readable at a glance as a low-level operation -- a one-to-three-step data transformation, parameter forwarding/reshuffling, primitive normalization, generic technical cleanup, or a single obvious expression. Test: if the best possible name for it would merely restate the code (`trim_and_downcase`, `put_default_status`), it is trivial mechanics.
- **Meaningful operation**: multi-step logic that carries a genuine domain or infrastructure concept -- it has a name in the business/system vocabulary that says *what* it means, not *how* it works (`calculate_invoice_total`, `authorize_export`).

##### Anonymous functions

- Anonymous functions are allowed only when written inline as direct callbacks/arguments to existing Elixir/Phoenix/dependency APIs (e.g. `Enum.map(list, fn x -> ... end)`).
- Never assign an anonymous function to a variable or create one for any other purpose. For recursion, use a named function.

##### Named functions

- Framework-required callback entrypoints (`mount/3`, `handle_event/3`, `render/1`, `changeset/2`, etc.) and named functions needed for recursion are always allowed. The conditions below govern every other named function.
- A new named function may be created only when **all** of the following hold:
  1. It is a meaningful operation, not trivial mechanics. Trivial mechanics always stay inline -- even when the same mechanics are repeated in multiple places. Reuse alone is never enough.
  2. At least one of:
     - the exact logic is genuinely used in 2 or more places (real reuse, not speculative),
     - it encodes a genuine domain concept with its own meaning,
     - the inline version would be materially harder to read or maintain.
  3. The call site reads at a higher level of abstraction and is understandable without opening the helper.
  4. The function name communicates domain meaning rather than restating the implementation.
- If any condition fails, keep it inline.

##### Branch-level evaluation

- Evaluate extraction at the branch level, not just the module level: logic used inside only one event branch, one `case`/`cond` branch, or one callback path stays inline in that branch -- do not extract it just because it is a few lines long or looks reusable.
- Branches that merely look similar but are tied to different IDs, fields, or business rules are not duplication. Keep them separate and inline.

##### Wrappers

- Single-use wrappers, thin wrappers, and pass-throughs around existing functions are not allowed -- call the existing function directly. A helper that only forwards parameters, wraps a single obvious expression, or reduces line count while adding indirection is not a valid helper.

##### Consolidating duplicated meaningful operations

- When the same meaningful operation exists (or would now exist) in 2 or more places, consolidate it into the one shared utility/module that already owns that concern. Prefer strengthening the existing utility into the canonical implementation over creating a new feature-local helper or parallel logic at the call site.
- Keep multiple implementations of the same operation only when a real behavioral difference forces it.
- Trivial mechanics are exempt from consolidation: never promote repeated trivial mechanics into a shared utility. Shared utilities already established in the codebase may of course keep being used.

##### Justification -- to me, in your response, never as code comments

- For each new named function: state in one sentence which condition above it satisfies and why inline was not sufficient.
- For each decision to keep duplicated meaningful logic unconsolidated: state in one sentence the behavioral difference that prevents consolidation.

#### Layout Grids

##### Plan the section before code

- Before writing any grid markup for a section, plan the structure top-down:
  1. **Section composition.** Decide whether the section is row-based (full-width rows top to bottom), region-based (outer grid splits into side-by-side sub-stacks), or a mix. Base this on whether the field set has natural side-by-side sub-groupings -- if yes, regions; if not, rows. Don't default to one or the other; pick whichever fits.
  2. **Rows.** Within the section (or within each region if region-based), group fields into rows. Each row holds 1–N fields that belong together visually/semantically.
  3. **Per-row grid-cols.** For each row, choose `grid-cols-[...]` whose column count equals the row's field count and whose fr ratios match field density.
- If a row would need `col-span` or an empty trailing `<div></div>` to fit, the field count or grid-cols is wrong -- adjust the row instead. (A genuine final-row remainder is handled under **Visual balance**.)

##### Syntax rules

- Always use Tailwind `grid-cols-[...]` with explicit `fr`/fixed-width values, such as `grid-cols-[1fr_1fr]` or `grid-cols-[2.75rem_1fr_1fr_2.75rem]`.
- Do not use Tailwind preset grid column counts like `grid-cols-2`, `grid-cols-3`, `grid-cols-4`, etc., unless I explicitly ask for it.
- Use `rem` for fixed elements like action/button/sequence columns.

##### Encoding field width

- A field's visual width is determined by the `fr` units of its column in the row's `grid-cols-[...]` definition. To make a field wider, give that column a larger `fr` value (e.g. `grid-cols-[1fr_3fr]` makes the second column three times as wide; `[1fr_1fr_2fr]` makes the third column twice as wide as the first two).
- The row's `grid-cols-[...]` is the single source of truth for that row's field widths. Tune fr ratios per row, not across the whole section: short codes/numbers → `1fr`; fields that genuinely need the room (names, descriptions, textareas, remark fields, emails, search-style live-selects) → `2fr` or `3fr`. Don't make a column wide just to fill space.
- Use clean ratios that resolve in halves/quarters (`1fr_1fr`, `1fr_2fr`, `1fr_1fr_2fr`, `1fr_3fr`, `1fr_1fr_1fr_1fr`) over arbitrary fractions. (Half-unit columns like `0.5fr` are permitted only as part of a symmetric internal split -- see **Visual balance**.)
- **Do not use `col-span-N` to widen fields.** `col-span-N` is permitted only inside structurally-table-like blocks where a single cell must literally cross multiple discrete columns that exist as separately-sized columns for other rows -- e.g. a header cell that announces a group covering several body columns of an items table. For ordinary form sections, treat `col-span` as forbidden: the answer is always to size the row's columns directly, never to span.

##### Composition: rows vs regions

- There is no fixed shape for a form section. The two common compositions (neither is a default -- pick whichever fits the data):
  - **Row-based section.** The whole section is a vertical stack of full-width rows. Each row is its own `grid grid-cols-[...]` spanning the full width of the section. Use this when the fields read top-to-bottom as one continuous group and don't divide into parallel sub-groups.
  - **Region-based section.** An outer grid (commonly `grid-cols-[1fr_1fr]` for halves, sometimes `[1fr_1fr_1fr]` for thirds) splits the section into side-by-side regions. Inside each region, rows are stacked vertically with `flex flex-col gap-N`, and each stacked row is its own inner `grid grid-cols-[...]`. Use this when the field set has clear parallel groupings -- e.g. address fields on the left + contact fields on the right.
- A section can also mix: e.g. a row-based top half followed by a region-based bottom half, or a single full-width row at the top and split regions below it. Use what reads cleanest, but don't introduce a region split just for visual variety -- the split must be backed by a real grouping in the data.
- Whichever composition you choose, **each individual row picks its own `grid-cols-[...]` based on the fields it holds.** Different rows may use different column counts and different fr ratios -- that is expected and correct.
  - Row-based section example:
    ```
    <div class="grid grid-cols-[1fr_2fr_1fr_1fr_1fr] gap-2 mt-2">...</div>     <%!-- 5 fields, name wider --%>
    <div class="grid grid-cols-[1fr_2fr_1fr_1fr_1fr] gap-2 mt-2">...</div>     <%!-- another 5 --%>
    <div class="grid grid-cols-[1fr_1fr_1fr_1fr_1fr_1fr] gap-2 mt-2">...</div> <%!-- 6 same-density fields --%>
    ```
  - Region-based section example (inside one region):
    ```
    <div class="flex flex-col gap-2">
      <div class="grid grid-cols-[1fr_1fr_2fr] gap-2 items-end">...</div>      <%!-- 3 fields, last wider --%>
      <div class="grid grid-cols-[1fr_1fr_1fr_1fr] gap-2">...</div>            <%!-- 4 same-density --%>
      <div class="grid grid-cols-[1fr_1fr] gap-2">...</div>                    <%!-- 2 fields --%>
    </div>
    ```
- Adjacent rows of similar field density will naturally share the same grid-cols string (e.g. four rows of 4 short fields each sharing `grid-cols-[1fr_1fr_1fr_1fr]`). Let that happen, but don't force it -- the match is a coincidence of the field sets, not a rule.

##### Visual balance

- The mechanics above produce a *valid* grid; these rules produce a *balanced* one. A section can satisfy every syntax and composition rule and still read as lopsided or jagged -- this subsection is the quality bar that catches that. When choosing per-row grid-cols, judge the result against these:
- **Compose on a fixed even grid.** Think in `1x`, `2x`, and clean half-blocks, not arbitrary widths. Prefer layouts that resolve in multiples of `2`; if a row starts feeling like `3` uneven groups, the rhythm is probably wrong.
- **Preserve the visual center seam.** Rows should feel like balanced left/right bands, not drift into uneven 3-part compositions. (This is also why region-based sections lean on `[1fr_1fr]` halves.)
- **Edges must land on real grid lines.** A "span" here means a wider `fr` column (e.g. `2fr` where the row's base unit is `1fr`), never `col-span`. A wide column's left and right edges must coincide with grid lines used by the rows around it. A field should not start or stop at the middle of a field above or below.
  - **The one exception:** a midpoint is allowed when it is a deliberate, symmetric subdivision -- an internal split that stays self-contained inside one parent column's edges. `grid-cols-[2fr_0.5fr_0.5fr_1fr]` (over a 4-unit base row) is valid: the `2fr` field aligns with two `1fr` columns above, and the `0.5fr_0.5fr` pair splits a single column symmetrically without bleeding into its neighbors. An asymmetric split like `0.7fr_0.3fr`, or one whose midpoint lines up with nothing meaningful in the adjacent rows, is not.
- **Cross-row alignment beats field order.** If reordering fields within the section keeps edges clean, reorder them. A good wide column feels anchored to the surrounding grid; a bad one cuts awkwardly across the lower row's field boundaries.
- **Wide columns absorb space cleanly** -- give a column more `fr` because the field needs the room (names, descriptions, remarks, emails), not just because it can be wider.
- **Similar-density fields keep a steady rhythm.** Dates, short enums, codes, and numeric fields should sit in consistent-width slots across rows, not jump between `1fr` in one row and `3fr` in the next.
- **Empty space collects at the far right of the final row only.** Avoid holes in the middle, bottom-right appendices, or orphan closing rows. A genuine remainder keeps its normal slot width and lets the trailing grid track sit empty -- this comes from under-filling the row's columns, never from inserting a placeholder `<div></div>`.
- **Silhouette test.** Picture the occupied area as one solid shape. If it forms a staircase, an inverted `L`, or a dangling last-row hook, the layout is not balanced -- it should read as a clean rectangle with at most one gap at the bottom-right.

##### Spacing conventions

- Between rows in a row-based section: `mt-N` (or `gap-N` if rows live inside a `flex flex-col gap-N`).
- Between fields within a row: `gap-N`.
- Between regions in a region-based section: `gap-N` on the outer grid.
- Between rows inside a region: `gap-N` on the region's `flex flex-col`.
- Adjust spacing only with intent.

##### Sharing a grid string (variable extraction)

- Inline the `grid-cols-[...]` string in each row by default.
- Only extract the grid-cols string into a variable (e.g. `items_grid_cols`) when the repeated rows form a single logical layout block -- meaning the rows are structurally bound to each other as parts of one composite unit (e.g. a list header row plus its `<.inputs_for>` item rows; or a table header row plus its body rows). In that case the variable lives at the top of the file/component scope where it is used.
- Form-section rows that happen to share the same grid-cols string are NOT a logical layout block. The fact that the strings match is coincidence -- these rows are independent visually-aligned rows, not a single composite unit. Inline each.
  """
    **VALID -- single logical layout block (header + items list share one grid):**
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

    **INVALID -- independent form rows extracted into a shared variable just because they happen to share a string:**
      ```elixir
        <% three_field_grid_cols = "grid grid-cols-[1fr_1fr_1fr]" %>

        <div class={three_field_grid_cols}>
          <.input field={f[:input_1]} type="text" label="Input 1" />
          <.input field={f[:input_2]} type="text" label="Input 2" />
          <.input field={f[:input_3]} type="text" label="Input 3" />
        </div>

        <div class={three_field_grid_cols}>
          <.input field={f[:input_4]} type="text" label="Input 4" />
          <.input field={f[:input_5]} type="text" label="Input 5" />
          <.input field={f[:input_6]} type="text" label="Input 6" />
        </div>
      ```
    These rows are not a composite unit -- they are independent rows in a form section. Inline each:
      ```elixir
        <div class="grid grid-cols-[1fr_1fr_1fr] gap-2">
          <.input field={f[:input_1]} type="text" label="Input 1" />
          <.input field={f[:input_2]} type="text" label="Input 2" />
          <.input field={f[:input_3]} type="text" label="Input 3" />
        </div>

        <div class="grid grid-cols-[1fr_1fr_1fr] gap-2">
          <.input field={f[:input_4]} type="text" label="Input 4" />
          <.input field={f[:input_5]} type="text" label="Input 5" />
          <.input field={f[:input_6]} type="text" label="Input 6" />
        </div>
      ```
  """

### Description / Explanation / Analysis Guidelines

- When asked to describe, explain, or analyze, be complete within the scope of the request: cover every line, every function, and every module the request targets. For anything outside that scope that interacts with the target, summarize the relationship briefly instead of fully expanding it, and ask me before widening the scope.
- Always use the documentation matching the versions of the tools and dependencies specified in this project (`.tool-versions`, `mix.exs`) when applicable; for everything else, look for and use the latest documentation.
- Never execute mutating `git` commands (`add`, `commit`, `push`, `checkout`, `restore`, `reset`, `stash`, `rebase`, `merge`, etc.) unless I explicitly instruct it. Read-only `git` commands (`status`, `diff`, `log`, `show`, `blame`) are allowed when useful. What you see is what you work with -- never use `git` to discard or rewrite changes.
- Always provide a simpler explanation along with real-world examples at the end of every explanation when applicable.
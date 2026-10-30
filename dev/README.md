# Elixirbits development guide

An Elixir, Phoenix LiveView, and Ash application template with authentication, account administration, page permissions, shared form components, and reusable application infrastructure.

This guide covers setup, implementation, verification, and deployment. For the application overview, see the [main README](../README.md). Run the commands below from the repository root.

The template as a whole defines the implementation standard, including application structure, resource access, permissions, shared components, and page behaviour. Use the relevant existing implementation as the reference for new work, and keep its code, examples, tests, and documentation consistent when changing a shared pattern.

Write each prose paragraph on one physical source line and let the editor wrap it visually. Keep blank lines between paragraphs and preserve the line structure of lists, tables, code examples, and intentional hard breaks. This applies to documentation, explanatory comments, and help text. Code keeps its normal formatter layout. Dependency, vendor, and generated files retain their upstream formatting.

## Local setup

`mise.toml` actively selects the latest tool releases. `.tool-versions` records exact known toolchain versions for reference and does not override that selection. Install the tools with mise:

```sh
mise install
```

Run project commands through `mise exec --` so they use the selected tools and project environment. The `MIX_ARCHIVES` setting in `mise.toml` follows the selected Elixir installation and normalises its path to forward slashes. Mix uses that path to discover and update Hex archives correctly on Windows.

PostgreSQL must be running on `localhost:5432` with username and password `postgres`, matching the local configuration. The PostgreSQL package installed by mise on Windows does not start a database server automatically. If there is no existing local server, create a development cluster once, provided `var/postgres` does not already exist:

```sh
mise exec -- initdb -D var/postgres --username=postgres --encoding=UTF8 --locale=C --auth=scram-sha-256 --pwprompt
```

Enter `postgres` at both password prompts. The ignored `var/postgres` directory holds the development databases between runs. Start this cluster whenever it is stopped:

```sh
mise exec -- pg_ctl start -D var/postgres -l var/postgres/server.log -o "-h 127.0.0.1 -p 5432" -w
```

Run the initial application setup once, then start Phoenix. Later runs only need the server command after PostgreSQL has started:

```sh
mise exec -- mix setup
mise exec -- mix phx.server
```

Press `Ctrl+C` to stop Phoenix. To stop the local PostgreSQL cluster while retaining its databases:

```sh
mise exec -- pg_ctl stop -D var/postgres -m fast -w
```

Node and npm manage the JavaScript dependencies. `mix assets.setup` installs them and updates `assets/package-lock.json` through npm. Its `cmd --cd assets --shell npm install` task uses the shell so Windows can resolve `npm.cmd`. For a clean installation of the locked versions, run `mise exec -- npm ci --prefix assets` after fetching the Mix dependencies.

Chart.js, Pretext, and Web Haptics remain available for future development. Import them when an application feature needs them; the current entry bundle does not load them.

The date/time picker library loads when a `VCalendar` input mounts, and the RGBA picker library loads when a colour input renders its editable picker. Pages without those controls do not download either library. The hooks retain current field state when loading finishes and ignore removed controls.

`assets/package.json` installs `super-image-cropper` from the `ris` branch of `RisPNG/super-image-cropper`, and `assets/package-lock.json` records the exact Git revision. npm prepares the package and its internal worker during installation, so the application does not require a sibling checkout. Update the dependency deliberately when adopting a newer fork revision. Keep the fork's `master` branch as the clean upstream reference and implement fixes on `ris`.

npm 12 reads `allow-git=root` from `assets/.npmrc`, permitting Git dependencies directly declared by the project. The `allowScripts` entry for `github:RisPNG/super-image-cropper` in `assets/package.json` approves that source's preparation script, which builds its worker. These project permissions apply to the existing `npm install` and `npm ci` commands.

Open [localhost:4000](http://localhost:4000). The component showcase is at `/dev_panel/layout_test`.

Development uses `elixirbits_template_dev` and tests use `elixirbits_template_test`, with PostgreSQL credentials configured in `config/dev.exs` and `config/test.exs`. Set `DATABASE_NAME` or `TEST_DATABASE_NAME` to use another database. PostgreSQL connections use UTC, while forms and calendars apply the requested display timezone.

Seeds register navigation entries and the `superuser` role, preserving existing grants and disabled navigation entries. They also provide these default accounts:

| Email | Password | Access |
| --- | --- | --- |
| `admin@elixirbits.dev` | `admin` | `superuser` role, with SU access |
| `user@elixirbits.dev` | `user` | No roles, with access to public pages |

New seed accounts are confirmed, and optional profile fields are left empty. The private, system-only `:seed_with_password` Ash action on `User` hashes the requested seed passwords and confirms the new accounts without changing the eight-character minimum for regular registration, password changes, or password resets.

Repeating the seeds preserves existing accounts, profile values, passwords, and the normal account's roles. Administrator accounts receive the `superuser` role when it is missing, keeping their other roles. Run the seeds again with:

```sh
mise exec -- mix run priv/repo/seeds.exs
```

To provision another administrator, set `ELIXIRBITS_ADMIN_EMAIL` and `ELIXIRBITS_ADMIN_PASSWORD` before running the same command. The password is required only when creating that account. An existing account keeps its password and receives the `superuser` role. After signing in as an administrator, open `/admin/users`, `/admin/roles`, or `/admin/organization`.

## Permissions and administration

Register each protected page in `Sitenav` and give its LiveView an `on_mount` declaration for `LiveUserAuth` with `{:require_page_access, "/your/page"}`. Apply `AccessControl.ResourcePolicies` to its Ash resource with the same `path:`. Declared protected pages without a navigation entry are denied, and disabled entries or branches remain inaccessible to superusers. Home and the component showcase are public routes. Their navigation entries control where links appear.

Read (`4`), create (`2`), update (`1`), and delete (`8`) are independent bits. Page access requires read, so levels without that bit are invalid, except for no access (`0`) and SU (`16`):

| Permission Level | Access |
| --- | --- |
| 0 | No access |
| 1 | Invalid (no read) |
| 2 | Invalid (no read) |
| 3 | Invalid (no read) |
| 4 | View page and entries |
| 5 | View + Update entries |
| 6 | View + Create entries |
| 7 | View + Create + Update entries |
| 8 | Invalid (no read) |
| 9 | Invalid (no read) |
| 10 | Invalid (no read) |
| 11 | Invalid (no read) |
| 12 | View + Delete entries |
| 13 | View + Update + Delete entries |
| 14 | View + Create + Delete entries |
| 15 | Full CRUD |
| 16 | Full CRUD + Special Custom Access |

The numbers are combinations, rather than an increasing authority scale: level `6` permits creation but cannot update, while level `5` permits updating but cannot create. Grants from multiple roles combine by bitwise union, so `5` and `6` together produce `7`. SU dominates the result as `16` and is separate from the standard bits.

Use `Permissions.can?(permissions, path, capability)` with `:create`, `:read`, `:update`, `:delete`, or `:su` for capability checks. For a special rule requiring the exact effective SU level, use `Permissions.perm_level(permissions, path) == 16`, then define what that protected operation permits. Level `15` alone cannot satisfy an SU rule. Public access grants read only, but roles can add capabilities on public pages. Disabled pages and branches still deny access.

User and role update screens use `/admin/users/:id/update` and `/admin/roles/:id/update`, with the `:update` LiveView action. Shared record controls use `<.action_button action={:update} />`.

The role creation screen uses `/admin/roles/create` with the `:create` LiveView action.

Profile updates cannot change role membership. Assigning roles requires permission to update users and SU authority over role administration. Changing permission grants or navigation rules also requires SU, while updating a role's name and description requires update authority. Role codes are stable identifiers. A role cannot be deleted while assigned to an account. Authorised role details and permission grants are saved in one Ash action.

Nested address changes also need the relevant capability. Updating an existing parent requires update permission. Adding an address additionally requires create, and deleting a saved address additionally requires delete. Discarding an unsaved address requires only the parent form's save permission. A new organisation uses create permission for its initial save and address creation.

The organisation screen stores one application's identity, currency, locale, timezone, contacts, and addresses. Public navigation receives only its name and regional metadata. Contact details and addresses require settings access. Addresses belong to exactly one user or the organisation, with ownership supplied through the parent relationship.

## API documentation

Open `/api/json/scalar` for Scalar's API reference. `ScalarPlug` runs in the Phoenix endpoint before the router and loads the OpenAPI specification from `/api/json/open_api`, which `ElixirbitsWeb.AshJsonApiRouter` generates through AshJsonApi and OpenApiSpex. The HTML renderer sits outside the JSON-only API pipeline so ordinary browser navigation works. Other paths pass through to the router, and the specification remains available independently of the renderer. The router currently declares `domains: []`, so its specification has no API operations until JSON API domains and routes are configured. Change those Ash declarations when exposing an API rather than maintaining a separate specification for Scalar.

Use [`scalar_api_plug`](https://hex.pm/packages/scalar_api_plug) temporarily. [Scalar's official Elixir integration page](https://scalar.com/products/api-references/integrations/elixir) links to [Tuist's `scalar_plug`](https://github.com/tuist/scalar_plug), which remains the preferred integration. As checked on 14 October 2026, its latest published release is [`0.2.0`, dated 14 July 2024](https://hex.pm/packages/scalar_plug/0.2.0), and its [latest upstream source commit](https://github.com/tuist/scalar_plug/commit/1ecee5c7dca3386113fc0298d2abcb052a68d14a) is also from that date. Treat it as unmaintained for now. When `scalar_plug` receives an update and active maintenance resumes, inspect the release source, verify this integration, and switch to it. Both packages define `ScalarPlug`, so replace the dependency rather than installing them together.

The installed [`scalar_api_plug` 0.3.0 renderer source](https://github.com/Aroy-Art/scalar_plug/blob/ffcfc46369e5a6fac519b167edf9831062a3a3fd/lib/scalar_plug.ex#L142-L154) hardcodes `https://cdn.jsdelivr.net/npm/@scalar/api-reference` and does not expose a script URL, version, or integrity option. Browser rendering therefore requires CDN access, and the JavaScript can change independently of `mix.lock`. Keep that limitation visible when reviewing package updates or switching integrations. The application uses the plug's native renderer with static options and does not inject a second script to override its asset loading.

Leave the plug's `configuration` at its empty-map default for now. The 0.3.0 renderer replaces JSON double quotes with apostrophes, while the inspected [Scalar 1.74.0 browser bundle](https://cdn.jsdelivr.net/npm/@scalar/api-reference@1.74.0) parses that attribute as JSON. Nonempty configuration maps therefore fail to parse. Recheck the package's serialisation before adding Scalar options, and keep the title and extra HTML trusted and static.

## Shared components and utilities

`CoreComponents` provides forms, actions, cards, collapse panels, entry panels, tables, and inputs, including native selects, searchable comboboxes, radios, switches, password visibility, and upload previews. Its imported `<.form>` disables browser submission validation by default and delegates native form behaviour to Phoenix. Colours live in `assets/css/app.css`. Fixed form grids use explicit tracks and `subgap` for aligned transparent fields. The showcase demonstrates the supported input modes and interactions, with select and combobox examples together under Core Inputs. Separate selection controls let the combobox show multiple tags while the native select remains a single-choice dropdown.

Application `put_flash/3` calls use the shared flash lifecycle imported by `ElixirbitsWeb`. Each notice replaces the previous flash, including across severity changes and redirects, while preserving structured payloads. Repeating a notice restarts its dismissal timer. Flash backgrounds use the central `flash-surface` theme utility for an opaque base and a severity tint.

Client controls target current Chromium, Firefox, and Safari releases. Colour and themed calendar popovers share one native CSS anchor positioning rule for placement and viewport width constraints, with a 0.25rem vertical gap and no horizontal offset from their triggers. Each control retains its own width and height limits. Their hooks connect the existing widgets to native popovers without measuring layout or adding JavaScript positioning fallbacks. Combobox panels use scoped CSS anchors and fixed positioning to escape scrolling containers, including the account menu. Petal's hook chooses whether to open above or below and caps the list height, while CSS handles horizontal placement and viewport width limits. Their appearance stays in the central theme. Native selects use the browser's customisable picker where supported and retain its standard picker elsewhere. Calendars retain the themed Vanilla Calendar interface, with native outside-click and Escape dismissal. Keyboard arrows enter the calendar, and Tab follows the browser's focus order. Calendar focus never changes `HTMLElement.prototype`.

Telephone inputs keep separate country and national-number controls. The country combobox uses Petal's trigger variant and selected-content slot to show only the dial code. Its panel contains the searchable country labels, including dial codes, country names, and ISO codes. The small telephone hook reads the combobox's native select and composes the submitted number. Theme animation, clipped-text tooltips, the timer demonstration, and AshTypescript RPC support remain part of the template. Timers share one second-based scheduler and refresh when the page becomes visible.

### Interface patterns

The application's existing pages, layouts, shared components, and central theme define its interface patterns together. [Layout Test](http://localhost:4000/dev_panel/layout_test) demonstrates shared component behaviour and states. Follow the existing page pattern that fits the new page's purpose and action hierarchy, and implement reusable colour and control behaviour through the central theme and existing component APIs.

- Use primary for the working canvas and the existing overlay system for surface hierarchy. `shell-surface` joins the header and sidebar, `panel-surface` groups form sections and cards, and `inset-surface` layers nested detail over its surrounding surface. These shared utilities use dark overlays in light mode and light overlays in dark mode. Keep ordinary text on `text-content` and `text-subcontent`, and use adaptive `border-outline` for controls and meaningful boundaries rather than outlining every grouping.
- Keep boxed buttons, section tabs, and collapse summaries at a 44px minimum height with vertically centred `text-sm` labels. Buttons without a variant use the standard contextual fill, with `aria-pressed` or `aria-selected` adding a 12% brand tint for the active state. Primary actions retain the solid brand fill, neutral buttons use transparent backgrounds with quiet outlines, and danger actions use a 12% error tint. Hover feedback uses the existing dark overlay. Metadata badges are compact `text-xs` pills with a 12% background tint and ordinary content text. Badges and selected states do not need the visual weight of primary actions.
- Use `variant={:text}` for standalone recovery actions and subordinate alternatives, whether they navigate to another page or perform an action in place. Links embedded in sentences retain their inline presentation. Navigation occupies a reserved sidebar with sentence-case labels, expandable branches, and a compact collapsed rail. Current links use a rounded 14% brand tint with ordinary content text, and native current-page and expanded-state attributes describe the selection. The top-right account popover holds the user identity, timezone preference, and sign-out action. Keep the sign-in form's recovery action beside Remember me, one prominent Sign in button, and the magic-link and account-creation alternatives as text actions.
- Use the shared input and upload components for field presentation, disabled and text modes, picker behaviour, tag clear controls, and transparent thumbnail previews. Keep field labels and errors attached to their controls. Navigation and select indicators use the same Heroicons micro chevron, with size and theme colour chosen for their context.
- Use `<.collapse>` for expandable panels. Its `summary` slot accepts header content, its default slot holds the revealed content within the same surface, and a chevron on the right indicates the native open state. Keep native disclosure behaviour and align side-by-side control rows at the top so opening one item leaves closed neighbours and ordinary buttons at their normal height. The component owns body spacing and preserves the browser's open state across LiveView updates. Pass `open` for initial expansion and `name` to group panels using native exclusive expansion.
- Use explicit fixed grid tracks, consistent spacing within each form section, and theme-based separator lines between distinct groups of controls. Filled or bordered grid children retain visible gutters; transparent form fields use the shared `subgap` conventions.
- Preserve compact presentation for inline clear icons, the segmented theme toggle, calendar dates and event chips, dropdown options, and metadata badges. Status and calendar colours retain their semantic meaning. Listing headers and alternating unselected rows use subtle dark overlays in light mode and light overlays in dark mode. Selected rows keep their brand tint.

Transparent fields retain their surrounding surface, including its overlays. Shared dropdowns, the colour picker, and date/time picker use `bg-surface` to paint an opaque copy of that visible surface through the existing theme calculations. Copy the surface rather than inheriting a transparent background. Panel and inset surfaces capture the colour beneath their layer, and unselected buttons use `bg-control` to match the nearest enclosing colour. This applies to cards and collapses alike. On the page canvas, `bg-control` adds a subtle 3.5% neutral fill, darkening in light mode and lightening in dark mode. Selected buttons retain their brand tint. Dropdown options use `option-surface` for selected, keyboard-active, and hovered states, darkening in light mode and lightening in dark mode. Calendar navigation glyphs inherit `content` through the existing Heroicons mask. Cinder's shared pagination wrapper gives both the upper and lower controls the same vertical padding around the results.

Navigation icons come from the optional `Sitenav.icon` database field. Only entries without a parent display it, including the Home link in the collapsed rail. Empty values use `hero-slash`, and child entries ignore their stored icon. A top-level entry with a nil URL opens a group, while an entry with a URL navigates to that path. The resource derives its supported names at compilation from the installed Heroicons and Tabler asset files, covering every style exposed by the existing plugins. Dependency updates that add or remove icon files trigger recompilation. Heroicons use `hero-` names with optional `-solid`, `-mini`, or `-micro` suffixes. Tabler uses `tabler-` names with an optional `-filled` suffix. Tailwind scans application source, seeds, and migrations rather than the validation catalogue, so the stylesheet includes only referenced icons. Write complete icon names in those source files and rebuild assets through the normal deployment workflow when introducing a new icon. For example, changing a seed entry to `icon: "tabler-chart-bar"` includes that icon in the next asset build. Home-page shortcut cards retain their separate destination illustrations.

Check changed pages in both themes, including hover, selected, disabled, keyboard, and expanded states. Forms retain their own field arrangements, and authentication forms retain their narrow column. Cinder applies these interface patterns through `ElixirbitsWeb.CinderTheme`. Package-owned AshAdmin, Scalar, LiveDashboard, and mailbox pages retain their upstream presentation.

```heex
<.collapse id="billing-protection">
  <:summary>
    <span>Billing protection</span>
  </:summary>
  <p>Fraud monitoring is enabled.</p>
</.collapse>
```

Page titles use `<.header level={1}>` directly on the canvas, section headings use the default level 2, and nested specimens may use level 3. Header-only card wrappers are unnecessary. Listing pages place their heading, unboxed filters, and table directly in the working area. Tables retain a rounded frame, shaded header, and alternating unselected rows. Form and detail cards, home shortcuts, Cinder list and grid items, and listing frames share `shadow-card`. Its quiet edge follows the theme's outline direction, dark in light mode and light in dark mode, with a soft dark shadow beneath it. Primary, neutral, and danger buttons use the smaller `shadow-button`, with a faint light top edge and dark depth. Pressed and disabled buttons flatten. Both shadow definitions reuse the existing dark and light colours through Tailwind's native shadow utilities, preserving focus rings. Default buttons, text actions, section tabs, inset panels, and collapses stay flat. Fields and dropdowns retain their existing styling, including the flat page-size selector. The component showcase keeps its colour catalogue visible and its detailed overlay experiments in native collapses.

Wrap each Cinder collection in an element with a unique `id` and `phx-hook="CinderPagination"`. The hook adds ellipses for omitted page ranges and mirrors Cinder's page information and navigation beneath its filter and sort controls. Both navigation bars use Cinder's existing events and page state. The optional page-size selector stays below the results. This application hook depends on Cinder's rendered markup, so check it when upgrading Cinder.

Every application form and input must use the imported `<.form>` and `<.input>` from `CoreComponents`, including selects, comboboxes, textareas, hidden fields, and file uploads. Call the core component by its qualified name in isolated component tests. Keep native form controls, Phoenix form rendering, Petal's combobox, and LiveView upload rendering inside the core implementation. If the shared API cannot preserve a field's behaviour or accessibility, discuss the missing capability and proposed core change before implementing a workaround.

This rule covers application-owned forms and inputs. Cinder filters and selection controls, AshAdmin, LiveDashboard, and the development mailbox remain owned by their installed packages. Core's native controls and framework-generated hidden fields are also part of their owning renderer. The source boundary test checks application templates and component calls to prevent new bypasses without changing dependency internals.

Use `type="radio" variant="card"` for compact radio cards with an optional description below each title. Radio options accept `{label, value}` or `{label, value, description: "Details", disabled: true}` tuples in either variant. Each card remains a label for a native radio, preserving single selection within its group, keyboard navigation, required validation, and disabled behaviour. The shared input display modes still apply, and the card appearance comes from the project's CSS. The Core Inputs showcase places radio cards immediately after the ordinary radio group.

```heex
<.input
  field={@form[:compute_plan]}
  type="radio"
  variant="card"
  label="Compute plan"
  options={[
    {"8-core CPU", "8-core", description: "32 GB RAM"},
    {"6-core CPU", "6-core", description: "24 GB RAM"},
    {"4-core CPU", "4-core", description: "16 GB RAM", disabled: true}
  ]}
/>
```

Use `<.input field={@form[:choice]} type="select" options={@options} />` for a native single select and `type="combobox"` for a searchable combobox. Both accept normal label/value option tuples and `multiple` for multiple selections. Multiple selects and comboboxes share Petal's searchable combobox renderer and hook. Multiple selections appear as removable tags below either field through the project's CSS. Comboboxes and multiple selects also accept `clearable` and `max_items`. Create independent field groups with `to_form/2`. The Petal wrapper uses the explicit input `id`, or the form field's ID by default. Its visible control uses that ID plus `"-input"`, and its submitted native select uses the same ID plus `"-select"`. External labels must target the visible control.

Single native select styling uses `.input-native-select` in `assets/css/app.css`. Its font, height, padding, border, and chevron match the combobox. CSS `appearance: base-select` and `::picker(select)` give the native dropdown the same theme colours, option spacing, hover and selected surfaces, and selected-option checkmark. The browser handles opening, keyboard selection, dismissal, and form submission. Browsers without these customisation features keep their standard option picker, so the single-select dropdown appearance depends on browser support. Multiple selects use the shared Petal dropdown and tags. See the [MDN customisable select guide](https://developer.mozilla.org/en-US/docs/Learn_web_development/Extensions/Forms/Customizable_select).

Selections trigger the enclosing form's `phx-change` event through the native select. Combobox filtering and keyboard navigation run in Petal's hook against the supplied options, so static choices require no search event handler or component update. Permission and timezone choices use `clearable={false}` to retain an explicit choice. Permission changes are processed alongside role form validation and restricted to the current superuser grant. Core includes an empty hidden value before each multiple select, so clearing every choice submits `[""]` instead of omitting the field. AshPhoenix removes empty array values natively. Map-backed forms strip those empty strings before merging selection lists, while omitted disabled fields retain their previous values.

Petal supplies the combobox, listbox, and option roles, along with the visible control's expanded state and active option. Core's label targets the actual textbox, and `label` or `aria-label` supplies its accessible name. Combobox `aria-labelledby` and `aria-describedby` describe the core field group, including its disabled display. Native select attributes apply to the select itself.

The Petal integration uses the qualified `PetalComponents.ComboBox.combo_box` component and imports the named `PetalComboBox` JavaScript hook directly from `deps/petal_components/assets/js/petal_components.js`. Only that Petal hook is registered with LiveView. Selection, keyboard, and disabled-state behaviour come from the upstream hook without local modifications. The upstream module also initialises a global accordion listener, including when using a named import. This side effect is accepted so the application uses the dependency's own JavaScript. The `>= 4.17.1` dependency constraint allows newer releases, with the installed version recorded in `mix.lock`. Combobox styles live in `assets/css/app.css` and use the existing theme colours. The application does not import Petal's component collection or global stylesheet.

Use `rounded-default` for ordinary controls and panels, and `rounded-full` for pills and circles. The shared `--radius-default` is 0.5rem, while `--radius-workspace` is 1.5rem for the working canvas's connection to the shared header and sidebar. The shared `workspace-canvas` anchors that corner beneath the header using CSS positioning and the surrounding shell colour, so it remains visible while the document scrolls and follows the expanded or collapsed sidebar. Document scrolling retains Phoenix's navigation history restoration. Both rounding classes also support SVG rectangles. SVG full rounding reads the rectangle's numeric `width` and `height` attributes and uses half the shorter dimension, capped by `--radius-full`, so its corners match HTML pills instead of stretching into an ellipse. Omit rounding classes for ordinary square elements. Central calendar styles still reset selected corners to zero where a range joins an already rounded date button.

The palette uses primary for the canvas and overlay-derived grouping surfaces, while secondary remains available for tooltips, tags, and disabled checked controls. Cards, nested panels, and collapse groups use the shared overlay surface utilities. Layout-test disclosure headers use vertically centred text with a 44px minimum height and a compact chevron hover target. The Local and Ecosystem tabs use the default button appearance, with their active appearance driven by `aria-selected`. Their control rows align items at the top, so expanded choices leave neighbouring closed controls and buttons at their natural height. The theme toggle uses three fixed grid columns over an inset track. Its selected control and the current navigation row use a brand background with a 14% opacity overlay and ordinary content text. Neutral outlines use `--color-outline`, which mixes the current surface towards opaque black at 22% in light mode and opaque white at 24% in explicit and system dark modes. Shared `bg-*` utilities publish that surface so field, button, and panel borders adapt to their background. The central `--outline-target` and `--outline-strength` control that calculation for borders, separators, SVG strokes, and captured `bg-outline` fills. `--color-content` and `--color-subcontent` are fixed palette values for each theme: dark main and muted text in light mode, and light main and muted text in dark mode. Their colours do not change with individual backgrounds or overlays. Transparent controls inherit their surrounding surface for outlines and floating-label cutouts. Use `text-content` for main text, `text-subcontent` for secondary text, `border-outline` for borders, `divide-outline` for separators, and `stroke-outline` for SVG grid lines. SVG colour classes follow the same approach: put a semantic `fill-*` on the group containing the shape and its text, then use `fill-content` for the theme's main foreground. Shapes inherit the group's fill, and transparent groups retain their surrounding background context for outlines. Surface tracking stays inside the shared stylesheet; components use ordinary Tailwind colour classes. Focus, errors, checked controls, and colour-coded calendar events keep their semantic theme colours.

Native range-slider thumbs receive the adaptive outline calculation centrally through separate browser-specific rules. Calendar thumbs use ordinary `bg-primary` and `border-outline` utilities without applying the calculation helper themselves.

The palette pairs Royal Amethyst (`#7E49B3`) with Nox Noir (`#141414`) dark surfaces and a white working canvas with softened Steel Mist overlays in light mode. Brand backgrounds share the exact amethyst colour in light, explicit dark, and system dark modes. Info stays blue, success green, warning amber, and error red, with midtone colours for dark content in light mode and deeper colours for light content in dark mode. Each colour has one `--color-*` value per theme, shared by backgrounds, text, icons, borders, focus indicators, and SVG fills. Status surfaces use the existing `text-content` and `text-subcontent` foregrounds. For example, `bg-error text-content` presents a filled error message, while `text-error` uses the same error colour for a validation message on a neutral surface. Content and subcontent still use the same theme palette values for backgrounds, text, SVG fills, and strokes. `bg-content` and `bg-subcontent` are dark in light mode and light in dark mode, regardless of the surrounding surface. These fills do not automatically invert nested text.

Use `text-content-inverse` or `text-subcontent-inverse` when a surface needs the opposite theme's foreground. They use the dark theme's light text in light mode and the light theme's dark text in dark mode, including system dark mode. For example, `bg-content text-content-inverse` pairs a content fill with contrasting main text, and `bg-subcontent text-subcontent-inverse` does the same for muted text. Unshaded, opaque brand surfaces use `text-content-inverse dark:text-content` for main text and `text-subcontent-inverse dark:text-subcontent` for secondary text, so their foregrounds match dark mode while the shared brand colour stays unchanged. The opacity and light-overlay thresholds below determine when those foregrounds change. Solid brand SVG labels use `fill-content-inverse dark:fill-content`; outlined events retain the normal foreground. Normal `text-content` and `text-subcontent` retain their existing colours elsewhere. Inversion is an explicit foreground-class choice and does not change the theme or automatically follow a background or overlay.

The central `@theme static` declaration emits the shared palette, normal foregrounds, and inverse foregrounds. Each theme's content and subcontent values have one central source, and both foreground roles refer to those values. `--color-dark` and `--color-light` remain translucent black and white palette values controlled by the shared `--overlay-opacity` value. Use `overlay-dark` or `overlay-light` to adjust the saturation and lightness of an existing surface, including transparent fields. Combine an explicit fill with a modifier, such as `bg-primary overlay-dark` or `bg-brand overlay-light`, to publish the adjusted surface for adaptive outlines and floating-label cutouts. Transparent elements use the surrounding surface as their base. The adjustment paints the resulting background colour while background images, text, and icons retain their colours and opacity. Borders and focus rings remain opaque, with adaptive outlines following the adjusted surface. SVG groups use the same adjusted surface as their fill, with independent foreground fills preserving their labels. Calendar event hover adjusts the group containing the event shape and its text. A modifier applies once per element. Button hover and disabled states use the dark modifier. Select options use the shared option surface for hovered, keyboard-active, and selected states, darkening in light mode and lightening in dark mode. The shared `bg-*` utility resolves palette colours and the captured adaptive outline background. Shared outline captures preserve the parent's computed outline colour for `bg-outline` before it becomes a new surface, avoiding a circular colour reference. Radio dots and checkbox marks use `currentColor`, with checked brand controls selecting inverse content in light mode and ordinary content in dark mode. Checked switch thumbs use the equivalent background pairing. Disabled checked controls retain secondary fills and their normal or muted foregrounds. The progress bar reads `--color-brand` and `--color-dark` from the current theme when loading starts. All surface adaptation remains CSS-only.

The adjustment converts the visible starting colour to sRGB HSL and keeps its hue unchanged. Both modifiers move saturation towards `100%`, while dark moves lightness towards `0%` and light moves it towards `100%`. Strength `0` preserves the starting colour, and strength `1` produces black or white. Neutral greys remain neutral. For example, a starting colour with saturation `40%` and lightness `60%` becomes saturation `55%` and lightness `45%` under a `0.25` dark adjustment, or saturation `55%` and lightness `70%` under the equivalent light adjustment.

Bare `overlay-dark` and `overlay-light` use the shared `--overlay-opacity` default of `0.1`. Specify another strength with a bracketed decimal, such as `overlay-dark-[0.25]`, `overlay-dark-[0.5]`, `overlay-light-[0.5]`, or `overlay-light-[1]`. Text, icons, and focus rings remain opaque. Nested overlays of the same kind add their strengths, including through ordinary transparent wrappers, and cap the total at `1`. Each run captures its unadjusted starting colour and applies the combined strength to it, so nested adjustments match one adjustment at the same total strength. Four default layers produce combined strengths of `0.1`, `0.2`, `0.3`, and `0.4`. A new explicit background, an opacity layer that paints additional background, or an overlay of the opposite kind starts a new run. An opacity layer that adds no background paint preserves the run. Repeating a class on the same element applies it once, and different strength classes on one element follow the CSS cascade rather than adding. The layout test's overlay strength section compares dark and light values and their nested default runs.

For text on a dark overlay over brand, retain `text-content-inverse dark:text-content`. A light overlay over brand with a strength of `0.5` or more uses `text-content dark:text-content-inverse`, giving dark text in either theme. Weaker light overlays retain the brand's light foreground. Apply the threshold to the combined strength of nested overlays, so the fifth default layer switches to dark text and its descendants inherit that foreground. The `dark:` variant covers both the selected dark theme and the system dark theme. Muted text follows the same rule with `text-subcontent` and `text-subcontent-inverse`.

Use `overlay-opacity` to set background alpha to the shared `--overlay-opacity` default of `0.1`, or specify a decimal from `0.1` to `1` with an arbitrary class such as `overlay-opacity-[0.25]`, `overlay-opacity-[0.5]`, or `overlay-opacity-[1]`. Only the background changes. Text, icons, borders, and focus rings remain opaque, and alpha `1` makes the background fully opaque. Combining opacity with a dark or light modifier first composites the fill over its surrounding surface, then adjusts that visible colour at the configured strength. The modifier paints the adjusted result as an opaque colour. Adaptive outlines and floating-label cutouts use this resulting surface, while content and subcontent retain their fixed theme colours.

Nested `overlay-opacity` elements add their amounts to the same background source, including through ordinary transparent wrappers. Four default layers produce background alpha values of `0.1`, `0.2`, `0.3`, and `0.4`, capped at `1`. An explicit background such as `bg-brand` starts a fresh stack, so a nested `bg-brand overlay-opacity` starts again at `0.1`. Repeating the same class on one element applies it once, and multiple opacity classes on one element follow the CSS cascade rather than adding. The layout test's background opacity examples compare explicit values and show the four nested default layers. Brand backgrounds with alpha at or below `0.5` use normal `text-content` and `text-subcontent`, giving dark foregrounds in light mode and light foregrounds in dark mode. Above `0.5`, use the usual brand foreground pairs, `text-content-inverse dark:text-content` and `text-subcontent-inverse dark:text-subcontent`. Apply this threshold to the combined alpha of nested layers, so the sixth default layer switches to the usual brand foregrounds and its descendants inherit them. A light adjustment of at least `0.5` still takes precedence and uses dark foregrounds in both modes.

Use `CoreComponents.button` without a variant for standard controls, including toggles and section tabs. Use `variant={:text}` for a subordinate text action, `:primary` for the preferred action, `:neutral` for an outlined action, and `:danger` for destructive confirmations. These choices describe visual emphasis. A text action may navigate through `navigate`, `patch`, or `href`, or perform an in-place action through an event, and the component retains the appropriate HTML element. Default controls use `aria-pressed` or `aria-selected` when they expose selected state. Labelled buttons and square `action_button` controls share their text, background, border, and hover colours through the central button utilities. Cinder actions use the same utilities. Table action columns fit their contents, so a label such as "Inspect" has room alongside square icons. Route links can use `<.link>` where they belong within prose or navigation.

Record action buttons use `:create` with the default tooltip "Add new", `:read` with "View", and `:update` with "Update". Use `action={:create} tooltip="Add"` when adding a nested form entry. Tooltips also provide the accessible label. The other supported actions are `:save`, `:send`, `:archive`, `:delete`, and `:back`.

The shared tooltip behaviour reveals the full rendered text of a clipped label only while its content overflows. Labels that fit do not repeat their text in a tooltip. This applies to navigation, truncated values, and clamped text, and updates after edits, page patches, and resizing. Existing explanatory tooltips keep their intended descriptions. Keyboard focus supports clipped controls and Escape dismisses the tooltip; masked passwords, file inputs, and scrollable regions do not expose automatic value tooltips.

Status badges use the compact `status-pill` theme utility with `text-xs` labels and a 12% background-opacity overlay. Add a shared semantic background and ordinary content text, such as `status-pill bg-success text-content` for a ready status. The same colour token supplies the tint without a separate badge palette.

Native file fields and LiveView upload controls share the file-input CSS. Their filename text uses equal vertical padding to centre its 20px line within the 44px bordered field, and the upload icon centres on the field as well. The upload component owns each transparent thumbnail frame and its tag-style remove icon, which appears inside the top-right corner on frame hover or keyboard focus. Use `thumbnail_class` to size the frame and the `preview_caption` and `pending_caption` slots for filenames. With previews enabled, single and singles thumbnails display those captions at the top left inside the frame on hover or keyboard focus, while multiple displays them below the frame. Tag preview layouts use those captions as chip labels. With previews off, single and singles show the active filename inside the input and keep file metadata mounted without visible preview chips. Multiple keeps its filename chips.

File inputs default to `preview={false}` and `editor={false}`. Set `preview={true}` for built-in image and native PDF previews. Use `stored_preview` and `pending_preview` slots only when the media itself needs custom rendering. `selection="single"` picks one file and replaces its saved preview until it is cancelled or saved. `selection="multiple"` selects several files together and shows their saved and pending files together. `selection="singles"` adds one file at a time and shows one preview. With previews enabled, its input displays the collection's file count, and the preview reveals its filename at the top left and borderless chevrons inside its sides on hover or keyboard focus. Its current/total position appears at the bottom right on hover. With previews off, the active filename appears inside the input, followed by its current/total position and the number input's stacked chevrons. Positions start at 1, with `0/0` for an empty collection. Saved files and locally prepared files share the count, and an edited replacement counts once. Omitting `selection` retains the mode inferred from the upload configuration or native `multiple` attribute.

To place a single or singles preview elsewhere, set the input's `preview_id` to the ID of a `<.file_preview>` destination. The input still owns its upload configuration, stored files, rendering options, and media/caption slots. Phoenix's portal keeps that collection synchronised at the destination and leaves the input in its original form. The destination can sit outside the form and sizes its preview through `class`, such as `size-20` or `h-44 w-full`. Detached thumbnails fill that size; `thumbnail_class="h-full w-full"` on the input is optional. Keep the destination mounted while its ID is linked, including when Preview is off or the input uses a hidden mode. Empty or hidden preview content hides the destination's visual space. Multiple previews remain inline. Without `preview_id`, the same collection stays beside its input.

The image editor accepts `true` for an unconstrained crop, `%{width: 512, height: 512}` for an exact output size, or `%{ratio: 16 / 9}` for an aspect ratio without fixed output dimensions. A constraint map enables the editor. Editing requires `preview={true}` and `selection="single"` or `selection="singles"`. Configure single uploads with `max_entries: 1`; singles uses the desired pending-file limit while keeping its picker limited to one file per selection. Leave `auto_upload` false when editing. Native file fields use the same editor; give a native singles field an array name such as `images[]` for multipart collection parameters. Image preparation remains in the browser until Save, and animated GIFs retain their animation. PDFs bypass the editor.

When editing is enabled, PNG, JPEG, GIF, and WebP previews expose a bottom Edit action on hover or keyboard focus. It reopens the editor for a pending file or an existing saved image. Confirming an edit replaces that pending file, while cancelling leaves it intact. Editing a saved image queues its replacement for Save and leaves the original saved data intact until submission. A LiveView form receives those associations in `<upload_name>_replacements`, a map from the new entry reference to its original stored URL, so its Save handler can replace that stored item. `<upload_name>_order` lists queued entry references in preview order so re-editing an earlier file preserves its position after Save. The existing single-avatar form already replaces its saved image through its normal Save flow.

The layout test uses one upload input with single, singles, multiple, preview, preview layout, and editor controls. Its single/singles preview sits in a separate region outside the upload form, while multiple previews stay inside the input. Single mode allows one pending file; singles and multiple allow three, with singles choosing them individually. Save or cancel pending files before switching selection mode, because LiveView needs an empty queue to change its upload configuration. Other display options retain the current selection. Turning Preview off shows the active filename inside single and singles inputs, or filename chips in multiple mode, and turns editing off. Switching to multiple also turns editing off. Saved files are session-only examples: saving a single file replaces them, while saving new singles or multiple files appends to them. Re-editing a saved file replaces that item in its existing position when saved. The Core Inputs file specimen uses the same component as a native picker without a LiveView upload configuration. Its demo Save does not transfer file bytes; a native multipart form can instead send its prepared File to an HTTP controller.

Cropper.js 2.3.0 provides the editing interface through its native custom elements, and the maintained Super Image Cropper fork prepares the accepted image. The fork reads the image transform and selection to apply the same crop to static images and GIF frames. It owns exact output resizing, GIF frame composition, loop counts, delays, transparency, encoding, and cancellation cleanup. Its GIF encoder uses a reserved transparent palette index so opaque black remains opaque. The application consumes its Blob output directly and has no separate GIF worker implementation. Esbuild preserves dependency licence notices in linked `.LEGAL.txt` files, which must accompany the generated JavaScript assets.

The shared HEEx image-editor template owns the dialog, buttons, status, and Cropper markup. JavaScript clones those inert native nodes when editing starts, configures the source and constraints, and delegates to the installed engines. The active dialog lives outside LiveView's patched DOM and is removed when editing ends. Editor dependencies remain lazy-loaded.

```heex
<.input
  type="file"
  upload={@uploads.display_pic}
  stored={List.wrap(@existing_display_pic)}
  preview={true}
  preview_id="display-picture-preview"
  editor={%{width: 512, height: 512}}
  preview_as="thumbnail"
  thumbnail_class="h-full w-full"
/>
<.file_preview id="display-picture-preview" class="size-20" />
```

PDF previews use the browser's native document viewer in a titled iframe, with an open-document link inside the frame. The browser supplies its own zoom, scrolling, password prompts, and error display. If inline viewing is unavailable, the frame shows a message and the same link. `UploadPdfPreview` assigns the saved file URL or pending upload Blob URL, and converts saved PDF data URLs to Blob URLs for the open action. It retains temporary URLs while the viewer is present and revokes them on removal. Tag mode hides the media without replacing its hook. PDF workers, canvas rendering, and packaged PDF rendering assets are unnecessary.

Number fields use divided up/down chevrons alongside the editable native input. The controls call the browser's `stepUp()` and `stepDown()`, preserving `min`, `max`, and `step`; disabled, read-only, and `step="any"` fields cannot step. In text modes, the chevrons appear on value-row hover or keyboard focus.

The `text` and `text-enabled` input modes use plain values with stacked labels. Calendar, colour, file, select, and telephone controls keep their pickers, and colour values and native file values update after selection. Passwords appear as editable plain text without a visibility button. Checkbox displays “{label} is enabled” or “{label} is disabled”, and switch displays “{label} is on” or “{label} is off”; clicking the sentence or pressing Space while focused changes the native state. Without a label, each shows its state word alone. Radio shows only its selected value and keeps its native choices hidden for submission. Live uploads remain editable in both text modes and retain their previews and clear controls. The `text-disabled` mode keeps its plain read-only display and hidden submission controls, including the current checkbox/switch state sentences.

`CalendarComponents.calendar/1` renders day, week, month, year, schedule, and resource views. It accepts plain event maps, converts UTC datetimes to the display timezone, clips events across local days, and emits `calendar_change` events for navigation and selection. Timed event controls support keyboard activation. `LiveTimer` displays elapsed or countdown time from an absolute `data-target` datetime.

`CoreUtils.Resource`, `Search`, and `Parse` handle Ash metadata, relationship loads, searchable options, nested sequence values, and typed input conversion. Datetime conversion preserves microseconds by default and supports explicit precision.

### Colour inputs

`CoreComponents.input` with `type="color"` renders a square colour swatch beside an editable value and searchable colour-space selection. Elixir's `Color` library supplies parsing, conversion, gamut mapping, and serialisation. The ten native output formats are HEX, RGB, HSL, Lab, LCH, OKLab, OKLCH, XYZ D50, XYZ D65, and CMYK. RGB and HSL include transparency and accept pasted RGBA and HSLA aliases. `CoreUtils.Color.options/0` supplies the shared choices. The named text field submits the selected syntax. The combobox's auxiliary native select records form selection state, while the colour string remains the stored value. The picker has no submitted name. Existing stored strings display in their own format first. Text modes keep their stacked labels, and read-only modes show the converted swatch, value, and current space while retaining their existing submission rules.

The text value can be edited or replaced with any supported format. On blur, a shared LiveView event validates that value and selects its detected format without rewriting the text. For example, pasting an OKLCH value while RGB is selected changes the format to OKLCH when the field loses focus. Native formats use their CSS function or `color()` notation, such as `lab(65 20 30)`, `color(xyz-d50 0.2 0.3 0.4 / 0.5)`, and `device-cmyk(0% 50% 100% 0%)`. Elixir produces the sRGB swatch and picker projection while preserving the original source. Incomplete drafts keep their current format while typing, and invalid values remain visible with a field error. Submission waits for pending validation or conversion, and explicit space choices also validate the pending value. A vertical divider separates the boxed value from the selector.

Only the square swatch opens the vanilla-colorful RGBA picker. It appears in a native auto popover beside the swatch, with saturation, hue, and alpha controls. Escape and outside clicks dismiss it. Opening or synchronising the picker does not change the value. The picker operates in sRGB and emits integer RGB channels when edited, so deliberately selecting a colour there replaces an out-of-sRGB source with the chosen sRGB colour. Picker interaction and its swatch update locally while Elixir converts the chosen RGBA value into the selected text format. Alpha stays precise during hue or saturation edits and changes when the alpha control is edited. Central CSS styles the picker frame, checkerboard, pointers, and keyboard focus with the shared theme; the library supplies the intrinsic colour ramps.

The space selector uses Petal's searchable combobox with a 4rem selector width, keyboard selection, and the core dropdown theme. Opening or clearing its search shows every space, and typing filters the labels locally. The selected field uses normal core combobox text styling, with the text cursor and an unchanged background on hover. Disabled and read-only entries expose no selection actions. `CoreComponents`' shared input mount hook handles colour validation, conversion, and detected-format selection for every application LiveView, so callers need no extra event handlers. These colour operations require a server round trip. The browser hook ignores obsolete replies, retains newer drafts, and applies each accepted reply's format to the combobox's native select and displayed label.

Format changes use Elixir's native converter and serializer. The shared mount hook retains each field's precise source separately from its latest formatted text, so changing formats does not compound serialisation rounding. Lab and LCH use native D50 white-point adaptation, and bounded sRGB formats use native OKLCH gamut mapping. The native serializer rounds decimal output to four places and RGB output to whole channel bytes. HEX uses 8-bit channels, so selecting it can round transparency or map colours outside sRGB into that smaller colour range. For example, transparency `0.5` becomes hex alpha `80`, equivalent to `128/255`. Saving stores the selected text representation, including any conversion loss in that representation.

Use `Elixirbits.CoreUtils.Color` as the Ash attribute type for persisted colour fields. It validates the supported numeric colour notations with the native parser, preserves the selected string, and maps to PostgreSQL `text`. Resource actions apply that validation through normal Ash casting. The layout showcase uses the same type to validate its LiveView form state before reporting a successful submission, and has no colour database field to migrate.

Supported literal syntax includes numeric channels, native CSS percentages and hue angles, and optional transparency. Spaces without a reliable native parser and serializer pair, including the former custom profiles, are excluded. Named colours, missing `none` channels, relative colours, and computed CSS expressions are outside this input's supported formats.

### Datetimes and user timezones

Persist instants with Ash `:utc_datetime`, `:utc_datetime_usec`, or `:datetime` with UTC timezone constraints. Application timestamps use these types, and database connections use UTC. A stored instant does not retain the timezone in which it was entered. API and background-job callers should supply a UTC `DateTime` or an ISO 8601 datetime with an explicit offset.

Dates and standalone clock times have different meanings. Store birthdays with `:date` and recurring local hours with `:time`. Neither is an instant that can be converted to UTC without additional information. User birthdays use `:date`. The user and organisation `timezone` fields store IANA names as preferences, rather than timezone-bearing datetime values.

The browser sends `Intl.DateTimeFormat().resolvedOptions().timeZone` through LiveSocket connect params. Every application LiveView receives `@user_timezone` through the shared `LiveUserAuth` mount hook. Resolution follows this order:

1. The signed-in user's saved timezone.
2. A valid timezone detected by the browser.
3. The organisation's timezone.
4. `Etc/UTC` when organisation settings are absent.

The initial HTTP render has no browser connect params, so it uses the saved preference or organisation fallback until LiveView connects. Calendar inputs update their displayed value when the resolved timezone arrives. An explicit user preference continues to take priority after reconnecting or navigating.

Signed-in users can open the top-right account menu and save a timezone. The searchable field keeps its unsaved choice across page updates and changes the stored preference only when saved. Choosing **Automatic (browser)** clears the saved preference. The dedicated `Accounts.update_user_timezone/3` action accepts only `timezone` and authorises the user's own active account. Changing other profile fields still needs the usual administration permission. Saving reloads the current page so its forms and calendars use the chosen timezone together.

Application AshPhoenix forms use native parameter transforms to interpret local datetime inputs on the server. Include these options when creating a form:

```elixir
AshPhoenix.Form.for_update(record, :update,
  actor: socket.assigns.current_user,
  context: %{shared: %{user_timezone: socket.assigns.user_timezone}},
  transform_params: &Elixirbits.CoreUtils.Resource.convert_form_datetimes/3,
  post_process_errors: &Elixirbits.CoreUtils.Resource.local_datetime_errors/3
)
```

The same options apply to `for_create` and `for_action`. Existing authentication contexts and form options remain alongside them. Construct the form before validating submitted local values: AshPhoenix casts constructor `params` before running its transform, so use its native `validate/2` before inspecting such initial params. Submission through `submit(params: params)` also validates and converts them. Datetime fields and arguments use native Ash metadata, including precision constraints. Values with explicit offsets keep their instant, and repeated validation does not convert an already converted instant twice.

Nested forms inherit the shared timezone and error processor, but their parameter transforms are configured separately. When adding editable datetime fields to a nested resource, retain AshPhoenix's generated relationship options and add the same native transform to that child's configuration:

```elixir
forms =
  resource
  |> AshPhoenix.Form.Auto.auto(:create)
  |> Keyword.update!(:children, fn opts ->
    Keyword.put_new(opts, :transform_params, &Elixirbits.CoreUtils.Resource.convert_form_datetimes/3)
  end)
```

Pass `forms: forms` to the constructor, using the actual relationship key and action. If the generated child options already contain a transform, retain it and compose datetime conversion in that native callback instead of replacing it. Construct or add child forms before validating their user inputs, as the current address editors do. Directly submitted new child params are converted before the child action runs. An initial child constructor's source is not a substitute for validation. Current address forms have no editable datetime fields.

Inputs bound to an AshPhoenix field obtain the timezone from the form's shared context. Pass `timezone={@user_timezone}` to standalone datetime inputs and `timezone={@user_timezone}` to calendars. Pass `user_timezone={@user_timezone}` to `Layouts.app` so the account menu shows the effective setting. Date, time, week, and month inputs keep their calendar or clock values.

Local clocks can be ambiguous or nonexistent when daylight-saving rules change. The server rejects those datetime inputs with a field error and preserves the entered text. An API caller can distinguish repeated clocks by supplying an explicit offset. `Parse.to_datetime(value, source_timezone: zone, on_invalid: :error)` returns tagged errors for invalid, ambiguous, and nonexistent input instead of choosing an instant silently.

Date searches over datetime fields must pass `user_timezone: socket.assigns.user_timezone` to `Search.search/1`. A date range ends immediately before the next local midnight, including days lasting 23 or 25 hours. Date-only `before` and `after` comparisons exclude the requested whole day, while their inclusive variants include it. An explicit datetime comparison uses its clock value.

For example, **09:30 in Kuala Lumpur becomes 01:30 UTC in storage and displays as 09:30 in Kuala Lumpur**. The same instant displays as 02:30 in London during British Summer Time. A birthday of **9 October remains 9 October** in every timezone. The component showcase submits its datetime example to a server-held UTC value and displays the result in the resolved user timezone.

Document numbers use a separate counter for each document type and full local date:

```elixir
Elixirbits.Numbering.next_number("INV", ~D[2026-10-09])
# "INV-20261009-00001"

Elixirbits.Numbering.next_number("INV", DateTime.utc_now(), timezone: "Asia/Kuala_Lumpur")
```

Allocation uses an atomic database increment. Formatting can change the prefix, suffix, separator, and padding, but cannot replace the allocated counter. Cancelled documents may leave gaps.

`Elixirbits.Scheduler` and `ElixirbitsWeb.Presence` are supervised and ready for application jobs and presence tracking. The scheduler starts with no jobs. The event log accepts both UUID and ULID resource identifiers, including ledger transfers.

### Browser validation messages

Messages such as "Please fill out this field" come from the browser's HTML constraint validation. Modules using `ElixirbitsWeb` import `CoreComponents.form/1` as `<.form>`, which renders `novalidate` by default to suppress those messages during submission:

```heex
<.form for={@form} phx-change="validate" phx-submit="save">
  <.input field={@form[:email]} type="email" label="Email" required />
</.form>
```

The shared component delegates rendering to `Phoenix.Component.form/1`, so Phoenix still handles form data, CSRF tokens, HTTP methods, multipart uploads, and slot values. Pass `novalidate={false}` to an application `<.form>` to enable browser submission validation for that form.

This default belongs to the shared application component. Native controls emitted inside core and forms rendered by installed dependencies follow their owning renderer's attributes. An input cannot enable `novalidate` for its form. Application templates must use the shared component instead of plain HTML `<form>` or explicitly qualified `<Phoenix.Component.form>`. See the [HTML form documentation](https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/form#novalidate).

`CoreComponents.input` keeps semantic attributes such as `required` and input types such as `email`. When `required` is true, it adds an asterisk next to the field's label. Pass `required` on the component. The label itself stays unchanged, so there is no need to append "Required" to its text. Optional fields have no marker. The asterisk uses the shared theme's error colour.

`novalidate` bypasses the browser's submission checks without changing the server's validation rules. Ash validates submitted values, including user email syntax, and the application displays form errors or the appropriate authentication message. Invalid password-reset requests stay on the form with errors, while valid requests retain the same generic response for known and unknown accounts.

Use the imported `<.form>` for future application forms to keep that behaviour consistent. Avoid calling `reportValidity()` on forms or inputs because that API explicitly asks the browser to display validation problems, even when automatic submission validation is disabled. See the [reportValidity documentation](https://developer.mozilla.org/en-US/docs/Web/API/HTMLFormElement/reportValidity).

Before adding a new form, make sure its resource or action enforces the constraints that HTML would otherwise check. Adding `required` to a component communicates the requirement but does not create a server validation rule.

## Upload storage

Public uploads are stored in `var/uploads/public` during development and `tmp/uploads/public` during tests. `CoreUtils.Upload` consumes LiveView uploads into the configured directory and returns `/uploads/...` URLs. The user editor validates before consuming files and removes new files when saving fails. Replaced pictures are removed after a successful save.

In production, set `UPLOAD_DIRECTORY` to a writable, persistent directory outside the release. Files in this directory are served publicly. Private documents need a separate authorised storage and download flow.

## Resource history

Organisation settings enable AshPaperTrail and AshEvents so changes retain history and produce events. AshArchival is disabled because the singleton settings have no deletion action. AshStateMachine is disabled because settings have no lifecycle states.

Number sequences disable all four extensions. Allocating a counter does not need versions, replay events, soft deletion, or lifecycle states. The durable counter remains in place.

Roles, grants, navigation entries, and addresses retain their audit versions after deletion. Their history stores the original source identifier without a foreign key that would prevent the source record from being removed. Archived users keep their source relationship. Replay clears the corresponding audit versions with their source records before rebuilding them from events.

Event-log reads require the system actor. Secret action inputs are redacted, while recorded attribute changes can include password hashes and private profile details. Full replay needs application-specific overrides for authentication actions because their required secret inputs are unavailable. The native replay action clears records before applying events and does not start a transaction. Run it inside an explicit Ash data-layer transaction after validating the replay configuration on a database copy. Use database backups for recovery.

## Verification and deployment

### Test layout and expectations

`test/` is the standard folder generated for Elixir projects, and Mix searches it by default. The name is configurable through `:test_paths` in `mix.exs`, so it is not a fixed requirement. This project keeps the standard layout, including `test/test_helper.exs` and `test/support`. Renaming it would also require updating the support compilation path and any commands or references that use it. See the official [Mix test configuration](https://mix.hexdocs.pm/1.20.4/Mix.Tasks.Test.html#module-configuration).

JavaScript lifecycle checks live separately in `assets/test/` and run through Node's built-in test runner. `mix test` does not run them. They check selected hook behaviour with simulated browser objects, so they do not replace browser testing.

The [Elixir test notice](../test/README.md) and [JavaScript test notice](../assets/test/README.md) explain the purpose and limits of the AI-generated checks. Their assertions may not fully reflect the author's intended behaviour and need review before being treated as requirements.

### Checks

```sh
mise exec -- mix compile --warnings-as-errors
mise exec -- mix format --check-formatted
mise exec -- mix ash.codegen --check
mise exec -- mix test
mise exec -- node --test assets/test/*.mjs
mise exec -- mix assets.build
mise exec -- mix dialyzer
mise exec -- mix hex.audit
mise exec -- npm audit --prefix assets
```

Node follows the same `latest` selection in `mise.toml`. Registry dependency requirements retain open-ended `>=` minimums, while the lockfiles record the installed releases. Update and check the lockfiles when adopting newer releases. `mix precommit` runs the native `ash.codegen --check`, the test suite, and Dialyzer. The migration test requires exactly one migration file. Hex audit reports dependency advisories independently of application tests.

Dialyzer has one exact exception for AshAuthenticationPhoenix 2.17.4's reference to `Ash.Resource.record/0`, which Ash omits on OTP 29. Remove it when the corrected type reaches a stable release. Unused filters fail the check so the exception cannot silently outlive the upstream fix.

Money uses the native Localize packages supplied by ExMoney. The existing CLDR backend supplies locale, currency, and territory metadata. The exchange-rate service stays disabled until the application needs it. Add its native retriever to the application supervision tree when enabling it. CLDR Calendar and Units currently use their newest compatible releases: their newer patches require DigitalToken 1, while Money 6 requires DigitalToken 2. Dependency updates must resolve that upstream constraint before advancing those packages together.

Assent, Makeup, Unicode, UnicodeSet, and UnicodeString also retain the newest versions allowed by authentication, Faker, and CLDR requirements.

PetalComponents 4.17.1 requires `websock_adapter ~> 0.5.7`, so dependency resolution retains WebSockAdapter 0.5.9 while 0.6.0 is available. The project follows that declared dependency range.

Cloak remains a declared template dependency for future encryption, and the application configures no encryption vault or encrypted resource attributes. Its newest published release, 1.1.4, still carries [CVE-2026-95105](https://cna.erlef.org/cves/CVE-2026-95105.html), which affects its unauthenticated AES-CTR ciphers. The package advisory remains open and is reported by `mix hex.audit`. When introducing encryption, configure `Cloak.Ciphers.AES.GCM` and exclude both CTR implementations. Any existing CTR ciphertext must be re-encrypted with GCM before removing CTR support, as described in the advisory.

Ash string-length constraints count Unicode codepoints, matching PostgreSQL's length checks.

### Initial schema

Keep exactly one migration in `priv/repo/migrations`, using `Elixirbits.Repo.Migrations.InitialSchema`. Make Ash-managed schema changes on the resources and regenerate the complete initial schema into fresh temporary migration and snapshot paths:

```sh
initial_schema_dir="$(mktemp -d)"
mise exec -- mix ash.codegen initial_schema \
  --migration-path "$initial_schema_dir/migrations" \
  --snapshot-path "$initial_schema_dir/resource_snapshots"
```

Preserve the native generated statements when combining the output into the single `InitialSchema` module. Its `up/0` contains the extension migration's `up/0` body before the table migration's `up/0` body. Its `down/0` contains the table migration's `down/0` body before the extension migration's `down/0` body. Keep the existing migration version and filename when replacing the schema on subsequent changes, so the project continues to contain exactly one migration file.

Replace `priv/resource_snapshots` with the native snapshot output from the temporary directory, including its `repo` directory and `extensions.json`. Do not edit snapshots by hand. Remove the temporary directory after replacing the migration and snapshots. Reset development and drop the test database after every schema replacement, then verify the generated schema and tests:

```sh
mise exec -- mix ecto.reset
MIX_ENV=test mise exec -- mix ecto.drop
mise exec -- mix ash.codegen --check
mise exec -- mix test
```

The development reset removes its data and reruns the seeds. `mix test` uses the existing `ash.setup` alias to recreate and migrate the empty test database. Tests create their own sandbox data and verify the seeds inside the sandbox, so the test database has no global seed records that could collide with fixtures. The exact-one migration test enforces the file count, while the native codegen check verifies that the resource definitions and snapshots agree.

### Deployment

Production also requires the database URL, Phoenix secret key, and authentication signing secret from `config/runtime.exs`. Build deployment assets with `mise exec -- mix assets.deploy` and consult the [Phoenix deployment guide](https://hexdocs.pm/phoenix/deployment.html) for release setup.

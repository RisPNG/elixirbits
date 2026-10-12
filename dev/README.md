# Elixirbits development guide

An Elixir, Phoenix LiveView, and Ash application template with authentication, account administration, page permissions, shared form components, and reusable application infrastructure.

This guide covers setup, implementation, verification, and deployment. For the application overview, see the [main README](../README.md). Run the commands below from the repository root.

Write each prose paragraph on one physical source line and let the editor wrap it visually. Keep blank lines between paragraphs and preserve the line structure of lists, tables, code examples, and intentional hard breaks. This applies to documentation, explanatory comments, and help text. Code keeps its normal formatter layout. Dependency, vendor, and generated files retain their upstream formatting.

## Local setup

`mise.toml` tracks the latest tool releases, and `.tool-versions` records the pinned toolchain versions. Install the tools with mise and make sure PostgreSQL is running before setting up the application:

```sh
mise install
mise exec -- mix setup
mise exec -- mix phx.server
```

Node and npm manage the JavaScript dependencies. `mix assets.setup` installs them and updates `assets/package-lock.json` through npm. For a clean installation of the locked versions, run `mise exec -- npm ci --prefix assets` after fetching the Mix dependencies.

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

## Shared components and utilities

`CoreComponents` provides forms, actions, cards, entry panels, tables, and inputs, including searchable selects, radios, switches, password visibility, and upload previews. Its imported `<.form>` disables browser submission validation by default and delegates native form behaviour to Phoenix. Colours live in `assets/css/app.css`. Fixed form grids use explicit tracks and `subgap` for aligned transparent fields. The showcase demonstrates the supported input modes and interactions.

Listing pages place their heading, filters, and table directly in the page layout. Cinder filters keep a transparent outline, and tables use their own rounded frame, shaded header, and alternating rows through the shared listing utilities. List and grid items keep individual transparent outlines. Reserve cards and recessed panels for forms and nested detail.

Every application form and input must use the imported `<.form>` and `<.input>` from `CoreComponents`, including selects, textareas, hidden fields, and file uploads. Call the core component by its qualified name in isolated component tests. Keep native form controls, Phoenix form rendering, LiveSelect, and LiveView upload rendering inside the core implementation. If the shared API cannot preserve a field's behaviour or accessibility, discuss the missing capability and proposed core change before implementing a workaround.

This rule covers application-owned forms and inputs. Cinder filters and selection controls, AshAdmin, LiveDashboard, and the development mailbox remain owned by their installed packages. Core's native controls and framework-generated hidden fields are also part of their owning renderer. The source boundary test checks application templates and component calls to prevent new bypasses without changing dependency internals.

Searchable selects use real Phoenix form fields, such as `<.input field={@form[:choice]} type="select" options={@options} />`. LiveSelect derives submitted names and textbox IDs from the field's form, so create a form with `to_form/2` for independent groups of fields instead of relying on a select's `name` override. An explicit input `id` identifies the LiveSelect component. The textbox keeps `field.id <> "_text_input"`, which an external label must target.

Selections trigger the enclosing form's `phx-change` event. Handle `live_select_change` for focus and search, filter the available options with `Search.filter/2`, and use native `send_update(LiveSelect.Component, id: id, options: options)`. Static permission and timezone choices use `update_min_len={0}` to restore all options when search text is cleared and `allow_clear={false}` to retain an explicit choice. Permission changes are processed alongside role form validation and restricted to the current superuser grant. The shared timezone hook handles only the navigation selector's exact ID, leaving page-specific selectors to their LiveView.

Select `aria-labelledby`, `aria-label`, and `aria-describedby` describe the core field group, including its disabled display. Labels still target the actual textbox. Installed LiveSelect does not expose arbitrary textbox attributes, so these associations describe the surrounding group rather than adding textbox-level ARIA or full combobox semantics.

Use `rounded-default` for ordinary controls and panels, and `rounded-full` for pills and circles. The shared `--radius-default` is 0.5rem. Both classes also support SVG rectangles. SVG full rounding reads the rectangle's numeric `width` and `height` attributes and uses half the shorter dimension, capped by `--radius-full`, so its corners match HTML pills instead of stretching into an ellipse. Omit rounding classes for ordinary square elements. Central calendar styles still reset selected corners to zero where a range joins an already rounded date button.

Neutral outlines use `--color-outline`, which darkens the current theme surface. Shared `bg-*` utilities publish that surface so field, button, and panel borders adapt to their background. `--color-content` uses native CSS `contrast-color()` to choose black or white for the same surface, and `--color-subcontent` mixes that foreground with the surface using the central `--subcontent-strength`. Transparent controls inherit their surrounding surface. Use `text-content` for main text, `text-subcontent` for secondary text, `border-outline` for borders, `divide-outline` for separators, and `stroke-outline` for SVG grid lines. SVG colour classes follow the same approach: put a semantic `fill-*` on the group containing the shape and its text, then use `fill-content` for contrasting text. Shapes inherit the group's fill, and transparent groups retain their surrounding background context. Surface tracking stays inside the shared stylesheet; components use ordinary Tailwind colour classes. Focus, errors, checked controls, and colour-coded calendar events keep their semantic theme colours.

Native range-slider thumbs receive the adaptive outline calculation centrally through separate browser-specific rules. Calendar thumbs use ordinary `bg-primary` and `border-outline` utilities without applying the calculation helper themselves.

The central `@theme static` declaration emits the shared colours without alternate tokens or a separate on-colour foreground. `--color-dark` and `--color-light` are translucent modifiers controlled by the shared `--overlay-opacity` value. Use `overlay-dark` or `overlay-light` to layer shading over an existing fill, including transparent fields. Combine an explicit fill with a modifier, such as `bg-primary overlay-dark` or `bg-brand overlay-light`, to publish the combined surface for adaptive text, outlines, and floating-label cutouts. Transparent elements inherit the surrounding surface, even when they add their own overlay. A modifier applies once per element. Button hover and disabled states use the dark modifier. Text and icons stay above the shade, and focus rings remain visible. Select options use light for hover and keyboard highlighting, and dark for selected values. The shared `bg-*` utility resolves palette colours and captured adaptive backgrounds. Inline compiler mappings select the parent capture for `bg-content`, `bg-subcontent`, and `bg-outline`, so they paint the parent's computed colour before becoming a new surface and nested text can adapt without a circular colour reference. Checked switch thumbs, radio dots, and checkbox marks use adaptive content colours. The progress bar reads `--color-brand` and `--color-dark` from the current theme when loading starts. All colour adaptation remains CSS-only.

Use `CoreComponents.button` with `variant={:neutral}` for ordinary labelled actions, `:primary` for the main action, and `:danger` for destructive confirmations. Labelled buttons and square `action_button` controls share their text, background, border, and hover colours through the `button-primary`, `button-neutral`, and `button-danger` theme utilities. Cinder actions use the same utilities. Table action columns fit their contents, so a label such as "Inspect" has room alongside square icons. Leave `variant` unset only for controls with their own presentation, such as tabs.

Record action buttons use `:create` with the default tooltip "Add new", `:read` with "View", and `:update` with "Update". Use `action={:create} tooltip="Add"` when adding a nested form entry. Tooltips also provide the accessible label. The other supported actions are `:save`, `:send`, `:archive`, `:delete`, and `:back`.

Status badges use the `status-pill` theme utility for the same 44px minimum height and `text-sm` font size as action buttons. Add the appropriate shared background and text colours, such as `status-pill bg-success text-content` for a ready status. The rounded pill shape communicates status while its height aligns with adjacent actions.

Native file fields and LiveView upload controls share the file-input CSS. Their filename text uses equal vertical padding to centre its 20px line within the 44px bordered field, and the upload icon centres on the field as well.

`CalendarComponents.calendar/1` renders day, week, month, year, schedule, and resource views. It accepts plain event maps, converts UTC datetimes to the display timezone, clips events across local days, and emits `calendar_change` events for navigation and selection. Timed event controls support keyboard activation. `LiveTimer` displays elapsed or countdown time from an absolute `data-target` datetime.

`CoreUtils.Resource`, `Search`, and `Parse` handle Ash metadata, relationship loads, searchable options, nested sequence values, and typed input conversion. Datetime conversion preserves microseconds by default and supports explicit precision.

### Datetimes and user timezones

Persist instants with Ash `:utc_datetime`, `:utc_datetime_usec`, or `:datetime` with UTC timezone constraints. Application timestamps use these types, and database connections use UTC. A stored instant does not retain the timezone in which it was entered. API and background-job callers should supply a UTC `DateTime` or an ISO 8601 datetime with an explicit offset.

Dates and standalone clock times have different meanings. Store birthdays with `:date` and recurring local hours with `:time`. Neither is an instant that can be converted to UTC without additional information. User birthdays use `:date`. The user and organisation `timezone` fields store IANA names as preferences, rather than timezone-bearing datetime values.

The browser sends `Intl.DateTimeFormat().resolvedOptions().timeZone` through LiveSocket connect params. Every application LiveView receives `@user_timezone` through the shared `LiveUserAuth` mount hook. Resolution follows this order:

1. The signed-in user's saved timezone.
2. A valid timezone detected by the browser.
3. The organisation's timezone.
4. `Etc/UTC` when organisation settings are absent.

The initial HTTP render has no browser connect params, so it uses the saved preference or organisation fallback until LiveView connects. Calendar inputs update their displayed value when the resolved timezone arrives. An explicit user preference continues to take priority after reconnecting or navigating.

Signed-in users can expand the navigation menu and save a timezone. The searchable field keeps its unsaved choice across page updates and changes the stored preference only when saved. Choosing **Automatic (browser)** clears the saved preference. The dedicated `Accounts.update_user_timezone/3` action accepts only `timezone` and authorises the user's own active account. Changing other profile fields still needs the usual administration permission. Saving reloads the current page so its forms and calendars use the chosen timezone together.

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

Inputs bound to an AshPhoenix field obtain the timezone from the form's shared context. Pass `timezone={@user_timezone}` to standalone datetime inputs and `timezone={@user_timezone}` to calendars. Pass `user_timezone={@user_timezone}` to `Layouts.app` so navigation shows the effective setting. Date, time, week, and month inputs keep their calendar or clock values.

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

Node's version is pinned in `.tool-versions`. `mix precommit` runs the native `ash.codegen --check`, the test suite, and Dialyzer. The migration test requires exactly one migration file. Hex audit reports dependency advisories independently of application tests.

Dialyzer has one exact exception for AshAuthenticationPhoenix 2.17.4's reference to `Ash.Resource.record/0`, which Ash omits on OTP 29. Remove it when the corrected type reaches a stable release. Unused filters fail the check so the exception cannot silently outlive the upstream fix.

Money uses the native Localize packages supplied by ExMoney. The existing CLDR backend supplies locale, currency, and territory metadata. The exchange-rate service stays disabled until the application needs it. Add its native retriever to the application supervision tree when enabling it. CLDR Calendar and Units currently use their newest compatible releases: their newer patches require DigitalToken 1, while Money 6 requires DigitalToken 2. Dependency updates must resolve that upstream constraint before advancing those packages together.

Assent, Makeup, Unicode, UnicodeSet, and UnicodeString also retain the newest versions allowed by authentication, Faker, and CLDR requirements.

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

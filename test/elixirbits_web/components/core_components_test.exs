defmodule ElixirbitsWeb.CoreComponentsTest.SelectPreview do
  use Phoenix.LiveView, layout: false

  alias ElixirbitsWeb.CoreComponents

  def mount(_params, session, socket) do
    {:ok,
     assign(socket,
       form:
         to_form(
           %{"labeled_role" => "viewer", "unlabeled_role" => "viewer", "phone" => "+60123456789"},
           as: :choices
         ),
       render_as: session["render_as"] || "enabled",
       options: [
         {"Editor", "editor"},
         {"Viewer", "viewer"},
         {"Unavailable", "unavailable", disabled: true}
       ]
     )}
  end

  def handle_event("change", %{"choices" => params}, socket) do
    {:noreply, assign(socket, :form, to_form(params, as: :choices))}
  end

  def render(assigns) do
    ~H"""
    <CoreComponents.form for={@form} id="choices-form" phx-change="change">
      <CoreComponents.input
        field={@form[:labeled_role]}
        id="labeled-role"
        type="combobox"
        label="Role"
        render_as={@render_as}
        options={@options}
      />
      <CoreComponents.input
        field={@form[:unlabeled_role]}
        id="unlabeled-role"
        type="combobox"
        render_as={@render_as}
        options={@options}
      />
      <CoreComponents.input
        field={@form[:phone]}
        id="phone"
        type="tel"
        label="Phone"
        render_as={@render_as}
      />
    </CoreComponents.form>
    """
  end
end

defmodule ElixirbitsWeb.CoreComponentsTest.ColorPreview do
  use Phoenix.LiveView, layout: false

  alias ElixirbitsWeb.CoreComponents

  on_mount {CoreComponents, :inputs}

  def mount(_params, session, socket) do
    {:ok, assign(socket, :input_assigns, session["input_assigns"])}
  end

  def render(assigns) do
    ~H"""
    <CoreComponents.input type="color" {@input_assigns} />
    """
  end
end

defmodule ElixirbitsWeb.CoreComponentsTest do
  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest

  alias ElixirbitsWeb.CoreComponents

  @endpoint ElixirbitsWeb.Endpoint

  describe "button actions" do
    test "default controls preserve toggle and tab states, events, and disabled behavior" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.button
          id="details-toggle"
          type="button"
          aria-pressed="true"
          phx-click="toggle_details"
          phx-value-section="details"
        >Details</CoreComponents.button>
        <CoreComponents.button
          id="overview-tab"
          type="button"
          role="tab"
          aria-selected="false"
          disabled
        >Overview</CoreComponents.button>
        """)

      document = Floki.parse_document!(html)

      assert [_] =
               Floki.find(
                 document,
                 "button#details-toggle[type=button][aria-pressed=true][phx-click=toggle_details][phx-value-section=details]"
               )

      assert document |> Floki.find("#details-toggle") |> Floki.text() |> String.trim() ==
               "Details"

      assert [_] =
               Floki.find(
                 document,
                 "button#overview-tab[role=tab][aria-selected=false][disabled]"
               )
    end

    test "text actions preserve navigation and event semantics" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.button id="create-account" variant={:text} navigate="/register">
          Create an account
        </CoreComponents.button>

        <CoreComponents.button
          id="request-link"
          variant={:text}
          type="button"
          phx-click="request_magic_link"
          phx-disable-with="Sending..."
        >Email me a magic link</CoreComponents.button>
        """)

      document = Floki.parse_document!(html)

      assert [_] =
               Floki.find(document, "a#create-account[href='/register'][data-phx-link=redirect]")

      assert [_] =
               Floki.find(
                 document,
                 "button#request-link[type=button][phx-click=request_magic_link][phx-disable-with='Sending...']"
               )

      assert Floki.find(document, "button#create-account, a#request-link") == []
      assert Floki.text(Floki.find(document, "#create-account")) =~ "Create an account"

      assert document |> Floki.find("#request-link") |> Floki.text() |> String.trim() ==
               "Email me a magic link"
    end
  end

  describe "collapse panels" do
    test "rich summaries and interactive content remain inside one native panel" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.collapse
          id="billing-protection"
          name="billing-settings"
          data-purpose="protection"
        >
          <:summary>
            <span id="protection-title">Billing protection</span>
            <span id="protection-status">3 of 4 services active</span>
            <.link href="/help/billing">Learn more</.link>
          </:summary>

          <CoreComponents.form for={nil} id="protection-settings" phx-submit="save_protection">
            <CoreComponents.input
              type="checkbox"
              name="fraud_monitoring"
              value={true}
              label="Fraud monitoring"
            /> <CoreComponents.button type="submit">Save settings</CoreComponents.button>
          </CoreComponents.form>
        </CoreComponents.collapse>
        """)

      document = Floki.parse_document!(html)

      assert [panel] =
               Floki.find(
                 document,
                 "details#billing-protection[name=billing-settings][data-purpose=protection]"
               )

      assert [summary] = Floki.find(panel, "summary")
      assert Floki.text(summary) =~ "Billing protection"
      assert Floki.text(summary) =~ "3 of 4 services active"
      assert Floki.find(summary, "a[href='/help/billing']") != []
      assert Floki.find(summary, "form") == []

      assert Floki.find(panel, "form#protection-settings[phx-submit=save_protection]") != []
      assert Floki.find(panel, "input[name=fraud_monitoring][checked]") != []

      assert Floki.text(Floki.find(panel, "button[type=submit]")) |> String.trim() ==
               "Save settings"

      assert Floki.find(document, "details[open]") == []
    end

    test "initial expansion is explicit and native open state is preserved after mounting" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.collapse id="expanded-settings" open>
          <:summary>Settings</:summary>

          <p>These settings start expanded.</p>
        </CoreComponents.collapse>
        """)

      document = Floki.parse_document!(html)
      assert [panel] = Floki.find(document, "details#expanded-settings[open]")
      assert Floki.text(panel) =~ "These settings start expanded."
      assert [mounted] = Floki.attribute(panel, "phx-mounted")
      assert [["ignore_attrs", %{"attrs" => ["open"]}]] = Jason.decode!(mounted)
    end
  end

  describe "combobox option states" do
    test "comboboxes expose selected and disabled options and follow native form changes" do
      {:ok, view, html} =
        live_isolated(Phoenix.ConnTest.build_conn(), __MODULE__.SelectPreview)

      document = Floki.parse_document!(html)

      for id <- ["labeled-role", "unlabeled-role", "choices_phone_country_code_country_select"] do
        rows = Floki.find(document, "##{id} [role=option]")
        assert length(rows) >= 2
        assert length(Floki.find(document, "##{id} [role=option][aria-selected=true]")) == 1
        assert Floki.find(document, "##{id}-select option[selected]") != []
      end

      for {id, field_name} <- [
            {"labeled-role", "choices[labeled_role]"},
            {"unlabeled-role", "choices[unlabeled_role]"}
          ] do
        assert has_element?(view, "##{id} [role=option][aria-disabled=true]", "Unavailable")
        assert has_element?(view, "##{id}-select option[value=unavailable][disabled]")

        assert has_element?(
                 view,
                 "##{id}-select[name='#{field_name}'] option[value=viewer][selected]"
               )
      end

      view
      |> form("#choices-form", choices: %{labeled_role: "editor", unlabeled_role: "editor"})
      |> render_change()

      for id <- ["labeled-role", "unlabeled-role"] do
        assert has_element?(view, "##{id}-select option[value=editor][selected]")
        assert has_element?(view, "##{id} [role=option][data-value=editor][aria-selected=true]")
        assert has_element?(view, "##{id} [role=option][data-value=viewer][aria-selected=false]")
      end
    end
  end

  describe "shared forms" do
    test "default validation setting preserves native form fields, errors, and LiveView attributes" do
      assigns = %{source: %{"email" => "person@example.com"}}

      html =
        rendered_to_string(~H"""
        <CoreComponents.form
          :let={%Phoenix.HTML.Form{} = form}
          for={@source}
          as={:account}
          errors={[email: {"Email is invalid", []}]}
          id="account-form"
          phx-change="validate"
          phx-submit="save"
          phx-target="#editor"
          autocomplete="off"
          data-purpose="profile"
        >
          <CoreComponents.input field={form[:email]} type="email" label="Email" required />
        </CoreComponents.form>
        """)

      document = Floki.parse_document!(html)

      assert Floki.find(
               document,
               "form#account-form[novalidate][phx-change=validate][phx-submit=save][phx-target='#editor'][autocomplete=off][data-purpose=profile]"
             ) != []

      assert Floki.find(
               document,
               "input#account-form_email[name='account[email]'][value='person@example.com'][required]"
             ) != []

      assert Floki.text(document) =~ "Email is invalid"
      assert Floki.find(document, "input[name=_csrf_token], input[name=_method]") == []
    end

    test "explicit false enables browser validation without removing required inputs" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.form for={nil} id="native-validation" novalidate={false}>
          <CoreComponents.input name="email" type="email" value="" required />
        </CoreComponents.form>
        """)

      document = Floki.parse_document!(html)
      assert Floki.find(document, "form#native-validation") != []
      assert Floki.find(document, "form[novalidate]") == []
      assert Floki.find(document, "input[name=email][required]") != []
    end

    test "HTTP forms retain native CSRF protection, method spoofing, and multipart encoding" do
      assigns = %{form: to_form(%{"avatar" => ""}, as: :profile)}

      html =
        rendered_to_string(~H"""
        <CoreComponents.form
          :let={%Phoenix.HTML.Form{} = form}
          for={@form}
          id="profile-upload"
          action="/profile"
          method="patch"
          multipart
        >
          <CoreComponents.input field={form[:avatar]} type="file" />
        </CoreComponents.form>
        """)

      document = Floki.parse_document!(html)

      assert Floki.find(
               document,
               "form#profile-upload[action='/profile'][method=post][enctype='multipart/form-data'][novalidate]"
             ) != []

      assert Floki.find(document, "input[type=hidden][name=_method][value=patch]") != []
      assert [token] = Floki.attribute(document, "input[type=hidden][name=_csrf_token]", "value")
      assert token != ""
      assert Floki.find(document, "input[type=file][name='profile[avatar]']") != []
    end
  end

  describe "color inputs" do
    test "standalone labels target the named color field when no ID is supplied" do
      {:ok, _view, html} =
        live_isolated(Phoenix.ConnTest.build_conn(), __MODULE__.ColorPreview,
          session: %{
            "input_assigns" => %{name: "accent", value: "#c9822b", label: "Accent"}
          }
        )

      document = Floki.parse_document!(html)

      assert Floki.find(document, "input#accent[data-color-value][name=accent]") != []
      assert Floki.text(Floki.find(document, "label[for=accent]")) |> String.trim() == "Accent"
    end

    test "supported color strings remain the submitted value beside a swatch-triggered picker" do
      for {value, format} <- [
            {"#12345678", "hex"},
            {"rgb(18 52 86 / 0.5)", "rgb"},
            {"rgba(18, 52, 86, 0.5)", "rgb"},
            {"hsl(210 65% 20% / 0.5)", "hsl"},
            {"hsla(210, 65%, 20%, 0.5)", "hsl"},
            {"lab(52 -2 -7 / 0.5)", "lab"},
            {"lch(52 24 270 / 0.5)", "lch"},
            {"oklab(0.32 -0.02 -0.07 / 0.5)", "oklab"},
            {"oklch(0.32 0.073 254 / 0.5)", "oklch"},
            {"color(xyz-d50 0.2 0.3 0.4 / 0.5)", "xyz-d50"},
            {"color(xyz-d65 0.2 0.3 0.4 / 0.5)", "xyz-d65"},
            {"device-cmyk(0.1 0.2 0.3 0.4 / 0.5)", "cmyk"}
          ] do
        {:ok, _view, html} =
          live_isolated(Phoenix.ConnTest.build_conn(), __MODULE__.ColorPreview,
            session: %{
              "input_assigns" => %{
                id: "accent",
                name: "settings[accent]",
                value: value,
                label: "Accent"
              }
            }
          )

        document = Floki.parse_document!(html)

        assert Floki.find(document, "#accent-color-input[phx-hook=ColorInput]") != []

        assert Floki.find(
                 document,
                 "input#accent[type=text][name='settings[accent]'][data-color-value]"
               ) != []

        assert Floki.attribute(document, "input#accent", "value") == [value]
        assert length(Floki.find(document, "[name='settings[accent]']")) == 1
        assert Floki.find(document, "input[type=color]") == []

        [initial_state] =
          Floki.attribute(document, "#accent-color-input", "data-color-state")

        assert %{
                 "valid" => true,
                 "value" => ^value,
                 "format" => ^format,
                 "swatch" => swatch,
                 "rgba" => %{"r" => r, "g" => g, "b" => b, "a" => alpha}
               } = Jason.decode!(initial_state)

        assert is_binary(swatch)
        assert Enum.all?([r, g, b], &(is_number(&1) && &1 >= 0 && &1 <= 255))
        assert_in_delta alpha, if(format == "hex", do: 120 / 255, else: 0.5), 1.0e-10

        assert Floki.find(
                 document,
                 "button[type=button][data-color-trigger][aria-label='Choose color'][popovertarget=accent-color-popover]:not([name]):not([disabled])"
               ) != []

        assert Floki.find(
                 document,
                 "#accent-color-popover[popover=auto][role=dialog][data-color-popover][aria-label='Choose color'] rgba-color-picker#accent-color-picker[data-color-picker][phx-update=ignore]:not([name])"
               ) != []

        assert Floki.find(document, "[data-color-swatch]") != []

        assert Floki.find(
                 document,
                 "#accent_color_space_select[phx-hook=PetalComboBox] input[type=text]"
               ) != []

        assert Floki.find(
                 document,
                 "[data-color-cycle]"
               ) == []

        assert Floki.find(document, "#accent-color-error[data-color-error]") != []
      end
    end

    test "saved native formats select their color-space label in editable and read-only modes" do
      for render_as <- ~w(enabled text-disabled),
          {value, format} <- [
            {"#12345678", "HEX"},
            {"color(xyz 0.2 0.3 0.4 / 0.5)", "XYZ D65"},
            {"color(xyz-d50 0.2 0.3 0.4 / 0.5)", "XYZ D50"},
            {"lab(52 -2 -7 / 0.5)", "Lab"},
            {"lch(52 24 270 / 0.5)", "LCH"},
            {"oklab(0.32 -0.02 -0.07 / 0.5)", "OKLab"},
            {"oklch(0.32 0.073 254 / 0.5)", "OKLCH"},
            {"rgba(18, 52, 86, 0.5)", "RGB"},
            {"hsla(210, 65%, 20%, 0.5)", "HSL"},
            {"device-cmyk(0.1 0.2 0.3 0.4 / 0.5)", "CMYK"}
          ] do
        {:ok, _view, html} =
          live_isolated(Phoenix.ConnTest.build_conn(), __MODULE__.ColorPreview,
            session: %{
              "input_assigns" => %{
                id: "accent",
                name: "accent",
                value: value,
                render_as: render_as
              }
            }
          )

        document = Floki.parse_document!(html)

        if render_as == "enabled" do
          assert Floki.attribute(document, "#accent_color_space_select input[type=text]", "value") ==
                   [format]
        else
          assert Floki.text(Floki.find(document, "[data-color-format]")) |> String.trim() ==
                   format
        end

        assert Floki.attribute(document, "input#accent", "value") == [value]
      end
    end

    test "form fields forward their attributes to the submitted text and keep one required label" do
      form =
        to_form(%{"accent" => "rgba(18, 52, 86, 0.5)"},
          as: :settings,
          errors: [accent: {"Accent is invalid", []}]
        )

      {:ok, _view, html} =
        live_isolated(Phoenix.ConnTest.build_conn(), __MODULE__.ColorPreview,
          session: %{
            "input_assigns" => %{
              field: form[:accent],
              label: "Accent",
              required: true,
              readonly: true,
              disabled: true,
              autocomplete: "off",
              "phx-debounce": "200",
              "data-purpose": "brand",
              "aria-label": "Brand accent"
            }
          }
        )

      document = Floki.parse_document!(html)

      assert Floki.find(
               document,
               "input#settings_accent[type=text][name='settings[accent]'][required][readonly][disabled][autocomplete=off][phx-debounce='200'][data-purpose=brand][aria-label='Brand accent']"
             ) != []

      assert Floki.attribute(document, "input#settings_accent", "value") == [
               "rgba(18, 52, 86, 0.5)"
             ]

      assert Floki.find(document, "label[for=settings_accent]") != []
      assert length(Floki.find(document, "span[aria-hidden=true].text-error")) == 1

      assert Floki.find(
               document,
               "[data-color-picker][name], [data-color-picker][required], [data-color-trigger][name], [data-color-trigger][required]"
             ) == []

      assert Floki.find(document, "button[data-color-trigger][disabled]") != []

      assert Floki.find(
               document,
               "#settings_accent_color_space_select input[type=text][disabled]"
             ) != []

      assert Floki.text(document) =~ "Accent is invalid"
    end

    test "disabled and readonly text fields cannot open the picker" do
      for restriction <- [:disabled, :readonly] do
        {:ok, _view, html} =
          live_isolated(Phoenix.ConnTest.build_conn(), __MODULE__.ColorPreview,
            session: %{
              "input_assigns" =>
                Map.put(
                  %{id: "accent", name: "accent", value: "rgba(18, 52, 86, 0.5)"},
                  restriction,
                  true
                )
            }
          )

        document = Floki.parse_document!(html)

        assert Floki.find(document, "input#accent[type=text][name=accent][#{restriction}]") != []
        assert Floki.find(document, "button[data-color-trigger][disabled]") != []
        assert Floki.find(document, "#accent_color_space_select input[type=text][disabled]") != []
      end
    end

    test "editable modes retain text submission while text modes keep their stacked labels" do
      for render_as <- ~w(enabled text text-enabled hidden hidden-enabled) do
        {:ok, _view, html} =
          live_isolated(Phoenix.ConnTest.build_conn(), __MODULE__.ColorPreview,
            session: %{
              "input_assigns" => %{
                id: "accent",
                name: "accent",
                value: "oklch(0.65 0.15 270 / 0.5)",
                label: "Accent",
                render_as: render_as,
                required: true
              }
            }
          )

        document = Floki.parse_document!(html)

        assert Floki.find(document, "#accent-color-input[phx-hook=ColorInput]") != []
        assert Floki.find(document, "input#accent[type=text][name=accent][required]") != []
        assert Floki.find(document, "button[data-color-trigger]:not([disabled])") != []

        assert Floki.attribute(document, "input#accent", "value") == [
                 "oklch(0.65 0.15 270 / 0.5)"
               ]

        assert length(Floki.find(document, "span[aria-hidden=true].text-error")) == 1

        if render_as in ~w(text text-enabled) do
          assert Floki.find(document, ".input-floating-control, .input-floating-label") == []
          assert Floki.find(document, "label[for=accent]") != []
        end

        if render_as in ~w(hidden hidden-enabled) do
          assert Floki.find(document, ".hidden input#accent[required]") != []
        end
      end
    end

    test "read-only modes show the swatch and preserve their existing submission semantics" do
      for render_as <- ~w(disabled like-enabled like-disabled text-disabled hidden-disabled),
          value <- ["hsl(210 65% 20% / 0.5)", "device-cmyk(0.1 0.2 0.3 0.4 / 0.5)"] do
        document =
          render_component(&CoreComponents.input/1,
            id: "accent",
            name: "accent",
            type: "color",
            value: value,
            label: "Accent",
            render_as: render_as,
            required: true
          )
          |> Floki.parse_document!()

        assert Floki.find(
                 document,
                 "[data-color-space-select], [data-color-cycle], [data-color-trigger], [data-color-popover], [data-color-picker]"
               ) == []

        if render_as == "hidden-disabled" do
          assert document == []
        else
          assert Floki.find(
                   document,
                   "#accent-color-input[phx-hook=ColorInput][data-color-editable=false] span[data-color-value]"
                 ) != []

          assert Floki.find(document, "[data-color-swatch]") != []
          assert Floki.text(document) =~ value
          assert length(Floki.find(document, "span[aria-hidden=true].text-error")) == 1
        end

        if render_as in ~w(like-disabled text-disabled) do
          assert Floki.find(document, "input#accent[type=hidden][name=accent][required]") != []

          assert Floki.attribute(document, "input#accent", "value") == [value]
        else
          assert Floki.find(document, "[name=accent]") == []
        end
      end
    end
  end

  describe "file previews and editing" do
    test "a standalone preview destination supplies only its ID and visual attributes" do
      document =
        render_component(&CoreComponents.file_preview/1,
          id: "profile:avatar-preview",
          class: "size-20",
          "data-purpose": "portrait"
        )
        |> Floki.parse_document!()

      assert Floki.find(
               document,
               "[id='profile:avatar-preview'][data-file-preview-outlet].size-20[data-purpose=portrait]"
             ) != []

      assert Floki.find(document, "input, img, iframe, [data-file-item], [phx-hook]") == []
    end

    test "detached LiveView previews render the canonical items once through a native portal" do
      assigns = %{
        destination: "profile:avatar-preview",
        upload: %Phoenix.LiveView.UploadConfig{
          name: :attachment,
          ref: "attachment-upload",
          accept: :any,
          max_entries: 3,
          entries: [
            %Phoenix.LiveView.UploadEntry{
              ref: "picked-image",
              upload_ref: "attachment-upload",
              client_name: "new-portrait.png",
              client_type: "image/png"
            },
            %Phoenix.LiveView.UploadEntry{
              ref: "picked-pdf",
              upload_ref: "attachment-upload",
              client_name: "document.pdf",
              client_type: "application/pdf"
            }
          ]
        }
      }

      document =
        rendered_to_string(~H"""
        <CoreComponents.input
          type="file"
          upload={@upload}
          stored={["/uploads/portrait.png"]}
          selection="singles"
          preview
          preview_id={@destination}
          thumbnail_class="h-full w-full"
          phx-target="#profile"
        >
          <:stored_preview :let={url}><img src={url} alt="Custom portrait" /></:stored_preview>

          <:preview_caption>saved-portrait.png</:preview_caption>

          <:pending_caption :let={pending_entry}>{pending_entry.client_name}</:pending_caption>
        </CoreComponents.input>
        <CoreComponents.file_preview id={@destination} class="size-20" />
        """)
        |> Floki.parse_document!()

      assert Floki.attribute(
               document,
               "template#attachment-upload-file-preview-portal",
               "data-phx-portal"
             ) == ["[id=\"profile:avatar-preview\"]"]

      assert Floki.find(
               document,
               "template #attachment-upload-file-previews[phx-hook=FilePreview][data-file-input-id=attachment-upload][data-file-detached=true][data-file-preview-as=thumbnail]"
             ) != []

      assert length(Floki.find(document, "[data-file-item]")) == 3

      assert Floki.find(
               document,
               "template [data-file-item] img[alt='Custom portrait'][src='/uploads/portrait.png']"
             ) != []

      assert Floki.find(
               document,
               "template img[data-phx-entry-ref=picked-image][data-phx-upload-ref=attachment-upload]"
             ) != []

      assert Floki.find(
               document,
               "template [phx-hook=UploadPdfPreview][data-entry-ref=picked-pdf] iframe[data-pdf-viewer]"
             ) != []

      assert Floki.find(
               document,
               "template button[phx-click=cancel_upload][phx-value-ref=picked-image][phx-target='#profile']"
             ) != []

      assert Floki.find(
               document,
               "#attachment-upload-file-input > [data-file-replacements][phx-update=ignore]"
             ) != []

      assert Floki.find(
               document,
               "template [data-file-replacements], template input[type=file], #attachment-upload-file-input > [data-file-collection]"
             ) == []

      assert Floki.find(
               document,
               "#attachment-upload-file-previews.mt-1, #attachment-upload-file-previews.mt-3, #attachment-upload-file-previews [data-file-server-previews].mt-3"
             ) == []

      assert Floki.text(
               Floki.find(
                 document,
                 "template [data-file-key='/uploads/portrait.png'] [data-file-filename]"
               )
             )
             |> String.trim() == "saved-portrait.png"
    end

    test "detached native previews retain their local surface and follow hidden modes" do
      for {preview, mode} <- [{false, "enabled"}, {true, "hidden"}, {true, "hidden-disabled"}] do
        document =
          render_component(&CoreComponents.input/1,
            id: "portrait",
            name: "portrait",
            type: "file",
            preview: preview,
            preview_id: "portrait-preview",
            render_as: mode,
            stored: ["/uploads/portrait.png"],
            thumbnail_class: "h-full w-full"
          )
          |> Floki.parse_document!()

        assert Floki.find(
                 document,
                 "template#portrait-file-preview-portal #portrait-file-previews[hidden][data-file-detached=true]"
               ) != []

        assert Floki.find(
                 document,
                 "template #portrait-file-local-preview[phx-update=ignore][data-file-preview-region]"
               ) != []

        assert Floki.find(document, "template img[src='/uploads/portrait.png']") != []
        assert Floki.find(document, "template #portrait-file-preview-frame.mt-3") == []
        assert Floki.find(document, "#portrait-file-input input#portrait[data-file-input]") != []
      end
    end

    test "ordinary and multiple previews keep the same inline collection renderer" do
      for {selection, max_entries, preview_id} <- [
            {"single", 1, nil},
            {"multiple", 3, "detached-preview"}
          ] do
        document =
          render_component(&CoreComponents.input/1,
            type: "file",
            upload: %Phoenix.LiveView.UploadConfig{
              name: :attachment,
              ref: "attachment-upload",
              accept: :any,
              max_entries: max_entries
            },
            selection: selection,
            preview: true,
            preview_id: preview_id,
            stored: ["/uploads/portrait.png"]
          )
          |> Floki.parse_document!()

        assert Floki.find(document, "template[data-phx-portal]") == []

        assert Floki.find(
                 document,
                 "#attachment-upload-file-input > #attachment-upload-file-previews[phx-hook=FilePreview][data-file-detached=false]"
               ) != []

        assert length(Floki.find(document, "[data-file-item]")) == 1
        assert Floki.attribute(document, "[phx-hook=FileInput]", "data-file-preview-id") == []
      end
    end

    test "file fields default to filenames without image editing or built-in media" do
      entry = %Phoenix.LiveView.UploadEntry{
        ref: "picked-image",
        upload_ref: "attachment-upload",
        client_name: "portrait.png",
        client_type: "image/png"
      }

      upload = %Phoenix.LiveView.UploadConfig{
        name: :attachment,
        ref: "attachment-upload",
        accept: :any,
        max_entries: 2,
        entries: [entry]
      }

      document =
        render_component(&CoreComponents.input/1,
          type: "file",
          upload: upload,
          stored: ["/uploads/previous.png"]
        )
        |> Floki.parse_document!()

      assert Floki.attribute(document, "[phx-hook=FileInput]", "data-file-preview") == ["false"]
      assert Floki.attribute(document, "[phx-hook=FileInput]", "data-file-editor") == ["false"]
      assert Floki.find(document, "img, iframe") == []
      assert Floki.text(document) =~ "previous.png"
      assert Floki.text(document) =~ "portrait.png"
      assert Floki.find(document, "button[phx-click=remove_upload]") != []
      assert Floki.find(document, "button[phx-click=cancel_upload]") != []
    end

    test "built-in image and PDF previews use the same stored and pending renderer" do
      image = %Phoenix.LiveView.UploadEntry{
        ref: "picked-image",
        upload_ref: "attachment-upload",
        client_name: "portrait.png",
        client_type: "image/png"
      }

      pdf = %Phoenix.LiveView.UploadEntry{
        ref: "picked-pdf",
        upload_ref: "attachment-upload",
        client_name: "document.pdf",
        client_type: "application/pdf"
      }

      upload = %Phoenix.LiveView.UploadConfig{
        name: :attachment,
        ref: "attachment-upload",
        accept: :any,
        max_entries: 3,
        entries: [image, pdf]
      }

      document =
        render_component(&CoreComponents.input/1,
          type: "file",
          upload: upload,
          preview: true,
          stored: ["/uploads/previous.png", "/uploads/document.PDF?token=preview"]
        )
        |> Floki.parse_document!()

      assert Floki.find(document, "img[src='/uploads/previous.png'][alt='previous.png']") != []

      assert Floki.find(
               document,
               "img[data-phx-entry-ref=picked-image][data-phx-upload-ref=attachment-upload][alt='portrait.png']"
             ) != []

      assert Floki.find(
               document,
               "[phx-hook=UploadPdfPreview][data-entry-ref=picked-pdf] iframe[data-pdf-viewer][title='PDF preview of document.pdf']"
             ) != []

      assert Floki.find(
               document,
               "[phx-hook=UploadPdfPreview][data-pdf-url='/uploads/document.PDF?token=preview'] iframe"
             ) != []

      assert length(
               Floki.find(document, "[data-pdf-open][target=_blank][rel='noopener noreferrer']")
             ) == 2

      assert Floki.find(document, "canvas") == []
      assert Floki.find(document, "[class~='grid-cols-[1fr_1fr_1fr_1fr]']") != []
    end

    test "a single pending file hides the stored frame while retaining its media and removal state" do
      entry = %Phoenix.LiveView.UploadEntry{
        ref: "picked-image",
        upload_ref: "attachment-upload",
        client_name: "portrait.png",
        client_type: "image/png"
      }

      upload = %Phoenix.LiveView.UploadConfig{
        name: :attachment,
        ref: "attachment-upload",
        accept: :any,
        max_entries: 1,
        entries: [entry]
      }

      document =
        render_component(&CoreComponents.input/1,
          type: "file",
          upload: upload,
          preview: true,
          stored: ["/uploads/previous.png"]
        )
        |> Floki.parse_document!()

      assert Floki.find(document, "[data-file-stored].hidden img[src='/uploads/previous.png']") !=
               []

      assert Floki.find(document, "[data-file-entry-ref=picked-image]:not(.hidden) img") != []
      assert Floki.find(document, "input#attachment-upload[multiple]") == []

      assert Floki.find(
               document,
               "[data-file-stored] button[phx-value-url='/uploads/previous.png']"
             ) != []
    end

    test "editor configuration preserves native multipart selection with previews enabled" do
      for editor <- [false, true, %{width: 512, height: 256}, %{ratio: 16 / 9}] do
        document =
          render_component(&CoreComponents.input/1,
            id: "portrait",
            name: "profile[portrait]",
            type: "file",
            editor: editor,
            preview: true,
            required: true
          )
          |> Floki.parse_document!()

        [encoded] = Floki.attribute(document, "#portrait-file-input", "data-file-editor")
        assert Jason.decode!(encoded) == Jason.decode!(Jason.encode!(editor))

        assert Floki.find(
                 document,
                 "input#portrait[data-file-input][type=file][name='profile[portrait]'][required]"
               ) != []

        assert Floki.find(document, "input#portrait[value]") == []
        assert Floki.find(document, "[data-file-preview-region]") != []

        if editor == false do
          assert Floki.find(document, "template[data-file-editor-template]") == []
        else
          assert Floki.find(document, "template[data-file-editor-template] dialog.file-editor") !=
                   []

          assert Floki.find(
                   document,
                   "template cropper-image[alt='Image to edit'][rotatable][scalable][translatable]"
                 ) != []

          assert Floki.find(
                   document,
                   "template cropper-selection[initial-coverage='0.8'][min-inset='0'][movable][resizable]"
                 ) != []

          assert Floki.find(document, "template button[data-editor-action=cancel][disabled]") ==
                   []

          assert Floki.find(document, "template button[data-editor-action=confirm][disabled]") !=
                   []
        end
      end
    end

    test "invalid image editor options fail clearly at the component boundary" do
      for editor <- [
            nil,
            "true",
            %{},
            %{width: 512},
            %{height: 512},
            %{width: 0, height: 1},
            %{width: 1.5, height: 1},
            %{width: 1, height: 1, ratio: 1},
            %{ratio: 0},
            %{ratio: -1},
            %{ratio: "1"}
          ] do
        assert_raise ArgumentError, ~r/editor must be/, fn ->
          render_component(&CoreComponents.input/1,
            id: "portrait",
            name: "portrait",
            type: "file",
            editor: editor
          )
        end
      end

      assert_raise ArgumentError, "image editing requires single or singles selection", fn ->
        render_component(&CoreComponents.input/1,
          id: "portrait",
          name: "portrait",
          type: "file",
          editor: true,
          multiple: true
        )
      end

      assert_raise ArgumentError, "image editing requires preview: true", fn ->
        render_component(&CoreComponents.input/1,
          id: "portrait",
          name: "portrait",
          type: "file",
          editor: true
        )
      end

      for upload <- [
            %Phoenix.LiveView.UploadConfig{
              name: :attachment,
              ref: "attachment-upload",
              accept: :any,
              max_entries: 2
            },
            %Phoenix.LiveView.UploadConfig{
              name: :attachment,
              ref: "attachment-upload",
              accept: :any,
              auto_upload?: true
            }
          ] do
        assert_raise ArgumentError, fn ->
          render_component(&CoreComponents.input/1,
            type: "file",
            upload: upload,
            editor: true,
            preview: true
          )
        end
      end
    end

    test "singles retain the complete upload queue behind one preview and an individual picker" do
      image = %Phoenix.LiveView.UploadEntry{
        ref: "picked-image",
        upload_ref: "attachment-upload",
        client_name: "portrait.png",
        client_type: "image/png",
        preflighted?: true
      }

      pdf = %Phoenix.LiveView.UploadEntry{
        ref: "picked-pdf",
        upload_ref: "attachment-upload",
        client_name: "document.pdf",
        client_type: "application/pdf",
        preflighted?: true,
        done?: true
      }

      upload = %Phoenix.LiveView.UploadConfig{
        name: :attachment,
        ref: "attachment-upload",
        accept: :any,
        max_entries: 3,
        entries: [image, pdf]
      }

      document =
        render_component(&CoreComponents.input/1,
          type: "file",
          upload: upload,
          selection: "singles",
          preview: true,
          editor: %{ratio: 1},
          stored: ["/uploads/previous.png", "/images/logo.svg"]
        )
        |> Floki.parse_document!()

      assert Floki.find(
               document,
               "[phx-hook=FileInput][data-file-selection=singles][data-file-max-entries='3']"
             ) != []

      assert Floki.find(document, "input#attachment-upload[multiple]") == []

      assert Floki.attribute(document, "input#attachment-upload", "data-phx-active-refs") == [
               "picked-image,picked-pdf"
             ]

      assert Floki.attribute(document, "input#attachment-upload", "data-phx-done-refs") == [
               "picked-pdf"
             ]

      assert Floki.attribute(document, "input#attachment-upload", "data-phx-preflighted-refs") ==
               ["picked-image,picked-pdf"]

      assert Floki.attribute(document, "[phx-hook=FileInput]", "data-file-entry-refs") == [
               Jason.encode!(["picked-image", "picked-pdf"])
             ]

      assert length(Floki.find(document, "[data-file-item]")) == 4
      assert length(Floki.find(document, "[data-file-item]:not([hidden])")) == 1

      assert Floki.find(document, "[data-file-key='/uploads/previous.png']:not([hidden]) img") !=
               []

      assert Floki.find(
               document,
               "[data-file-entry-ref=picked-image][hidden] img[data-phx-entry-ref=picked-image]"
             ) != []

      assert Floki.find(
               document,
               "[data-file-entry-ref=picked-pdf][hidden] [phx-hook=UploadPdfPreview]"
             ) != []

      assert Floki.find(
               document,
               "button[data-file-cycle=previous]:not([hidden]), button[data-file-cycle=next]:not([hidden])"
             )
             |> length() == 2

      assert Floki.find(document, "button[data-file-edit='/uploads/previous.png']") != []
      assert Floki.find(document, "button[data-file-edit=picked-image]") != []

      assert Floki.find(
               document,
               "[data-file-key='/images/logo.svg'] [data-file-edit], [data-file-key=picked-pdf] [data-file-edit]"
             ) == []

      assert Floki.find(
               document,
               "#attachment-upload-file-replacements[data-file-replacements][phx-update=ignore]"
             ) != []
    end

    test "explicit single selection requires a one-entry LiveView queue" do
      upload = %Phoenix.LiveView.UploadConfig{
        name: :attachment,
        ref: "attachment-upload",
        accept: :any,
        max_entries: 3
      }

      assert_raise ArgumentError, "single selection requires max_entries: 1", fn ->
        render_component(&CoreComponents.input/1,
          type: "file",
          upload: upload,
          selection: "single"
        )
      end
    end

    test "singles show a count while their genuine native picker remains focusable" do
      for {stored, count} <- [
            {[], "0 files"},
            {["/uploads/previous.png"], "1 file"},
            {["/uploads/previous.png", "/uploads/document.pdf"], "2 files"}
          ] do
        document =
          render_component(&CoreComponents.input/1,
            id: "portraits",
            name: "portraits",
            type: "file",
            selection: "singles",
            preview: true,
            stored: stored
          )
          |> Floki.parse_document!()

        assert Floki.text(
                 Floki.find(document, "[data-file-name][data-file-count][aria-live=polite]")
               ) == count

        assert Floki.find(
                 document,
                 "label[for=portraits] input#portraits[type=file].sr-only.peer:not([disabled]):not([multiple])"
               ) != []

        assert Floki.find(document, "input#portraits[tabindex='-1']") == []

        assert Floki.attribute(document, "[data-file-name]", "data-file-default-name") == [
                 "Choose a file"
               ]

        assert Floki.find(
                 document,
                 "[data-file-preview-region][phx-update=ignore] [data-file-preview-caption][data-file-caption][hidden]"
               ) != []
      end
    end

    test "singles thumbnail hover captions keep slot filenames inside the preview" do
      image = %Phoenix.LiveView.UploadEntry{
        ref: "picked-image",
        upload_ref: "attachment-upload",
        client_name: "new-portrait.png",
        client_type: "image/png"
      }

      assigns = %{
        upload: %Phoenix.LiveView.UploadConfig{
          name: :attachment,
          ref: "attachment-upload",
          accept: :any,
          max_entries: 3,
          entries: [image]
        },
        saved: "data:image/png;base64,c2F2ZWQ="
      }

      document =
        rendered_to_string(~H"""
        <CoreComponents.input type="file" upload={@upload} selection="singles" preview stored={[@saved]}>
          <:preview_caption>saved-portrait.png</:preview_caption>

          <:pending_caption :let={entry}>{entry.client_name}</:pending_caption>
        </CoreComponents.input>
        """)
        |> Floki.parse_document!()

      assert Floki.text(Floki.find(document, "[data-file-name][data-file-count]")) == "2 files"

      assert Floki.text(
               Floki.find(
                 document,
                 "[data-file-stored] > [data-file-preview-as=thumbnail] > [data-file-caption]"
               )
             )
             |> String.trim() == "saved-portrait.png"

      assert Floki.text(
               Floki.find(
                 document,
                 "[data-file-entry-ref=picked-image] > [data-file-preview-as=thumbnail] > [data-file-caption]"
               )
             )
             |> String.trim() == "new-portrait.png"

      assert Floki.find(
               document,
               "[data-file-item] > [data-file-caption], [data-file-item] > span"
             ) == []

      assert Floki.find(
               document,
               "[data-file-collection] > button[data-file-cycle=previous][aria-label='Previous file'], [data-file-collection] > button[data-file-cycle=next][aria-label='Next file']"
             )
             |> length() == 2

      assert Floki.find(
               document,
               "[data-file-cycle][class*=bg-], [data-file-cycle][class*=border]"
             ) == []

      assert Floki.find(document, "[data-file-collection][class*=grid-cols-]") == []
    end

    test "singles read-only modes retain a count alongside their stored previews" do
      upload = %Phoenix.LiveView.UploadConfig{
        name: :attachment,
        ref: "attachment-upload",
        accept: :any,
        max_entries: 3
      }

      document =
        render_component(&CoreComponents.input/1,
          type: "file",
          upload: upload,
          selection: "singles",
          preview: true,
          render_as: "text-disabled",
          stored: ["/uploads/first.png", "/uploads/second.png"]
        )
        |> Floki.parse_document!()

      assert Floki.text(Floki.find(document, "[data-file-readonly-name]")) == "2 files"
      assert Floki.find(document, "input#attachment-upload[disabled]") != []
      assert length(Floki.find(document, "[data-file-item]")) == 2
    end

    test "singles count preserves floating labels and plain text-mode controls" do
      for mode <- ["enabled", "text"] do
        document =
          render_component(&CoreComponents.input/1,
            id: "portraits",
            name: "portraits",
            type: "file",
            selection: "singles",
            preview: true,
            label: "Portraits",
            render_as: mode
          )
          |> Floki.parse_document!()

        assert Floki.text(Floki.find(document, "[data-file-name]")) == "0 files"

        if mode == "enabled" do
          assert Floki.find(
                   document,
                   "input.sr-only.peer.input-floating-control + .input-floating-label"
                 ) != []

          assert Floki.find(document, "[data-file-name][data-file-count]") != []
        else
          assert Floki.find(
                   document,
                   "input.input-floating-control, [data-file-count], .input-floating-label"
                 ) == []

          assert Floki.find(document, "[data-file-name].block:not(.hidden)") != []
        end
      end
    end

    test "multiple selection keeps filenames below its thumbnails" do
      document =
        render_component(&CoreComponents.input/1,
          type: "file",
          upload: %Phoenix.LiveView.UploadConfig{
            name: :attachment,
            ref: "attachment-upload",
            accept: :any,
            max_entries: 3
          },
          selection: "multiple",
          preview: true,
          stored: ["/uploads/previous.png"]
        )
        |> Floki.parse_document!()

      assert Floki.find(document, "[data-file-count], [data-file-caption], input.sr-only") == []

      assert Floki.text(Floki.find(document, "[data-file-item] > span")) |> String.trim() ==
               "previous.png"
    end

    test "single thumbnails keep custom and pending filenames inside inline and detached previews" do
      for preview_id <- [nil, "portrait-preview"] do
        assigns = %{
          preview_id: preview_id,
          upload: %Phoenix.LiveView.UploadConfig{
            name: :attachment,
            ref: "attachment-upload",
            accept: :any,
            max_entries: 1,
            entries: [
              %Phoenix.LiveView.UploadEntry{
                ref: "picked-image",
                upload_ref: "attachment-upload",
                client_name: "new-portrait.png",
                client_type: "image/png"
              }
            ]
          }
        }

        document =
          rendered_to_string(~H"""
          <CoreComponents.input
            type="file"
            upload={@upload}
            stored={["/uploads/previous.png"]}
            preview
            preview_id={@preview_id}
          >
            <:stored_preview :let={url}><img src={url} alt="Custom portrait" /></:stored_preview>

            <:preview_caption>saved-portrait.png</:preview_caption>

            <:pending_caption :let={pending_entry}>{pending_entry.client_name}</:pending_caption>
          </CoreComponents.input>
          """)
          |> Floki.parse_document!()

        assert Floki.text(
                 Floki.find(
                   document,
                   "[data-file-key='/uploads/previous.png'] > [data-file-preview-as=thumbnail] > [data-file-caption][data-file-filename]"
                 )
               )
               |> String.trim() == "saved-portrait.png"

        assert Floki.text(
                 Floki.find(
                   document,
                   "[data-file-key=picked-image] > [data-file-preview-as=thumbnail] > [data-file-caption][data-file-filename]"
                 )
               )
               |> String.trim() == "new-portrait.png"

        assert Floki.find(
                 document,
                 "[data-file-key='/uploads/previous.png'] img[alt='Custom portrait']"
               ) != []

        assert Floki.find(document, "[data-file-item] > [data-file-filename]") == []
      end
    end

    test "singles filename chips leave room for navigation inside the full preview width" do
      document =
        render_component(&CoreComponents.input/1,
          id: "attachments",
          name: "attachments",
          type: "file",
          selection: "singles",
          preview: true,
          preview_as: "tag",
          stored: ["/uploads/first.png", "/uploads/second.pdf"]
        )
        |> Floki.parse_document!()

      assert Floki.find(
               document,
               "[data-file-collection].mt-1 [data-file-server-previews].grid:not(.flex)"
             ) != []

      assert Floki.find(
               document,
               "[data-file-item] > [data-file-preview-as=tag].px-9:not(.mr-1):not(.mt-1)"
             )
             |> length() == 2

      assert Floki.find(document, "[data-file-preview-container][data-file-preview-as=tag].px-9") !=
               []

      assert Floki.find(
               document,
               "[data-file-collection] > button[data-file-cycle=previous], [data-file-collection] > button[data-file-cycle=next]"
             )
             |> length() == 2

      assert Floki.text(Floki.find(document, "[data-file-key='/uploads/first.png']")) =~
               "first.png"
    end

    test "single and singles without previews show slot filenames inside the input and retain parked actions" do
      for {selection, max_entries, expected_name} <- [
            {"single", 1, "new-portrait.png"},
            {"singles", 3, "saved-portrait.png"}
          ] do
        entry = %Phoenix.LiveView.UploadEntry{
          ref: "picked-image",
          upload_ref: "attachment-upload",
          client_name: "new-portrait.png",
          client_type: "image/png"
        }

        assigns = %{
          selection: selection,
          upload: %Phoenix.LiveView.UploadConfig{
            name: :attachment,
            ref: "attachment-upload",
            accept: :any,
            max_entries: max_entries,
            entries: [entry]
          },
          saved: "data:image/png;base64,c2F2ZWQ="
        }

        document =
          rendered_to_string(~H"""
          <CoreComponents.input type="file" upload={@upload} selection={@selection} stored={[@saved]}>
            <:preview_caption>saved-portrait.png</:preview_caption>

            <:pending_caption :let={pending_entry}>{pending_entry.client_name}</:pending_caption>
          </CoreComponents.input>
          """)
          |> Floki.parse_document!()

        assert Floki.text(Floki.find(document, "[data-file-control] [data-file-name]"))
               |> String.trim() == expected_name

        assert Floki.find(document, "[data-file-control] button[data-file-clear]") != []

        assert Floki.find(
                 document,
                 "label button[data-file-clear], label [data-file-cycle-input]"
               ) == []

        assert Floki.find(
                 document,
                 "[data-file-collection][hidden] [data-file-item] [data-file-filename]"
               )
               |> length() == 2

        assert Floki.find(
                 document,
                 "[data-file-collection][hidden] button[data-file-remove][phx-click=cancel_upload][phx-value-ref=picked-image]"
               ) != []

        assert Floki.find(
                 document,
                 "[data-file-cycle], [data-file-preview-position], [data-file-count]"
               ) == []

        if selection == "singles" do
          assert Floki.text(Floki.find(document, "[data-file-control] [data-file-position]")) ==
                   "1/2"

          assert Floki.find(
                   document,
                   "[data-file-control] button[data-file-cycle-input=next][data-file-next] .hero-chevron-up-micro"
                 ) != []

          assert Floki.find(
                   document,
                   "[data-file-control] button[data-file-cycle-input=previous][data-file-previous] .hero-chevron-down-micro"
                 ) != []
        else
          assert Floki.find(document, "[data-file-position], [data-file-cycle-input]") == []
        end
      end
    end

    test "singles filename navigation remains in the input and disabled until a collection exists" do
      document =
        render_component(&CoreComponents.input/1,
          id: "attachments",
          name: "attachments",
          type: "file",
          selection: "singles"
        )
        |> Floki.parse_document!()

      assert Floki.text(Floki.find(document, "[data-file-name]")) == "Choose a file"
      assert Floki.text(Floki.find(document, "[data-file-position]")) == "0/0"
      assert length(Floki.find(document, "[data-file-cycle-input][disabled]:not([hidden])")) == 2

      assert Floki.find(
               document,
               "label[for=attachments] input#attachments.sr-only.peer:not([disabled])"
             ) != []
    end

    test "compact read-only file fields shade their wrapper once and retain collection browsing" do
      for mode <- ["disabled", "like-disabled"] do
        document =
          render_component(&CoreComponents.input/1,
            id: "attachments",
            name: "attachments",
            type: "file",
            selection: "singles",
            render_as: mode,
            stored: ["/uploads/first.png", "/uploads/second.pdf"]
          )
          |> Floki.parse_document!()

        assert Floki.find(document, "[data-file-control].overlay-dark") != []
        assert Floki.find(document, "[data-file-name].overlay-dark") == []
        assert Floki.find(document, "[data-file-name].text-subcontent") != []
        assert Floki.find(document, "input#attachments[disabled]") != []
        assert length(Floki.find(document, "[data-file-cycle-input]:not([disabled])")) == 2
        assert Floki.find(document, "[data-file-clear][disabled]") != []
      end
    end

    test "native selection modes control only picker cardinality and retain the local editor surface" do
      for selection <- ["single", "singles", "multiple"] do
        document =
          render_component(&CoreComponents.input/1,
            id: "portrait",
            name: "portrait",
            type: "file",
            selection: selection,
            preview: true,
            editor: selection != "multiple",
            multiple: true
          )
          |> Floki.parse_document!()

        assert Floki.attribute(document, "#portrait-file-input", "data-file-selection") == [
                 selection
               ]

        assert Floki.find(document, "input#portrait[multiple]") != [] == (selection == "multiple")

        assert Floki.find(
                 document,
                 "[data-file-preview-region][phx-update=ignore] button[data-file-edit][hidden]"
               ) != []

        assert length(Floki.find(document, "[data-file-cycle]")) ==
                 if(selection == "singles", do: 2, else: 0)
      end
    end

    test "image edit controls follow file types, preview layout, and each mode's editability" do
      for mode <-
            ~w(enabled disabled like-enabled like-disabled hidden hidden-enabled hidden-disabled text text-enabled text-disabled),
          preview_as <- ["tag", "thumbnail"] do
        upload = %Phoenix.LiveView.UploadConfig{
          name: :attachment,
          ref: "attachment-upload",
          accept: :any,
          max_entries: 3
        }

        document =
          render_component(&CoreComponents.input/1,
            type: "file",
            upload: upload,
            selection: "singles",
            preview: true,
            editor: true,
            preview_as: preview_as,
            render_as: mode,
            stored: ["/uploads/previous.webp", "/images/logo.svg", "/uploads/document.pdf"]
          )
          |> Floki.parse_document!()

        editable = mode in ~w(enabled text text-enabled hidden hidden-enabled)

        assert Floki.find(document, "button[data-file-edit='/uploads/previous.webp']") != [] ==
                 editable

        assert Floki.find(
                 document,
                 "[data-file-key='/images/logo.svg'] [data-file-edit], [data-file-key='/uploads/document.pdf'] [data-file-edit]"
               ) == []
      end
    end

    test "text file thumbnails remain picker labels when custom media has no caption" do
      entry = %Phoenix.LiveView.UploadEntry{
        ref: "picked-image",
        upload_ref: "attachment-upload",
        client_name: "portrait.png",
        client_type: "image/png"
      }

      for mode <- ["text", "text-enabled"] do
        assigns = %{
          mode: mode,
          upload: %Phoenix.LiveView.UploadConfig{
            name: :attachment,
            ref: "attachment-upload",
            accept: :any,
            max_entries: 2,
            entries: [entry]
          }
        }

        document =
          rendered_to_string(~H"""
          <CoreComponents.input
            upload={@upload}
            type="file"
            render_as={@mode}
            stored={["/uploads/previous.png"]}
            preview_as="thumbnail"
          >
            <:stored_preview :let={url}><img src={url} alt="Stored portrait" /></:stored_preview>

            <:pending_preview :let={pending_entry}>
              <.live_img_preview entry={pending_entry} alt="Pending portrait" />
            </:pending_preview>
          </CoreComponents.input>
          """)
          |> Floki.parse_document!()

        assert Floki.find(document, "input#attachment-upload.sr-only") != []

        assert Floki.find(
                 document,
                 "[data-file-stored] label[for=attachment-upload] img[alt='Stored portrait']"
               ) != []

        assert Floki.find(
                 document,
                 "[data-file-entry-ref=picked-image] label[for=attachment-upload] img[alt='Pending portrait']"
               ) != []
      end
    end

    test "native read-only file modes expose their server filename to the client hook" do
      for mode <- ["disabled", "like-enabled", "like-disabled", "text-disabled"] do
        document =
          render_component(&CoreComponents.input/1,
            id: "portrait",
            name: "portrait",
            type: "file",
            render_as: mode,
            value: "portrait.png"
          )
          |> Floki.parse_document!()

        assert Floki.find(document, "input#portrait[data-file-input][disabled]") != []

        assert Floki.attribute(document, "[data-file-readonly-name]", "data-file-default-name") ==
                 ["portrait.png"]

        assert Floki.text(Floki.find(document, "[data-file-readonly-name]")) == "portrait.png"
      end
    end

    test "native file previews expose the resolved layout and a selection clear control" do
      for preview_as <- [nil, "tag", "thumbnail"] do
        document =
          render_component(&CoreComponents.input/1,
            id: "portrait",
            name: "portrait",
            type: "file",
            preview: true,
            preview_as: preview_as
          )
          |> Floki.parse_document!()

        expected = preview_as || "thumbnail"

        assert Floki.attribute(document, "#portrait-file-input", "data-file-preview-as") == [
                 expected
               ]

        assert Floki.attribute(document, "[data-file-preview-container]", "data-file-preview-as") ==
                 [expected]

        assert Floki.attribute(document, "[data-file-preview-container]", "phx-update") == []

        assert Floki.find(
                 document,
                 "[data-file-preview-container][hidden] > [data-file-preview-region][phx-update=ignore].contents"
               ) != []

        assert Floki.find(
                 document,
                 "button[data-file-clear][type=button][hidden][aria-label='Clear selected file']"
               ) != []

        assert Floki.find(document, "button[data-file-clear][disabled]") == []
      end
    end

    test "native file fields retain their disabled input and preview region in hidden-disabled mode" do
      document =
        render_component(&CoreComponents.input/1,
          id: "portrait",
          name: "portrait",
          type: "file",
          label: "Portrait",
          preview: true,
          render_as: "hidden-disabled",
          required: true
        )
        |> Floki.parse_document!()

      assert Floki.find(
               document,
               "#portrait-file-input.hidden[phx-hook=FileInput] input#portrait[disabled][required]"
             ) != []

      assert Floki.find(
               document,
               "#portrait-file-local-preview[phx-update=ignore][data-file-preview-region]"
             ) != []

      assert Floki.find(document, "button[data-file-clear][hidden][disabled]") != []
      assert length(Floki.find(document, "span[aria-hidden=true].text-error")) == 1
    end
  end

  describe "required input labels" do
    test "native controls retain required and mark their label once" do
      types =
        ~w(email file number password search text url textarea date datetime-local time week month checkbox switch radio)

      for {type, variant} <-
            Enum.map(types, &{&1, "default"}) ++
              [{"checkbox", "alt"}, {"switch", "alt"}, {"radio", "card"}] do
        value =
          case type do
            "number" -> 7
            type when type in ["checkbox", "switch"] -> true
            _type -> "email"
          end

        assigns = %{type: type, variant: variant, value: value}

        html =
          rendered_to_string(~H"""
          <CoreComponents.input
            id="contact"
            name="contact"
            type={@type}
            variant={@variant}
            value={@value}
            label="Contact"
            options={[{"Email", "email"}, {"Phone", "phone"}]}
            required
          />
          """)

        document = Floki.parse_document!(html)
        markers = Floki.find(document, "span[aria-hidden=true].text-error")

        assert length(markers) == 1, "#{type}/#{variant} must have one required marker"
        assert Floki.text(markers) == "*"

        assert length(
                 Floki.find(
                   document,
                   "input[name=contact][required], textarea[name=contact][required]"
                 )
               ) ==
                 if(type == "radio", do: 2, else: 1)

        assert Floki.find(document, "input[novalidate], textarea[novalidate]") == []

        if type == "radio" do
          assert Floki.find(document, "legend span[aria-hidden=true]") == markers
          assert Floki.find(document, "label span[aria-hidden=true]") == []
        end
      end
    end

    test "display modes show one marker and keep required on hidden submission controls" do
      for type <- ~w(text textarea date checkbox switch radio),
          render_as <-
            ~w(disabled like-enabled like-disabled text-disabled text text-enabled hidden hidden-enabled) do
        assigns = %{type: type, render_as: render_as}

        html =
          rendered_to_string(~H"""
          <CoreComponents.input
            id="contact"
            name="contact"
            type={@type}
            value="email"
            label="Contact"
            options={[{"Email", "email"}, {"Phone", "phone"}]}
            render_as={@render_as}
            required
          />
          """)

        document = Floki.parse_document!(html)

        assert length(Floki.find(document, "span[aria-hidden=true].text-error")) == 1,
               "#{type}/#{render_as} must not duplicate the marker"

        if render_as in ["like-disabled", "text-disabled", "hidden", "hidden-enabled"] do
          assert Floki.find(document, ".hidden [name=contact][required]") != []
        end

        if render_as in ["like-disabled", "text-disabled"] do
          assert Floki.find(document, ".hidden span[aria-hidden=true].text-error") == []
        end
      end
    end

    test "optional, explicitly false, and unlabeled inputs have no marker" do
      for {required, label} <- [
            {nil, "Required"},
            {false, "Contact Required"},
            {true, nil},
            {true, ""}
          ] do
        assigns = %{required: required, label: label}

        html =
          rendered_to_string(~H"""
          <CoreComponents.input
            id="contact"
            name="contact"
            type="text"
            value=""
            label={@label}
            required={@required}
            placeholder="Enter contact details"
          />
          """)

        document = Floki.parse_document!(html)
        assert Floki.find(document, "span[aria-hidden=true].text-error") == []
        assert Floki.attribute(document, "input", "placeholder") == ["Enter contact details"]
        assert Floki.find(document, "input[required]") != [] == (required == true)
      end
    end

    test "HTML boolean attribute values mark labeled controls without normalizing their attributes" do
      for required <- [true, "", "required"] do
        assigns = %{required: required}

        html =
          rendered_to_string(~H"""
          <CoreComponents.input name="contact" value="" label="Contact" required={@required} />
          """)

        document = Floki.parse_document!(html)
        assert length(Floki.find(document, "span[aria-hidden=true].text-error")) == 1
        assert Floki.find(document, "input[name=contact][required]") != []
      end
    end

    test "form-field and tooltip delegation preserve one marker, labels, and placeholders" do
      assigns = %{form: to_form(%{"email" => "person@example.com"}, as: :account)}

      html =
        rendered_to_string(~H"""
        <CoreComponents.input
          field={@form[:email]}
          type="email"
          label="Email"
          placeholder="Enter an email address"
          tooltip="Used for signing in"
          required
        />
        """)

      document = Floki.parse_document!(html)
      assert length(Floki.find(document, "span[aria-hidden=true].text-error")) == 1

      assert Floki.find(document, "[data-tooltip='Used for signing in'] label[for=account_email]") !=
               []

      assert Floki.find(
               document,
               "input#account_email[name='account[email]'][required][value='person@example.com']"
             ) != []

      assert Floki.attribute(document, "input", "placeholder") == ["Enter an email address"]
      assert Floki.find(document, ".input-floating-label-hidden span[aria-hidden=true]") != []
    end

    test "disabled comboboxes keep one required label and their submitted option values" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.input
          id="role"
          name="role"
          type="combobox"
          value="viewer"
          label="Role"
          options={[{"Viewer", "viewer"}]}
          disabled
          required
        />
        """)

      document = Floki.parse_document!(html)
      assert length(Floki.find(document, "span[aria-hidden=true].text-error")) == 1
      assert Floki.find(document, "input#role[disabled][required][value=Viewer]") != []
      assert Floki.find(document, "input[type=hidden][name=role][value=viewer]") != []
      assert [classes] = Floki.attribute(document, "input#role", "class")
      assert "disabled:overlay-dark" in String.split(classes)
    end

    test "upload controls and their read-only previews retain one required label" do
      for render_as <-
            ~w(enabled disabled like-enabled like-disabled text-disabled text text-enabled hidden hidden-enabled hidden-disabled) do
        assigns = %{
          render_as: render_as,
          upload: %Phoenix.LiveView.UploadConfig{
            name: :attachment,
            ref: "attachment-upload",
            accept: :any
          }
        }

        html =
          rendered_to_string(~H"""
          <CoreComponents.input
            upload={@upload}
            type="file"
            label="Attachment"
            render_as={@render_as}
            required
          />
          """)

        document = Floki.parse_document!(html)
        assert length(Floki.find(document, "span[aria-hidden=true].text-error")) == 1

        if render_as in ["enabled", "text", "text-enabled", "hidden", "hidden-enabled"] do
          assert Floki.find(document, "input#attachment-upload[type=file][required]") != []
          assert Floki.find(document, "input#attachment-upload[disabled]") == []
        else
          assert Floki.find(
                   document,
                   "label[for=attachment-upload] input#attachment-upload.sr-only[type=file][required][disabled]"
                 ) != []
        end
      end
    end

    test "pending image previews retain their upload references and respect each mode's editability" do
      for render_as <-
            ~w(disabled like-enabled like-disabled text-disabled text text-enabled hidden-disabled) do
        entry = %Phoenix.LiveView.UploadEntry{
          ref: "picked-image",
          upload_ref: "attachment-upload",
          client_name: "portrait.png",
          client_type: "image/png"
        }

        assigns = %{
          render_as: render_as,
          upload: %Phoenix.LiveView.UploadConfig{
            name: :attachment,
            ref: "attachment-upload",
            accept: :any,
            entries: [entry]
          }
        }

        html =
          rendered_to_string(~H"""
          <CoreComponents.input
            upload={@upload}
            type="file"
            label="Attachment"
            render_as={@render_as}
            disabled={false}
          >
            <:pending_preview :let={pending_entry}>
              <.live_img_preview entry={pending_entry} />
            </:pending_preview>
          </CoreComponents.input>
          """)

        document = Floki.parse_document!(html)

        if render_as in ["text", "text-enabled"] do
          assert Floki.find(
                   document,
                   "label[for=attachment-upload] input#attachment-upload.sr-only[data-phx-active-refs=picked-image]"
                 ) != []

          assert Floki.find(document, "input#attachment-upload[disabled]") == []

          assert Floki.find(
                   document,
                   "button[phx-click=cancel_upload][phx-value-ref=picked-image]"
                 ) != []
        else
          assert Floki.find(
                   document,
                   "label[for=attachment-upload] input#attachment-upload.sr-only[disabled][data-phx-active-refs=picked-image]"
                 ) != []

          assert Floki.find(document, "button[phx-click=cancel_upload]") == []
        end

        assert Floki.find(
                 document,
                 "img[data-phx-upload-ref=attachment-upload][data-phx-entry-ref=picked-image]"
               ) != []
      end
    end

    test "enabled uploads respect explicit disabled and hidden-disabled retains the native input" do
      assigns = %{
        upload: %Phoenix.LiveView.UploadConfig{
          name: :attachment,
          ref: "attachment-upload",
          accept: :any
        }
      }

      enabled =
        rendered_to_string(~H"""
        <CoreComponents.input upload={@upload} type="file" label="Attachment" disabled />
        """)

      assert Floki.find(
               Floki.parse_document!(enabled),
               "label:not(.hidden) input#attachment-upload[disabled]"
             ) != []

      excluded =
        rendered_to_string(~H"""
        <CoreComponents.input
          upload={@upload}
          type="file"
          label="Attachment"
          render_as="hidden-disabled"
        />
        """)

      assert Floki.find(
               Floki.parse_document!(excluded),
               "div.hidden label[for=attachment-upload] input#attachment-upload.sr-only[disabled]"
             ) != []
    end

    test "hidden inputs and excluded fields do not create a label marker" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.input type="hidden" name="token" id="token" value="secret" label="Token" required />
        <CoreComponents.input
          name="contact"
          value=""
          label="Contact"
          render_as="hidden-disabled"
          required
        />
        """)

      document = Floki.parse_document!(html)
      assert Floki.find(document, "span[aria-hidden=true].text-error") == []
      assert Floki.find(document, "input#token[required][value=secret]") != []
      assert Floki.find(document, "[name=contact]") == []
    end
  end

  describe "disabled input controls" do
    test "temporal controls retain native disabled state while allowing other attributes to patch" do
      for type <- ~w(date datetime-local time week month), label <- [nil, "Schedule"] do
        document =
          render_component(&CoreComponents.input/1,
            id: "schedule",
            name: "schedule",
            type: type,
            label: label,
            value: "",
            disabled: true,
            required: true,
            errors: ["Schedule is invalid"]
          )
          |> Floki.parse_document!()

        assert Floki.find(
                 document,
                 "input#schedule[disabled][required][readonly][phx-hook=VCalendar]"
               ) != []

        assert Floki.attribute(document, "input#schedule", "phx-update") == []

        assert Floki.attribute(document, "input#schedule", "aria-controls") == [
                 "schedule-calendar"
               ]

        assert Floki.find(
                 document,
                 "#schedule-calendar[popover=auto][data-calendar-popover][data-vc=calendar][data-vc-theme=elixirbits][data-vc-mode=#{type}][phx-update=ignore]"
               ) != []

        assert [classes] = Floki.attribute(document, "input#schedule", "class")
        assert "disabled:overlay-dark" in String.split(classes)
        assert [mounted] = Floki.attribute(document, "input#schedule", "phx-mounted")

        assert [["ignore_attrs", %{"attrs" => ["value", "aria-haspopup", "aria-expanded"]}]] =
                 Jason.decode!(mounted)

        assert Floki.text(document) =~ "Schedule is invalid"
      end
    end

    test "checked controls shade their fields once and retain their muted selection markers" do
      for {type, variant} <- [
            {"checkbox", "default"},
            {"checkbox", "alt"},
            {"switch", "default"},
            {"switch", "alt"},
            {"radio", "default"}
          ] do
        value = if type == "radio", do: "email", else: true

        document =
          render_component(&CoreComponents.input/1,
            id: "contact",
            name: "contact",
            type: type,
            variant: variant,
            value: value,
            label: "Contact",
            options: [{"Email", "email"}, {"Phone", "phone"}],
            disabled: true
          )
          |> Floki.parse_document!()

        assert [classes] = Floki.attribute(document, "input[checked][disabled]", "class")
        assert classes =~ "disabled:checked:bg-secondary"
        assert classes =~ "disabled:checked:border-secondary"

        if type in ["checkbox", "switch"] and variant == "default" do
          assert [field_classes] = Floki.attribute(document, "label[for=contact]", "class")
          assert "has-[:disabled]:overlay-dark" in String.split(field_classes)
          refute "disabled:overlay-dark" in String.split(classes)
        else
          assert "disabled:overlay-dark" in String.split(classes)
        end

        case type do
          "switch" ->
            assert classes =~ "disabled:checked:before:bg-subcontent"
            assert Floki.find(document, "input[type=hidden][name=contact][disabled]") != []

          "checkbox" ->
            assert "checked:bg-control-check" in String.split(classes)

          "radio" ->
            assert "checked:bg-control-radio" in String.split(classes)
            assert Floki.find(document, "fieldset.group legend") != []
        end
      end

      for render_as <- ~w(disabled like-disabled) do
        document =
          render_component(&CoreComponents.input/1,
            id: "active",
            name: "active",
            type: "switch",
            value: true,
            label: "Active",
            render_as: render_as
          )
          |> Floki.parse_document!()

        assert Floki.find(document, "span.bg-secondary.border-secondary") != []
        assert Floki.find(document, "div.overlay-dark") != []
        assert Floki.find(document, "span.overlay-dark") == []
      end
    end

    test "disabled password fields disable the visibility action before the hook mounts" do
      for label <- [nil, "Password"] do
        document =
          render_component(&CoreComponents.input/1,
            id: "password",
            name: "password",
            type: "password",
            label: label,
            value: "secret",
            disabled: true
          )
          |> Floki.parse_document!()

        assert Floki.find(document, "input#password[disabled]") != []
        assert Floki.find(document, "button#password-password-toggle[disabled]") != []
        assert [classes] = Floki.attribute(document, "input#password", "class")
        assert "disabled:overlay-dark" in String.split(classes)
      end
    end

    test "disabled uploads retain previews and disable their remove and cancel actions" do
      entry = %Phoenix.LiveView.UploadEntry{
        ref: "picked-image",
        upload_ref: "attachment-upload",
        client_name: "portrait.png",
        client_type: "image/png"
      }

      assigns = %{
        entry: entry,
        upload: %Phoenix.LiveView.UploadConfig{
          name: :attachment,
          ref: "attachment-upload",
          accept: :any,
          max_entries: 2,
          entries: [entry]
        }
      }

      html =
        rendered_to_string(~H"""
        <CoreComponents.input
          upload={@upload}
          stored={["portrait.png"]}
          type="file"
          label="Attachment"
          disabled
        >
          <:stored_preview :let={url}>{url}</:stored_preview>

          <:pending_preview>{@entry.client_name}</:pending_preview>
        </CoreComponents.input>
        """)

      document = Floki.parse_document!(html)
      assert Floki.find(document, "input#attachment-upload[disabled]") != []
      assert Floki.find(document, "button[phx-click=remove_upload][disabled]") != []
      assert Floki.find(document, "button[phx-click=cancel_upload][disabled]") != []
      assert Floki.text(document) =~ "portrait.png"
      assert [classes] = Floki.attribute(document, "input#attachment-upload", "class")
      assert "disabled:overlay-dark" in String.split(classes)
    end
  end

  describe "record actions" do
    test "hiding the tooltip keeps the action label and respects a supplied accessible label" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.action_button id="back-action" action={:back} tooltip="" />
        <CoreComponents.action_button
          id="custom-action"
          action={:create}
          tooltip=""
          aria-label="Add another entry"
        />
        """)

      document = Floki.parse_document!(html)
      assert Floki.find(document, "#back-action[aria-label=Back]") != []
      assert Floki.find(document, "#custom-action[aria-label='Add another entry']") != []

      for id <- ~w(back-action custom-action) do
        assert Floki.attribute(document, "##{id}", "data-tooltip") in [[], [""]]
      end
    end
  end

  describe "input render_as" do
    test "enabled renders a real input by default" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.input type="text" name="city" value="Ipoh" label="City" />
        """)

      assert html =~ "<input"
      assert html =~ ~s(name="city")
      assert html =~ ~s(value="Ipoh")
    end

    test "disabled renders a lookalike span without an input" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.input
          type="text"
          id="city"
          name="city"
          value="Ipoh"
          label="City"
          render_as="disabled"
        />
        """)

      refute html =~ "<input"
      assert html =~ ~s(id="city")
      assert html =~ "Ipoh"
      assert html =~ "bg-transparent"
      assert html =~ "overlay-dark"
      assert html =~ "cursor-not-allowed"
      assert html =~ "input-floating-control"
      assert html =~ "input-floating-label"
    end

    test "like-enabled renders a lookalike span with the enabled visual" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.input type="text" name="city" value="Ipoh" label="City" render_as="like-enabled" />
        """)

      refute html =~ "<input"
      assert html =~ "Ipoh"
      assert html =~ "bg-transparent"
      assert html =~ "text-content"
      refute html =~ "cursor-not-allowed"
      refute html =~ "overlay-dark"
    end

    test "like-disabled renders a lookalike span plus the real input hidden" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.input
          type="text"
          id="city"
          name="city"
          value="Ipoh"
          label="City"
          render_as="like-disabled"
        />
        """)

      assert html =~ ~s(<div class="hidden">)
      assert html =~ "<input"
      assert html =~ ~s(name="city")
      assert html =~ ~s(value="Ipoh")
      assert html =~ "cursor-not-allowed"
      assert html =~ "overlay-dark"
      assert length(String.split(html, ~s(id="city"))) == 2
    end

    test "hidden renders the real input inside a hidden wrapper" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.input type="text" name="city" value="Ipoh" label="City" render_as="hidden" />
        """)

      assert html =~ ~s(<div class="hidden">)
      assert html =~ "<input"
      assert html =~ ~s(name="city")
      assert html =~ ~s(value="Ipoh")
    end

    test "hidden-disabled renders nothing" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.input
          type="text"
          name="city"
          value="Ipoh"
          label="City"
          render_as="hidden-disabled"
        />
        """)

      assert String.trim(html) == ""
    end

    test "combobox span shows the option label instead of the raw value" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.input
          type="combobox"
          name="state"
          value="prk"
          label="State"
          options={[{"Perak", "prk"}, {"Penang", "png"}]}
          render_as="disabled"
        />
        """)

      refute html =~ "<input"
      assert html =~ "Perak"
      refute html =~ ">prk<"
    end

    test "empty span keeps the floating label centered instead of floated" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.input type="text" name="city" value="" label="City" render_as="disabled" />
        """)

      refute html =~ "input-floating-control"
      assert html =~ "input-floating-label"
    end

    test "checkbox span renders the box visual without a checkbox input" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.input
          type="checkbox"
          name="active"
          value={true}
          label="Active"
          render_as="disabled"
        />
        """)

      refute html =~ "<input"
      assert html =~ "bg-transparent"
      assert html =~ "bg-secondary"
      assert html =~ "cursor-not-allowed"
    end

    test "switch span renders the toggle visual without a checkbox input" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.input
          type="switch"
          name="active"
          value={true}
          label="Active"
          render_as="like-enabled"
        />
        """)

      refute html =~ "<input"
      assert html =~ "rounded-full"
      assert html =~ "before:translate-x-5"
    end

    test "number steppers respect server-rendered disabled, readonly, and any-step state" do
      for attrs <- [[disabled: true], [readonly: true], [step: "any"], [step: "ANY"]] do
        document =
          render_component(
            &CoreComponents.input/1,
            [id: "quantity", name: "quantity", type: "number", value: 4] ++ attrs
          )
          |> Floki.parse_document!()

        assert length(Floki.find(document, "button[data-number-step][disabled]")) == 2
      end

      html =
        render_component(&CoreComponents.input/1,
          id: "quantity",
          name: "quantity",
          type: "number",
          value: 4,
          step: "0.5"
        )

      assert Floki.find(Floki.parse_document!(html), "button[data-number-step][disabled]") == []
    end

    test "text combobox and telephone modes preserve picker selection and composite submission" do
      for render_as <- ~w(text text-enabled) do
        {:ok, view, html} =
          live_isolated(Phoenix.ConnTest.build_conn(), __MODULE__.SelectPreview,
            session: %{"render_as" => render_as}
          )

        document = Floki.parse_document!(html)

        for id <- ["labeled-role", "unlabeled-role"] do
          assert Floki.find(
                   document,
                   "##{id}[phx-hook=PetalComboBox].input-text-wrapper input[type=text]"
                 ) != []
        end

        assert Floki.find(
                 document,
                 "select[name='choices[labeled_role]'] option[value=viewer][selected]"
               ) != []

        assert Floki.find(
                 document,
                 "[phx-hook=TelInput] input[data-tel-composite][name='choices[phone]'][value='+60123456789']"
               ) != []

        assert Floki.find(document, "[phx-hook=TelInput] input[data-tel-number].border-0") != []

        country_label =
          document
          |> Floki.find(
            "#choices_phone_country_code_country_select-trigger [data-pc-combo-trigger-label]"
          )
          |> Floki.text()
          |> String.trim()

        assert country_label == "+60"

        assert Floki.find(
                 document,
                 ".input-floating-wrapper, .input-floating-control, .input-floating-label"
               ) == []

        assert has_element?(view, "#labeled-role [role=option]", "Editor")
        view |> form("#choices-form", choices: %{labeled_role: "editor"}) |> render_change()

        assert has_element?(
                 view,
                 "select[name='choices[labeled_role]'] option[value=editor][selected]"
               )
      end
    end

    test "disabled text comboboxes retain their selected submission value without a floating label" do
      for render_as <- ~w(text text-enabled) do
        document =
          render_component(&CoreComponents.input/1,
            id: "role",
            name: "role",
            type: "combobox",
            value: "viewer",
            label: "Role",
            options: [{"Viewer", "viewer"}],
            render_as: render_as,
            disabled: true,
            required: true
          )
          |> Floki.parse_document!()

        assert Floki.find(
                 document,
                 "input#role[type=text][disabled][required][value=Viewer].border-0"
               ) != []

        assert Floki.find(document, "input[type=hidden][name=role][value=viewer]") != []
        assert Floki.find(document, ".input-floating-control, .input-floating-label") == []
        assert length(Floki.find(document, "span[aria-hidden=true].text-error")) == 1
      end
    end

    test "text file modes retain native pickers behind their plain values" do
      for render_as <- ~w(text text-enabled), disabled <- [false, true] do
        document =
          render_component(&CoreComponents.input/1,
            id: "choice",
            name: "choice",
            type: "file",
            label: "Choice",
            render_as: render_as,
            required: true,
            disabled: disabled,
            placeholder: "Choose a file"
          )
          |> Floki.parse_document!()

        assert Floki.find(
                 document,
                 "[phx-hook=FileInput] input#choice[type=file][name=choice][required]"
               ) != []

        assert Floki.find(document, "input#choice[disabled]") != [] == disabled
        assert Floki.find(document, ".input-floating-control, .input-floating-label") == []
        assert length(Floki.find(document, "span[aria-hidden=true].text-error")) == 1

        assert Floki.attribute(document, "input#choice", "value") == []

        assert Floki.text(Floki.find(document, "[data-file-name]")) |> String.trim() ==
                 "Choose a file"
      end
    end

    test "text password modes expose an editable plain value without a visibility action" do
      for render_as <- ~w(text text-enabled), label <- ["Password", nil] do
        document =
          render_component(&CoreComponents.input/1,
            id: "secret",
            name: "secret",
            type: "password",
            value: "visible-secret",
            label: label,
            render_as: render_as,
            required: true
          )
          |> Floki.parse_document!()

        assert Floki.find(
                 document,
                 "input#secret[type=text][name=secret][value=visible-secret][required]"
               ) != []

        assert Floki.find(
                 document,
                 "input#secret[disabled], [phx-hook=PasswordVisibility], button"
               ) == []

        assert Floki.find(document, "input#secret.border-0") != []
        assert Floki.find(document, ".input-floating-control, .input-floating-label") == []
      end
    end

    test "text calendar modes preserve their picker contract and local values without floating labels" do
      values = %{
        "datetime-local" => "2027-01-01T04:15:00",
        "date" => "2027-01-01",
        "time" => "04:15",
        "week" => "2026-W53",
        "month" => "2027-01"
      }

      for {type, value} <- values,
          render_as <- ~w(text text-enabled),
          label <- ["Schedule", nil] do
        document =
          render_component(&CoreComponents.input/1,
            id: "schedule",
            name: "schedule",
            type: type,
            value: ~U[2026-12-31 20:15:00Z],
            timezone: "Asia/Kuala_Lumpur",
            label: label,
            render_as: render_as,
            required: true
          )
          |> Floki.parse_document!()

        assert Floki.find(
                 document,
                 "input#schedule[type=text][name=schedule][readonly][required][phx-hook=VCalendar]"
               ) != []

        assert Floki.attribute(document, "input#schedule", "value") == [value]
        assert Floki.attribute(document, "input#schedule", "data-vc-value") == [value]
        assert Floki.attribute(document, "input#schedule", "data-vc-mode") == [type]

        assert Floki.attribute(document, "input#schedule", "data-vc-timezone") == [
                 "Asia/Kuala_Lumpur"
               ]

        assert Floki.find(document, "input#schedule.border-0") != []
        assert Floki.find(document, ".input-floating-control, .input-floating-label") == []
        assert Floki.attribute(document, "input#schedule", "phx-mounted") != []

        if label do
          assert Floki.find(document, "label[for=schedule] + input#schedule") != []

          assert Floki.text(Floki.find(document, "label[for=schedule]")) |> String.trim() ==
                   "Schedule*"
        end
      end
    end

    test "editable text checkbox and switch modes use state sentences and retain native toggles" do
      for type <- ~w(checkbox switch),
          render_as <- ~w(text text-enabled),
          checked <- [false, true],
          disabled <- [false, true] do
        document =
          render_component(&CoreComponents.input/1,
            id: "active",
            name: "active",
            type: type,
            value: checked,
            label: "Active",
            render_as: render_as,
            required: true,
            disabled: disabled,
            form: "settings"
          )
          |> Floki.parse_document!()

        assert Floki.find(document, "label[data-boolean-text][for=active]") != []
        assert Floki.find(document, "label.border") == []

        assert Floki.find(
                 document,
                 "input#active[type=checkbox][required][form=settings].sr-only"
               ) != []

        assert Floki.find(document, "input#active[checked]") != [] == checked
        assert Floki.find(document, "input#active[disabled]") != [] == disabled
        assert Floki.find(document, "input[type=hidden][name=active][disabled]") != [] == disabled

        assert Floki.find(document, "input[type=hidden][name=active][value=false][form=settings]") !=
                 []

        assert Floki.find(document, ".bg-control-check, .rounded-full, label.inline-grid") == []
        assert Floki.text(Floki.find(document, "label[for=active]")) =~ "Active"

        assert Floki.attribute(document, "label[for=active] > input", "type") == [
                 "hidden",
                 "checkbox"
               ]

        {checked_text, unchecked_text} =
          if type == "checkbox", do: {"enabled", "disabled"}, else: {"on", "off"}

        assert Floki.text(Floki.find(document, "[data-boolean-state=checked]")) == checked_text

        assert Floki.text(Floki.find(document, "[data-boolean-state=unchecked]")) ==
                 unchecked_text

        assert [checked_classes] =
                 Floki.attribute(document, "[data-boolean-state=checked]", "class")

        assert [unchecked_classes] =
                 Floki.attribute(document, "[data-boolean-state=unchecked]", "class")

        assert "group-has-[input:checked]/boolean:inline" in String.split(checked_classes)
        assert "group-has-[input:checked]/boolean:hidden" in String.split(unchecked_classes)
        assert length(Floki.find(document, "span[aria-hidden=true].text-error")) == 1
      end
    end

    test "custom text boolean styling retains the group that follows native checked state" do
      for type <- ~w(checkbox switch),
          render_as <- ~w(text text-enabled),
          checked <- [false, true] do
        document =
          render_component(&CoreComponents.input/1,
            id: "active",
            name: "active",
            type: type,
            value: checked,
            label: "Active",
            render_as: render_as,
            class: "text-brand"
          )
          |> Floki.parse_document!()

        assert [classes] =
                 Floki.attribute(document, "label[data-boolean-text][for=active]", "class")

        assert "text-brand" in String.split(classes)
        assert "group/boolean" in String.split(classes)
        refute "text-sm" in String.split(classes)
        assert Floki.find(document, "input#active[checked]") != [] == checked

        {checked_text, unchecked_text} =
          if type == "checkbox", do: {"enabled", "disabled"}, else: {"on", "off"}

        assert Floki.text(Floki.find(document, "[data-boolean-state=checked]")) == checked_text

        assert Floki.text(Floki.find(document, "[data-boolean-state=unchecked]")) ==
                 unchecked_text
      end
    end

    test "text-disabled checkbox and switch modes show the current state without a visible toggle" do
      for type <- ~w(checkbox switch), checked <- [false, true] do
        document =
          render_component(&CoreComponents.input/1,
            id: "active",
            name: "active",
            type: type,
            value: checked,
            label: "Active",
            render_as: "text-disabled",
            required: true
          )
          |> Floki.parse_document!()

        assert Floki.find(document, ".hidden input#active[type=checkbox][checked][required]") !=
                 [] == checked

        assert Floki.find(document, ".hidden input#active[type=checkbox][required]") != []

        visible = Floki.filter_out(document, ".hidden, span[aria-hidden=true]")

        state =
          case {type, checked} do
            {"checkbox", true} -> "enabled"
            {"checkbox", false} -> "disabled"
            {"switch", true} -> "on"
            {"switch", false} -> "off"
          end

        assert Floki.text(visible) |> String.split() |> Enum.join(" ") == "Active is #{state}"
        assert Floki.find(visible, "span[data-boolean-text]") != []

        assert Floki.attribute(visible, "[data-boolean-state]", "data-boolean-state") == [
                 if(checked, do: "checked", else: "unchecked")
               ]

        assert Floki.find(visible, "input, label[for=active], .bg-control-check, .rounded-full") ==
                 []

        assert length(Floki.find(document, "span[aria-hidden=true].text-error")) == 1
      end
    end

    test "text boolean modes honor explicit checked state and use standalone state words without labels" do
      for type <- ~w(checkbox switch),
          render_as <- ~w(text text-enabled text-disabled),
          checked <- [false, true] do
        document =
          render_component(&CoreComponents.input/1,
            id: "active",
            name: "active",
            type: type,
            value: not checked,
            checked: checked,
            render_as: render_as
          )
          |> Floki.parse_document!()

        assert Floki.find(document, "input#active[checked]") != [] == checked
        assert length(Floki.find(document, "#active")) == 1
        assert Floki.find(document, "span[aria-hidden=true].text-error") == []

        {checked_text, unchecked_text} =
          if type == "checkbox", do: {"Enabled", "Disabled"}, else: {"On", "Off"}

        if render_as == "text-disabled" do
          visible = Floki.filter_out(document, ".hidden")

          assert Floki.text(visible) |> String.trim() ==
                   if(checked, do: checked_text, else: unchecked_text)

          assert Floki.find(visible, "label, input") == []
        else
          assert Floki.text(Floki.find(document, "[data-boolean-state=checked]")) == checked_text

          assert Floki.text(Floki.find(document, "[data-boolean-state=unchecked]")) ==
                   unchecked_text
        end
      end
    end

    test "alternate disabled checkbox and switch displays shade their indicator without boxing the label" do
      for type <- ~w(checkbox switch) do
        document =
          render_component(&CoreComponents.input/1,
            id: "active",
            name: "active",
            type: type,
            value: true,
            label: "Active",
            variant: "alt",
            render_as: "disabled"
          )
          |> Floki.parse_document!()

        assert Floki.find(
                 document,
                 "div#active.inline-grid > span:first-child.overlay-dark.bg-secondary"
               ) != []

        assert Floki.find(document, "div#active.border, div#active.overlay-dark, input") == []

        assert Floki.text(Floki.find(document, "div#active > span.text-subcontent"))
               |> String.trim() == "Active"
      end
    end

    test "text radio modes show only the selected value and preserve hidden native choices" do
      for render_as <- ~w(text text-enabled text-disabled), variant <- ~w(default card) do
        document =
          render_component(&CoreComponents.input/1,
            id: "contact",
            name: "contact",
            type: "radio",
            variant: variant,
            value: "email",
            label: "Contact",
            options: [{"Email", "email"}, {"Phone", "phone"}],
            render_as: render_as,
            required: true
          )
          |> Floki.parse_document!()

        assert Floki.find(
                 document,
                 ".hidden fieldset#contact input[type=radio][value=email][checked][required]"
               ) != []

        assert length(Floki.find(document, ".hidden input[type=radio]")) == 2

        assert Floki.text(Floki.find(document, "div:not(.hidden) > div > span.text-content")) ==
                 "email"

        assert Floki.find(document, "div:not(.hidden) > fieldset") == []
        assert length(Floki.find(document, "span[aria-hidden=true].text-error")) == 1
      end
    end
  end

  describe "input phx-debounce" do
    test "text inputs default to blur" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.input type="text" name="city" value="" label="City" />
        """)

      assert html =~ ~s(phx-debounce="blur")
    end

    test "textarea defaults to blur" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.input type="textarea" name="remark" value="" label="Remark" />
        """)

      assert html =~ ~s(phx-debounce="blur")
    end

    test "caller can override the default" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.input type="text" name="city" value="" label="City" phx-debounce="500" />
        """)

      assert html =~ ~s(phx-debounce="500")
      refute html =~ ~s(phx-debounce="blur")
    end

    test "checkbox stays undebounced so toggles fire immediately" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.input type="checkbox" name="active" value={true} label="Active" />
        """)

      refute html =~ "phx-debounce"
    end
  end

  describe "temporal inputs" do
    test "calendar validation borders do not compete with the default outline or change custom styling" do
      for disabled <- [false, true] do
        document =
          render_component(&CoreComponents.input/1,
            id: "schedule",
            name: "schedule",
            type: "date",
            label: "Schedule",
            value: "",
            disabled: disabled,
            errors: ["Choose a date"]
          )
          |> Floki.parse_document!()

        assert [classes] = Floki.attribute(document, "input#schedule", "class")
        assert "bg-transparent" in String.split(classes)
        assert "border-error" in String.split(classes)
        refute "border-outline" in String.split(classes)
        assert Floki.text(document) =~ "Choose a date"
      end

      custom_error =
        render_component(&CoreComponents.input/1,
          id: "schedule",
          name: "schedule",
          type: "date",
          value: "",
          errors: ["Choose a date"],
          error_class: "text-error"
        )
        |> Floki.parse_document!()

      assert [classes] = Floki.attribute(custom_error, "input#schedule", "class")
      assert "border-outline" in String.split(classes)
      assert "text-error" in String.split(classes)
      refute "border-error" in String.split(classes)

      custom_control =
        render_component(&CoreComponents.input/1,
          id: "schedule",
          name: "schedule",
          type: "date",
          value: "",
          errors: ["Choose a date"],
          class: "calendar-control"
        )
        |> Floki.parse_document!()

      assert [classes] = Floki.attribute(custom_control, "input#schedule", "class")
      assert "calendar-control" in String.split(classes)
      assert "border-error" in String.split(classes)
      refute "bg-transparent" in String.split(classes)
      refute "border-outline" in String.split(classes)
      refute "min-h-11" in String.split(classes)
    end

    test "stored instants use local calendar values across year and ISO week boundaries" do
      expected = %{
        "datetime-local" => "2027-01-01T04:15:00",
        "date" => "2027-01-01",
        "time" => "04:15",
        "week" => "2026-W53",
        "month" => "2027-01"
      }

      for {type, value} <- expected do
        html =
          render_component(&CoreComponents.input/1,
            id: "instant",
            name: "instant",
            type: type,
            value: ~U[2026-12-31 20:15:00Z],
            timezone: "Asia/Kuala_Lumpur"
          )

        document = Floki.parse_document!(html)
        assert Floki.attribute(document, "input", "value") == [value]
        assert Floki.attribute(document, "input", "data-vc-value") == [value]
        assert Floki.attribute(document, "input", "data-vc-timezone") == ["Asia/Kuala_Lumpur"]
      end
    end

    test "form context supplies the timezone and an explicit input timezone wins" do
      field = %Phoenix.HTML.FormField{
        id: "instant",
        name: "account[instant]",
        field: :instant,
        value: ~U[2026-04-23 13:30:00Z],
        errors: [],
        form: %Phoenix.HTML.Form{
          params: %{},
          source: %AshPhoenix.Form{
            opts: [context: %{shared: %{user_timezone: "America/New_York"}}]
          }
        }
      }

      for {timezone, expected} <- [
            {nil, "2026-04-23T09:30:00"},
            {"Asia/Kuala_Lumpur", "2026-04-23T21:30:00"}
          ] do
        html =
          render_component(&CoreComponents.input/1,
            field: field,
            type: "datetime-local",
            timezone: timezone
          )

        assert html |> Floki.parse_document!() |> Floki.attribute("input", "value") == [expected]
      end
    end

    test "read-only modes show local time and retain local hidden submission values" do
      for render_as <- ~w(disabled like-enabled like-disabled text-disabled) do
        html =
          render_component(&CoreComponents.input/1,
            id: "instant",
            name: "instant",
            type: "datetime-local",
            value: "2026-04-23T09:30:00-04:00",
            timezone: "Asia/Kuala_Lumpur",
            render_as: render_as
          )

        document = Floki.parse_document!(html)
        assert Floki.text(document) =~ "23 Apr 2026, 21:30"

        assert Floki.attribute(document, "input", "value") ==
                 if(render_as in ~w(like-disabled text-disabled),
                   do: ["2026-04-23T21:30:00"],
                   else: []
                 )
      end

      for render_as <- ~w(enabled text text-enabled hidden hidden-enabled) do
        html =
          render_component(&CoreComponents.input/1,
            id: "instant",
            name: "instant",
            type: "datetime-local",
            value: ~U[2026-04-23 13:30:00Z],
            timezone: "Asia/Kuala_Lumpur",
            render_as: render_as
          )

        assert html |> Floki.parse_document!() |> Floki.attribute("input", "value") == [
                 "2026-04-23T21:30:00"
               ]
      end
    end

    test "calendar values and unparsed local strings keep their meaning" do
      for {type, value, expected} <- [
            {"date", ~D[2026-04-23], "2026-04-23"},
            {"time", ~T[09:30:25], "09:30:25"},
            {"week", "2026-W17", "2026-W17"},
            {"month", "2026-04", "2026-04"},
            {"datetime-local", "2026-04-23T09:30", "2026-04-23T09:30"},
            {"datetime-local", "not a date <yet>", "not a date <yet>"}
          ] do
        html =
          render_component(&CoreComponents.input/1,
            id: "calendar-value",
            name: "calendar_value",
            type: type,
            value: value,
            timezone: "Pacific/Auckland"
          )

        assert html |> Floki.parse_document!() |> Floki.attribute("input", "value") == [expected]
      end
    end

    test "invalid Ash datetime sentinels restore the original local value" do
      raw = "2026-03-08T02:30"

      field = %Phoenix.HTML.FormField{
        id: "instant",
        name: "account[instant]",
        field: :instant,
        value: {:error, :nonexistent_datetime},
        errors: [{"This local time does not exist.", []}],
        form: %Phoenix.HTML.Form{
          params: %{"instant" => raw},
          source: %AshPhoenix.Form{
            raw_params: %{"instant" => raw},
            opts: [context: %{shared: %{user_timezone: "America/New_York"}}]
          }
        }
      }

      html = render_component(&CoreComponents.input/1, field: field, type: "datetime-local")
      document = Floki.parse_document!(html)
      assert Floki.attribute(document, "input", "value") == [raw]
      assert Floki.text(document) =~ "This local time does not exist."
      refute html =~ "nonexistent_datetime"
    end
  end

  describe "input autocomplete" do
    test "defaults to off" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.input type="text" name="city" value="" label="City" />
        """)

      assert html =~ ~s(autocomplete="off")
    end

    test "caller can override the default" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.input type="text" name="city" value="" label="City" autocomplete="on" />
        """)

      assert html =~ ~s(autocomplete="on")
      refute html =~ ~s(autocomplete="off")
    end
  end
end

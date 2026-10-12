defmodule ElixirbitsWeb.CoreComponentsTest.SelectPreview do
  use Phoenix.LiveView, layout: false

  alias ElixirbitsWeb.CoreComponents

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       form:
         to_form(
           %{"labeled_role" => "viewer", "unlabeled_role" => "viewer", "phone" => "+60123456789"},
           as: :choices
         ),
       options: [
         {"Editor", "editor"},
         {"Viewer", "viewer"},
         %{label: "Unavailable", value: "unavailable", disabled: true}
       ]
     )}
  end

  def render(assigns) do
    ~H"""
    <CoreComponents.input
      field={@form[:labeled_role]}
      id="labeled-role"
      type="select"
      label="Role"
      options={@options}
      keep_options_on_select
    />
    <CoreComponents.input
      field={@form[:unlabeled_role]}
      id="unlabeled-role"
      type="select"
      options={@options}
      keep_options_on_select
    />
    <CoreComponents.input field={@form[:phone]} id="phone" type="tel" label="Phone" />
    """
  end
end

defmodule ElixirbitsWeb.CoreComponentsTest do
  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest

  alias ElixirbitsWeb.CoreComponents

  @endpoint ElixirbitsWeb.Endpoint

  describe "select option states" do
    test "shared selects keep one option surface layer and padding while keyboard selection stays usable" do
      {:ok, view, _html} =
        live_isolated(Phoenix.ConnTest.build_conn(), __MODULE__.SelectPreview)

      for id <- ["labeled-role", "unlabeled-role", "choices_phone_country_code_country_select"] do
        html = render_hook(element(view, "##{id}"), "keydown", %{"key" => "ArrowDown"})
        document = Floki.parse_document!(html)
        rows = Floki.find(document, "##{id} ul > li")

        assert length(rows) >= 2
        assert Floki.find(document, "##{id} ul > li.bg-primary.overlay-dark.font-semibold") != []

        assert Floki.find(
                 document,
                 "##{id} ul > li.cursor-pointer.text-content > div.overlay-light"
               ) != []

        refute html =~ "hover:bg-gray-400"
        refute html =~ "text-gray-400"

        for row <- rows do
          assert [outer_classes] = Floki.attribute(row, "class")
          refute outer_classes =~ "py-2"
          refute outer_classes =~ "px-3"
          refute outer_classes =~ "hover:overlay-light"
          assert [inner_classes] = Floki.attribute(row, "div", "class")
          assert "py-2" in String.split(inner_classes)
          assert "px-3" in String.split(inner_classes)
          assert "hover:overlay-light" in String.split(inner_classes)
        end
      end

      for {id, field_name} <- [
            {"labeled-role", "choices[labeled_role]"},
            {"unlabeled-role", "choices[unlabeled_role]"}
          ] do
        assert has_element?(view, "##{id} li.cursor-not-allowed.text-subcontent", "Unavailable")
        render_hook(element(view, "##{id}"), "option_click", %{"idx" => "2"})
        assert has_element?(view, "##{id} input[type=hidden][name='#{field_name}'][value=viewer]")
        render_hook(element(view, "##{id}"), "option_click", %{"idx" => "0"})
        assert has_element?(view, "##{id} input[type=hidden][name='#{field_name}'][value=editor]")
        render_hook(element(view, "##{id}"), "keydown", %{"key" => "ArrowDown"})
        assert has_element?(view, "##{id} li.bg-primary.overlay-dark", "Editor")
        assert has_element?(view, "##{id} li > div.overlay-light", "Viewer")
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

  describe "required input labels" do
    test "native controls retain required and mark their label once" do
      types =
        ~w(color email file number password search text url textarea date datetime-local time week month checkbox switch radio)

      for {type, variant} <-
            Enum.map(types, &{&1, "default"}) ++ [{"checkbox", "alt"}, {"switch", "alt"}] do
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

    test "disabled selects keep one required label and their submitted option values" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.input
          id="role"
          name="role"
          type="select"
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

        if render_as in ["enabled", "hidden", "hidden-enabled"] do
          assert Floki.find(document, "input#attachment-upload[type=file][required]") != []
          assert Floki.find(document, "input#attachment-upload[disabled]") == []
        else
          assert Floki.find(
                   document,
                   "label.hidden input#attachment-upload[type=file][required][disabled]"
                 ) != []
        end
      end
    end

    test "read-only pending image previews retain their native upload input and references" do
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
            <:pending :let={pending_entry}><.live_img_preview entry={pending_entry} /></:pending>
          </CoreComponents.input>
          """)

        document = Floki.parse_document!(html)

        assert Floki.find(
                 document,
                 "label.hidden input#attachment-upload[disabled][data-phx-active-refs=picked-image]"
               ) != []

        assert Floki.find(
                 document,
                 "img[data-phx-upload-ref=attachment-upload][data-phx-entry-ref=picked-image]"
               ) != []

        assert Floki.find(document, "button[phx-click=cancel_upload]") == []
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
               "div.hidden label.hidden input#attachment-upload[disabled]"
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
        assert classes =~ "disabled:checked:bg-tertiary"
        assert classes =~ "disabled:checked:border-tertiary"

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

        assert Floki.find(document, "span.bg-tertiary.border-tertiary") != []
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
          <:preview :let={url}>{url}</:preview>
          <:pending>{@entry.client_name}</:pending>
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

    test "select span shows the option label instead of the raw value" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.input
          type="select"
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
      assert html =~ "bg-tertiary"
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

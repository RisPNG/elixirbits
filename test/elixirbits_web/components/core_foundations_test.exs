defmodule ElixirbitsWeb.CoreFoundationsTest do
  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest

  alias ElixirbitsWeb.CoreComponents

  test "plain text modes preserve editability and submitted read-only values" do
    assigns = %{}

    html =
      rendered_to_string(~H"""
      <CoreComponents.input name="city" id="city" type="text" value="Ipoh" render_as="text" />
      <CoreComponents.input
        name="country"
        id="country"
        type="text"
        value="Malaysia"
        render_as="text-disabled"
      />
      """)

    document = Floki.parse_document!(html)
    assert Floki.find(document, "input#city[name=city][value=Ipoh]") != []
    assert Floki.find(document, ".hidden input#country[name=country][value=Malaysia]") != []
    assert length(Floki.find(document, "#country")) == 1
    assert Floki.find(document, "input#city[disabled]") == []
  end

  test "radio options submit their values and expose the group label" do
    assigns = %{}

    html =
      rendered_to_string(~H"""
      <CoreComponents.input
        name="contact"
        type="radio"
        label="Contact method"
        value={:phone}
        options={[{"Email", :email}, {"Phone", :phone}]}
      />
      """)

    document = Floki.parse_document!(html)

    assert Floki.find(document, "fieldset legend") |> Floki.text() |> String.trim() ==
             "Contact method"

    assert Floki.find(document, "input[name=contact][value=phone][checked]") != []
    assert Floki.find(document, "input[value=email][checked]") == []
  end

  test "radio cards retain native choices with descriptions, required values, and disabled options" do
    document =
      render_component(&CoreComponents.input/1,
        id: "compute-plan",
        name: "account[compute_plan]",
        type: "radio",
        variant: "card",
        label: "Compute plan",
        value: "6-core",
        options: [
          {"8-core CPU", "8-core", description: "32 GB RAM"},
          {"6-core CPU", "6-core", description: "24 GB RAM"},
          {"4-core CPU", "4-core", description: "16 GB RAM", disabled: true}
        ],
        required: true
      )
      |> Floki.parse_document!()

    assert Floki.find(document, "fieldset#compute-plan legend") |> Floki.text() =~ "Compute plan"

    assert length(
             Floki.find(document, "input[type=radio][name='account[compute_plan]'][required]")
           ) == 3

    assert length(Floki.find(document, "input[type=radio][checked]")) == 1
    assert Floki.find(document, "input[value='6-core'][checked]:not([disabled])") != []
    assert Floki.find(document, "input[value='4-core'][disabled]:not([checked])") != []

    labels = Floki.find(document, "label")

    for {value, title, description} <- [
          {"8-core", "8-core CPU", "32 GB RAM"},
          {"6-core", "6-core CPU", "24 GB RAM"},
          {"4-core", "4-core CPU", "16 GB RAM"}
        ] do
      label =
        Enum.find(labels, fn label -> Floki.find(label, "input[value='#{value}']") != [] end)

      assert Floki.text(label) =~ title
      assert Floki.text(label) =~ description
      assert Floki.find(label, "input[hidden], input[tabindex='-1']") == []
    end
  end

  test "radio variants support simple options and omit every choice when the group is disabled" do
    for variant <- ~w(default card) do
      document =
        render_component(&CoreComponents.input/1,
          name: "plan",
          type: "radio",
          variant: variant,
          value: :standard,
          options: [
            {"Standard", :standard},
            {"Advanced", :advanced, description: "More capacity"}
          ],
          disabled: true
        )
        |> Floki.parse_document!()

      assert length(Floki.find(document, "input[type=radio][name=plan][disabled]")) == 2
      assert Floki.find(document, "input[value=standard][checked][disabled]") != []
      assert Floki.find(document, "input[type=radio]:not([disabled])") == []
      assert Floki.text(document) =~ "More capacity"
    end
  end

  test "native single selects render prompts and disabled controls" do
    assigns = %{}

    html =
      rendered_to_string(~H"""
      <CoreComponents.input
        id="native-role"
        name="role"
        type="select"
        label="Role"
        value="viewer"
        prompt="Choose a role"
        options={[{"Editor", "editor"}, {"Viewer", "viewer"}]}
        required
      />
      <CoreComponents.input
        id="native-disabled-role"
        name="disabled_role"
        type="select"
        value="editor"
        options={[{"Editor", "editor"}, {"Viewer", "viewer"}]}
        disabled
      />
      """)

    document = Floki.parse_document!(html)
    assert Floki.find(document, "select#native-role[name=role][required]") != []

    assert Floki.find(document, "select#native-role option[value='']") |> Floki.text() ==
             "Choose a role"

    assert Floki.find(document, "select#native-role option[value=viewer][selected]") != []
    assert Floki.find(document, "label[for=native-role]") |> Floki.text() =~ "Role"
    assert Floki.find(document, "select#native-disabled-role[name=disabled_role][disabled]") != []

    assert Floki.find(document, "select#native-disabled-role option[value=editor][selected]") !=
             []

    assert Floki.find(document, "[phx-hook=PetalComboBox]") == []
  end

  test "multiple selects render a searchable picker with selected tags and native array values" do
    assigns = %{
      form: Phoenix.Component.to_form(%{"roles" => ["editor", "viewer"]}, as: :account)
    }

    html =
      rendered_to_string(~H"""
      <CoreComponents.input
        id="account-roles"
        field={@form[:roles]}
        type="select"
        label="Roles"
        options={[
          {"Available", [{"Editor", "editor"}, {"Viewer", "viewer"}]},
          {"Unavailable", "blocked", disabled: true}
        ]}
        multiple
        max_items={3}
      />
      """)

    document = Floki.parse_document!(html)

    assert Floki.find(
             document,
             "#account-roles[phx-hook=PetalComboBox][data-max-items='3']"
           ) != []

    assert Floki.find(
             document,
             "#account-roles-input[role=combobox][aria-autocomplete=list]:not([readonly])"
           ) != []

    assert Floki.find(document, "#account-roles-select[name='account[roles][]'][multiple]") != []
    assert length(Floki.find(document, "#account-roles-select option[selected]")) == 2
    assert Floki.find(document, "input[type=hidden][name='account[roles][]'][value='']") != []
    assert Floki.find(document, "label[for=account-roles-input]") |> Floki.text() =~ "Roles"

    for role <- ~w(editor viewer) do
      assert Floki.find(
               document,
               "#account-roles-chips > [data-pc-combo-chip][data-value=#{role}]"
             ) != []
    end

    assert Floki.find(document, "#account-roles-select optgroup[label=Available]") != []
    assert Floki.find(document, "#account-roles-select option[value=blocked][disabled]") != []

    assert Floki.find(
             document,
             "#account-roles [role=option][data-value=blocked][aria-disabled=true]"
           ) != []
  end

  test "disabled and read-only multiple selects omit both selections and their empty marker" do
    form = Phoenix.Component.to_form(%{"roles" => ["member"]}, as: :account)

    for attribute <- [:disabled, :readonly] do
      document =
        render_component(
          &CoreComponents.input/1,
          [
            id: "account-roles",
            field: form[:roles],
            type: "select",
            options: [{"Member", "member"}],
            multiple: true
          ] ++ [{attribute, true}]
        )
        |> Floki.parse_document!()

      assert Floki.find(
               document,
               "#account-roles-select[name='account[roles][]'][multiple][disabled]"
             ) != []

      assert Floki.find(document, "#account-roles-select option[value=member][selected]") != []

      assert Floki.find(
               document,
               "input[type=hidden][name='account[roles][]'][value=''][disabled]"
             ) != []

      assert Floki.find(document, "input[type=hidden][name='account[roles][]']:not([disabled])") ==
               []
    end
  end

  test "standalone selects and comboboxes allow omitted initial values" do
    assigns = %{}

    html =
      rendered_to_string(~H"""
      <CoreComponents.input
        id="native-choice"
        name="native_choice"
        type="select"
        label="Native choice"
        options={[{"Editor", "editor"}]}
      />
      <CoreComponents.input
        id="search-choice"
        name="search_choice"
        type="combobox"
        label="Search choice"
        options={[{"Viewer", "viewer"}]}
      />
      """)

    document = Floki.parse_document!(html)

    assert Floki.find(document, "select#native-choice[name=native_choice].input-floating-control") !=
             []

    assert Floki.find(document, "#search-choice-select[name=search_choice]") != []
    assert Floki.find(document, "#search-choice-select option[selected]") == []
  end

  test "multiple comboboxes preserve names, selected options, disabled choices, and selection limits" do
    assigns = %{
      form: Phoenix.Component.to_form(%{"roles" => ["editor", "viewer"]}, as: :account)
    }

    html =
      rendered_to_string(~H"""
      <CoreComponents.input
        id="account-roles"
        field={@form[:roles]}
        type="combobox"
        label="Roles"
        options={[
          {"Available", [{"Editor", "editor"}, {"Viewer", "viewer"}]},
          {"Unavailable", "blocked", disabled: true}
        ]}
        multiple
        max_items={3}
      />
      """)

    document = Floki.parse_document!(html)

    assert Floki.find(document, "#account-roles[phx-hook=PetalComboBox][data-max-items='3']") !=
             []

    assert Floki.find(document, "#account-roles-select[name='account[roles][]'][multiple]") != []
    assert length(Floki.find(document, "#account-roles-select option[selected]")) == 2
    assert Floki.find(document, "#account-roles-select optgroup[label=Available]") != []
    assert Floki.find(document, "#account-roles-select option[value=blocked][disabled]") != []

    assert Floki.find(
             document,
             "#account-roles [role=option][data-value=blocked][aria-disabled=true]"
           ) != []
  end

  test "read-only multiple comboboxes do not submit an empty selection marker" do
    assigns = %{form: Phoenix.Component.to_form(%{"roles" => ["member"]}, as: :account)}

    html =
      rendered_to_string(~H"""
      <CoreComponents.input
        field={@form[:roles]}
        type="combobox"
        options={[{"Member", "member"}]}
        multiple
        readonly
      />
      """)

    document = Floki.parse_document!(html)
    assert Floki.find(document, "input[type=hidden][name='account[roles][]'][disabled]") != []

    assert Floki.find(
             document,
             "select[name='account[roles][]'][disabled] option[value=member][selected]"
           ) != []
  end

  test "record actions are named and only explicit submit actions submit forms" do
    assigns = %{}

    html =
      rendered_to_string(~H"""
      <CoreComponents.action_button action={:create} id="create" />
      <CoreComponents.action_button action={:read} id="read" />
      <CoreComponents.action_button action={:create} id="add" tooltip="Add" />
      <CoreComponents.action_button action={:delete} id="delete" />
      <CoreComponents.action_button action={:save} id="save" type="submit" />
      """)

    document = Floki.parse_document!(html)

    assert Floki.find(
             document,
             "button#create[type=button][aria-label='Add new'][data-tooltip='Add new']"
           ) != []

    assert Floki.find(document, "button#read[type=button][aria-label=View][data-tooltip=View]") !=
             []

    assert Floki.find(document, "button#add[type=button][aria-label=Add][data-tooltip=Add]") != []
    assert Floki.find(document, "button#delete[type=button][aria-label=Delete]") != []
    assert Floki.find(document, "button#save[type=submit][aria-label=Save]") != []
  end

  test "modal connects its label, cancellation, and native focus handling" do
    assigns = %{}

    html =
      rendered_to_string(~H"""
      <CoreComponents.modal id="confirm" on_cancel={Phoenix.LiveView.JS.push("cancel")}>
        <:title>Confirm deletion</:title>
        <CoreComponents.button id="cancel" type="button">Cancel</CoreComponents.button>
      </CoreComponents.modal>
      """)

    document = Floki.parse_document!(html)

    assert Floki.find(document, "[role=dialog][aria-modal=true][aria-labelledby=confirm-title]") !=
             []

    assert Floki.find(document, "#confirm-content[phx-hook='Phoenix.FocusWrap']") != []
    assert Floki.find(document, "#confirm[phx-key=Escape][phx-window-keydown][phx-remove]") != []

    assert Floki.find(document, "#confirm-title") |> Floki.text() |> String.trim() ==
             "Confirm deletion"
  end
end

defmodule ElixirbitsWeb.CoreSelectHarness do
  use ElixirbitsWeb, :live_view

  def mount(_params, _session, socket) do
    changeset = Ecto.Changeset.change({%{quantity: 7}, %{quantity: :integer}})

    {:ok,
     socket
     |> assign(:quantity_form, to_form(changeset, as: :item))
     |> assign(:role_form, to_form(%{"role" => :admin, "phone" => "+60123456789"}, as: :account))
     |> assign(:required, true)}
  end

  def handle_event("toggle_required", _params, socket) do
    {:noreply, assign(socket, :required, not socket.assigns.required)}
  end

  def render(assigns) do
    ~H"""
    <.form for={@quantity_form}>
      <.input
        field={@quantity_form[:quantity]}
        type="combobox"
        label="Quantity"
        options={[{"Seven", 7}]}
        required={@required}
      />
    </.form>

    <.form for={@role_form}>
      <.input
        id="custom-role"
        field={@role_form[:role]}
        type="combobox"
        label="Role"
        options={[{"Administrator", "admin"}, {"Viewer", "viewer"}]}
        aria-describedby="role-help"
        required={@required}
      />
      <p id="role-help">Choose the account's role.</p>
      <.input field={@role_form[:phone]} type="tel" label="Phone" required={@required} />
    </.form>
    <button id="toggle-required" type="button" phx-click="toggle_required">Toggle required</button>
    """
  end
end

defmodule ElixirbitsWeb.CoreSelectTest do
  use ElixirbitsWeb.ConnCase, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest

  test "combobox and telephone labels follow explicit required changes without duplicated markers",
       %{
         conn: conn
       } do
    {:ok, view, html} = live_isolated(conn, ElixirbitsWeb.CoreSelectHarness)
    document = Floki.parse_document!(html)

    assert length(Floki.find(document, "form[novalidate]")) == 2
    assert length(Floki.find(document, "span[aria-hidden=true].text-error")) == 3

    assert has_element?(
             view,
             "label[for=item_quantity-input] span[aria-hidden=true]",
             "*"
           )

    assert has_element?(
             view,
             "label[for=custom-role-input] span[aria-hidden=true]",
             "*"
           )

    assert has_element?(view, "label[for=account_phone] span[aria-hidden=true]", "*")
    assert has_element?(view, "input#account_phone[type=tel][required]")
    assert has_element?(view, "input[type=hidden][name='account[phone]'][value='+60123456789']")

    html = view |> element("#toggle-required") |> render_click()
    assert Floki.find(Floki.parse_document!(html), "span[aria-hidden=true].text-error") == []
    refute has_element?(view, "input#account_phone[required]")

    assert has_element?(
             view,
             "#custom-role-select[name='account[role]'] option[value=admin][selected]"
           )

    html = view |> element("#toggle-required") |> render_click()

    assert length(Floki.find(Floki.parse_document!(html), "span[aria-hidden=true].text-error")) ==
             3

    assert has_element?(view, "input#account_phone[required]")
  end

  test "comboboxes preserve real form fields, integer values, and explicit component IDs", %{
    conn: conn
  } do
    {:ok, view, _html} = live_isolated(conn, ElixirbitsWeb.CoreSelectHarness)

    assert has_element?(view, "#item_quantity[phx-hook=PetalComboBox]")

    assert has_element?(
             view,
             "#item_quantity-select[name='item[quantity]'] option[value='7'][selected]"
           )

    assert has_element?(view, "#custom-role[phx-hook=PetalComboBox]")

    assert has_element?(
             view,
             "#custom-role-select[name='account[role]'] option[value=admin][selected]"
           )

    assert has_element?(view, "#custom-role input[type=text][value=Administrator]")
    refute has_element?(view, "#account_role")
    assert has_element?(view, "[role=group][aria-describedby=role-help] #custom-role")
    assert has_element?(view, "label[for=custom-role-input]")
    assert has_element?(view, "input#custom-role-input[role=combobox]")
  end

  test "disabled comboboxes retain their labeled group, help, and submitted zero value" do
    assigns = %{form: Phoenix.Component.to_form(%{"level" => 0}, as: :permission)}

    html =
      rendered_to_string(~H"""
      <span id="level-label">Permission</span>
      <ElixirbitsWeb.CoreComponents.input
        field={@form[:level]}
        type="combobox"
        options={[{"None", 0}, {"Read", 4}]}
        aria-labelledby="level-label"
        aria-describedby="level-help"
        disabled
      />
      <p id="level-help">Read access is needed for other capabilities.</p>
      """)

    document = Floki.parse_document!(html)

    assert Floki.find(
             document,
             "[role=group][aria-labelledby=level-label][aria-describedby=level-help] input[disabled][value=None]"
           ) != []

    assert Floki.find(document, "input[type=hidden][name='permission[level]'][value='0']") != []
  end
end

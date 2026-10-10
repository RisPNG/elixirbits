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
        type="select"
        label="Quantity"
        options={[{"Seven", 7}]}
        required={@required}
      />
    </.form>
    <.form for={@role_form}>
      <.input
        id="custom-role"
        field={@role_form[:role]}
        type="select"
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

  test "select and telephone labels follow explicit required changes without duplicated markers",
       %{
         conn: conn
       } do
    {:ok, view, html} = live_isolated(conn, ElixirbitsWeb.CoreSelectHarness)
    document = Floki.parse_document!(html)

    assert length(Floki.find(document, "form[novalidate]")) == 2
    assert length(Floki.find(document, "span[aria-hidden=true].text-error")) == 3

    assert has_element?(
             view,
             "label[for=item_quantity_text_input] .input-floating-label span[aria-hidden=true]",
             "*"
           )

    assert has_element?(
             view,
             "label[for=account_role_text_input] .input-floating-label span[aria-hidden=true]",
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
             "#custom-role input[type=hidden][name='account[role]'][value=admin]"
           )

    html = view |> element("#toggle-required") |> render_click()

    assert length(Floki.find(Floki.parse_document!(html), "span[aria-hidden=true].text-error")) ==
             3

    assert has_element?(view, "input#account_phone[required]")
  end

  test "selects preserve real form fields, integer values, and explicit component IDs", %{
    conn: conn
  } do
    {:ok, view, _html} = live_isolated(conn, ElixirbitsWeb.CoreSelectHarness)

    assert has_element?(view, "#item_quantity-ls[data-field=item_quantity]")

    assert has_element?(
             view,
             "#item_quantity-ls input[type=hidden][name='item[quantity]'][value='7']"
           )

    assert has_element?(view, "#custom-role[data-field=account_role]")

    assert has_element?(
             view,
             "#custom-role input[type=hidden][name='account[role]'][value=admin]"
           )

    assert has_element?(view, "#custom-role input[type=text][value=Administrator]")
    refute has_element?(view, "#account_role-ls")
    assert has_element?(view, "[role=group][aria-describedby=role-help] #custom-role")
    assert has_element?(view, "label[for=account_role_text_input] input#account_role_text_input")
  end

  test "disabled selects retain their labelled group, help, and submitted zero value" do
    assigns = %{form: Phoenix.Component.to_form(%{"level" => 0}, as: :permission)}

    html =
      rendered_to_string(~H"""
      <span id="level-label">Permission</span>
      <ElixirbitsWeb.CoreComponents.input
        field={@form[:level]}
        type="select"
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

defmodule ElixirbitsWeb.Dashboard.LayoutTestInputMatrixTest do
  use ElixirbitsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias ElixirbitsWeb.CoreComponents

  test "native file specimens keep preview and editing off for single and multiple selections", %{
    conn: conn
  } do
    {:ok, view, _html} = live(conn, ~p"/dashboard/dev_panel/layout_test")

    selector = "#layout-test-input-example-file [phx-hook=FileInput]"
    assert has_element?(view, "#{selector}[data-file-preview=false][data-file-editor=false]")

    assert has_element?(
             view,
             "#{selector}[data-file-selection=single] input#local_upload:not([multiple])"
           )

    render_click(element(view, "#layout-test-input-state-multiple"))
    assert has_element?(view, "#{selector}[data-file-preview=false][data-file-editor=false]")

    assert has_element?(
             view,
             "#{selector}[data-file-selection=multiple] input#local_upload[multiple]"
           )
  end

  test "supported types and the radio card specimen expose their selection controls", %{
    conn: conn
  } do
    {:ok, _view, html} = live(conn, ~p"/dashboard/dev_panel/layout_test")
    document = Floki.parse_document!(html)
    attributes = CoreComponents.__components__().input.attrs
    types = Enum.find(attributes, &(&1.name == :type)).opts[:values]

    specimens =
      Floki.find(document, "#layout-test-input-examples [data-input-mode][data-input-type]")

    assert length(specimens) == length(types) + 1

    assert specimens
           |> Floki.attribute("data-input-type")
           |> Enum.reject(&(&1 == "radio-card"))
           |> Enum.sort() == Enum.sort(types)

    assert Floki.find(document, "#layout-test-input-example-radio-card[data-input-variant=card]") !=
             []

    specimen_ids = Floki.attribute(specimens, "id")
    radio_index = Enum.find_index(specimen_ids, &(&1 == "layout-test-input-example-radio"))
    assert Enum.at(specimen_ids, radio_index + 1) == "layout-test-input-example-radio-card"

    for {attribute, option} <- [
          {:render_as, "render_as"},
          {:variant, "variant"}
        ] do
      values = Enum.find(attributes, &(&1.name == attribute)).opts[:values]
      values = if attribute == :variant, do: Enum.reject(values, &(&1 == "card")), else: values

      controls =
        Floki.find(document, "#layout-test-input-controls button[phx-value-option='#{option}']")

      assert Enum.sort(Floki.attribute(controls, "phx-value-choice")) ==
               Enum.sort(Enum.map(values, &to_string/1))
    end

    for option <- ~w(select_mode combobox_mode) do
      assert Floki.attribute(
               document,
               "#layout-test-input-controls button[phx-value-option='#{option}']",
               "phx-value-choice"
             ) == ["single", "multiple"]
    end

    assert Floki.attribute(
             document,
             "#layout-test-input-controls button[phx-value-option=checked]",
             "phx-value-choice"
           ) == ["false", "true"]
  end

  test "changing display modes keeps the same specimens and applies their submission semantics",
       %{conn: conn} do
    {:ok, view, html} = live(conn, ~p"/dashboard/dev_panel/layout_test")

    specimen_ids =
      Floki.attribute(Floki.parse_document!(html), "[data-input-mode][data-input-type]", "id")

    attributes = CoreComponents.__components__().input.attrs
    modes = Enum.find(attributes, &(&1.name == :render_as)).opts[:values]

    for mode <- modes do
      document =
        view
        |> element("#layout-test-input-render-#{mode}")
        |> render_click()
        |> Floki.parse_document!()

      assert Floki.attribute(document, "[data-input-mode][data-input-type]", "id") == specimen_ids

      assert Enum.uniq(
               Floki.attribute(document, "[data-input-mode][data-input-type]", "data-input-mode")
             ) == [
               mode
             ]

      assert has_element?(view, "#layout-test-input-render-#{mode}[aria-pressed=true]")

      case mode do
        "hidden-disabled" ->
          refute has_element?(view, "#local_project_name")
          refute has_element?(view, "#layout-test-local-role")

        mode when mode in ~w(disabled like-enabled) ->
          assert has_element?(view, "span#local_project_name", "Layout Test")

          refute has_element?(
                   view,
                   "#layout-test-input-example-text input[name='local[project_name]']"
                 )

        mode when mode in ~w(like-disabled text-disabled hidden hidden-enabled) ->
          assert has_element?(
                   view,
                   "#layout-test-input-example-text .hidden input#local_project_name[value='Layout Test']"
                 )

        _ ->
          assert has_element?(
                   view,
                   "input#local_project_name[name='local[project_name]'][value='Layout Test']"
                 )
      end
    end
  end

  test "radio cards select and submit independently of the normal radio group", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/dashboard/dev_panel/layout_test")

    assert has_element?(
             view,
             "#local_compute_plan input[name='local[compute_plan]'][value='6-core'][checked]"
           )

    assert has_element?(view, "#local_compute_plan input[value='4-core'][disabled]")
    assert has_element?(view, "#local_compute_plan", "24 GB RAM")
    assert has_element?(view, "#local_contact_method input[value=email][checked]")

    view
    |> form("#layout-test-form", local: %{compute_plan: "8-core"})
    |> render_change()

    assert has_element?(view, "#local_compute_plan input[value='8-core'][checked]")
    refute has_element?(view, "#local_compute_plan input[value='6-core'][checked]")
    assert has_element?(view, "#local_contact_method input[value=email][checked]")

    view
    |> form("#layout-test-form", local: %{compute_plan: "6-core", contact_method: "phone"})
    |> render_submit()

    assert has_element?(view, "#local_compute_plan input[value='6-core'][checked]")
    assert has_element?(view, "#local_contact_method input[value=phone][checked]")
  end

  test "like-enabled specimens retain each input's visible controls without submitting fields", %{
    conn: conn
  } do
    {:ok, view, _html} = live(conn, ~p"/dashboard/dev_panel/layout_test")
    render_click(element(view, "#layout-test-input-render-like-enabled"))

    assert has_element?(view, "#layout-test-input-example-password [data-password-display]")

    refute has_element?(
             view,
             "#layout-test-input-example-password [data-password-display]",
             "password123"
           )

    assert has_element?(view, "#layout-test-input-example-password .hero-eye")

    assert has_element?(view, "#layout-test-input-example-number .number-input-control .border-l")

    for step <- ~w(1 -1) do
      assert has_element?(
               view,
               "#layout-test-input-example-number span[data-number-step='#{step}']"
             )
    end

    for type <- ~w(select combobox) do
      assert has_element?(view, "#layout-test-input-example-#{type}", "Administrator")
      assert has_element?(view, "#layout-test-input-example-#{type} .pc-combo-box__chevron")
    end

    assert has_element?(view, "#layout-test-input-example-tel", "+60")
    assert has_element?(view, "#layout-test-input-example-tel span[data-tel-number]", "123456789")
    assert has_element?(view, "#layout-test-input-example-tel .pc-combo-box__chevron")

    assert has_element?(
             view,
             "#layout-test-input-example-textarea span[data-input-rows='4']",
             "Core components, layout flow, dependency surfaces."
           )

    assert view
           |> render()
           |> Floki.parse_document!()
           |> Floki.find("#layout-test-input-example-textarea span[data-input-rows='4']")
           |> Floki.text() == "Core components, layout flow, dependency surfaces."

    refute has_element?(view, "#layout-test-input-example-hidden #local_hidden_token")
    refute has_element?(view, "#layout-test-input-example-hidden", "LT-LOCAL")

    for type <-
          ~w(text email password number date time week month datetime-local search url tel select combobox textarea checkbox switch radio radio-card hidden) do
      refute has_element?(
               view,
               "#layout-test-input-example-#{type} input, #layout-test-input-example-#{type} select, #layout-test-input-example-#{type} textarea"
             )
    end
  end

  test "like-enabled radio groups retain all choices and the selected state", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/dashboard/dev_panel/layout_test")

    view
    |> form("#layout-test-form", local: %{compute_plan: "8-core", contact_method: "phone"})
    |> render_change()

    render_click(element(view, "#layout-test-input-render-like-enabled"))

    assert has_element?(view, "#local_contact_method", "Email")
    assert has_element?(view, "#local_contact_method", "Telephone")
    assert has_element?(view, "#local_contact_method [data-radio-checked=true]", "Telephone")
    assert has_element?(view, "#local_contact_method [data-radio-checked=false]", "Email")

    assert view
           |> render()
           |> Floki.parse_document!()
           |> Floki.find("#local_contact_method [data-radio-option]")
           |> length() == 2

    for {label, description} <- [
          {"8-core CPU", "32 GB RAM"},
          {"6-core CPU", "24 GB RAM"},
          {"4-core CPU", "16 GB RAM"}
        ] do
      assert has_element?(view, "#local_compute_plan", label)
      assert has_element?(view, "#local_compute_plan", description)
    end

    assert has_element?(view, "#local_compute_plan [data-radio-checked=true]", "8-core CPU")
    refute has_element?(view, "#local_compute_plan [data-radio-checked=true]", "6-core CPU")
  end

  test "like-enabled multiple choices and textarea sizing follow the enabled specimens", %{
    conn: conn
  } do
    {:ok, view, _html} = live(conn, ~p"/dashboard/dev_panel/layout_test")

    for control <- ~w(select combobox) do
      render_click(element(view, "#layout-test-input-#{control}-mode-multiple"))
    end

    render_click(element(view, "#layout-test-input-state-textarea_size"))

    view
    |> form("#layout-test-form",
      local: %{role: ["designer", "viewer"], native_role: ["admin", "viewer"]}
    )
    |> render_change()

    assert has_element?(view, "textarea#local_notes[rows='6']")

    for type <- ~w(select combobox) do
      assert has_element?(
               view,
               "#layout-test-input-example-#{type} [data-pc-combo-trigger-label]",
               "2 selected"
             )
    end

    render_click(element(view, "#layout-test-input-render-like-enabled"))

    for type <- ~w(select combobox) do
      assert has_element?(
               view,
               "#layout-test-input-example-#{type} .pc-combo-box__trigger-label",
               "2 selected"
             )

      refute has_element?(view, "#layout-test-input-example-#{type} input")
      refute has_element?(view, "#layout-test-input-example-#{type} select")
    end

    assert has_element?(view, "span#local_notes[data-input-rows='6']")

    view
    |> form("#layout-test-form")
    |> render_submit()

    render_click(element(view, "#layout-test-input-render-enabled"))

    for role <- ~w(designer viewer) do
      assert has_element?(
               view,
               "#layout-test-local-role select option[value=#{role}][selected]"
             )
    end

    for role <- ~w(admin viewer) do
      assert has_element?(
               view,
               "select#local_native_role-select option[value=#{role}][selected]"
             )
    end
  end

  test "like-enabled calendar values use the enabled field's timezone and format" do
    for type <- ~w(date time week month datetime-local) do
      attributes = [
        type: type,
        id: "schedule",
        name: "schedule",
        value: ~U[2026-12-31 20:15:00Z],
        timezone: "Asia/Singapore"
      ]

      enabled =
        render_component(&CoreComponents.input/1, attributes)
        |> Floki.parse_document!()

      [expected] = Floki.attribute(enabled, "input#schedule", "value")

      static =
        render_component(
          &CoreComponents.input/1,
          Keyword.put(attributes, :render_as, "like-enabled")
        )
        |> Floki.parse_document!()

      assert Floki.text(Floki.find(static, "span#schedule")) == expected
      assert Floki.find(static, "input, select, textarea") == []
    end
  end

  test "single select displays preserve keyword choices and groups without turning separators into choices" do
    options = [
      [key: "Unavailable", value: "unavailable", disabled: true],
      :hr,
      {"Available roles", [{"Viewer", "viewer"}, {"Administrator", "admin"}]},
      {:hr, nil},
      [key: "No role", value: ""]
    ]

    for {value, label} <- [
          {nil, "Viewer"},
          {"", "No role"},
          {"unavailable", "Unavailable"},
          {"admin", "Administrator"}
        ] do
      attributes = [type: "select", id: "role", name: "role", options: options, value: value]

      enabled =
        render_component(&CoreComponents.input/1, attributes)
        |> Floki.parse_document!()

      assert Floki.attribute(enabled, "select#role-select option", "value") ==
               ["", "unavailable", "viewer", "admin", ""]

      assert Floki.attribute(enabled, "select#role-select optgroup", "label") == [
               "Available roles"
             ]

      assert Floki.find(enabled, "#role [data-pc-combo-item][data-label=hr]") == []
      assert Floki.find(enabled, "option[value=unavailable][disabled]") != []

      assert Floki.attribute(enabled, "select#role-select option[selected]", "value") ==
               if(is_nil(value), do: ["viewer"], else: [value])

      display =
        render_component(
          &CoreComponents.input/1,
          Keyword.put(attributes, :render_as, "like-enabled")
        )
        |> Floki.parse_document!()

      assert display
             |> Floki.find("#role .pc-combo-box__trigger-label")
             |> Floki.text()
             |> String.trim() == label

      assert Floki.find(display, "input, select, textarea") == []
    end
  end

  test "radio cards share required, error, empty, and disabled showcase states", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/dashboard/dev_panel/layout_test")

    for state <- ~w(required errors) do
      render_click(element(view, "#layout-test-input-state-#{state}"))
    end

    assert has_element?(view, "#local_compute_plan input[type=radio][required]")
    assert has_element?(view, "#layout-test-input-example-radio-card", "Example validation error")

    render_click(element(view, "#layout-test-input-state-empty"))
    refute has_element?(view, "#local_compute_plan input[checked]")
    render_click(element(view, "#layout-test-input-state-empty"))
    assert has_element?(view, "#local_compute_plan input[value='6-core'][checked]")

    render_click(element(view, "#layout-test-input-state-disabled"))
    refute has_element?(view, "#local_compute_plan input[type=radio]:not([disabled])")

    render_submit(view, "local_save", %{"local" => %{"project_name" => "Saved plan"}})
    assert has_element?(view, "#local_compute_plan input[value='6-core'][checked][disabled]")
  end

  test "disabled fieldsets preserve native control attributes and remain independent of direct disabled state",
       %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/dashboard/dev_panel/layout_test")

    view
    |> form("#layout-test-form", local: %{project_name: "Preserved draft"})
    |> render_change()

    for state <- ~w(required placeholder fieldset_disabled) do
      render_click(element(view, "#layout-test-input-state-#{state}"))
      assert has_element?(view, "#layout-test-input-state-#{state}[aria-pressed=true]")
    end

    assert has_element?(view, "fieldset#layout-test-input-examples[disabled]")
    refute has_element?(view, "#layout-test-input-state-disabled[aria-pressed=true]")

    for id <- ~w(local_project_name local_password local_budget local_launch_date) do
      assert has_element?(view, "fieldset[disabled] input##{id}:not([disabled])[required]")
    end

    assert has_element?(view, "input#local_launch_date[readonly][phx-hook=VCalendar]")

    assert has_element?(
             view,
             "input#local_project_name[value='Preserved draft'][placeholder='Example Text']"
           )

    assert has_element?(
             view,
             "#layout-test-input-example-text [data-core-input] .input-required",
             "*"
           )

    assert has_element?(
             view,
             "#layout-test-local-role select[name='local[role]']:not([disabled]) option[value=admin][selected]"
           )

    render_click(element(view, "#layout-test-input-state-disabled"))

    assert has_element?(
             view,
             "fieldset#layout-test-input-examples[disabled] input#local_project_name[disabled]"
           )

    render_click(element(view, "#layout-test-input-state-fieldset_disabled"))

    assert has_element?(
             view,
             "fieldset#layout-test-input-examples:not([disabled]) input#local_project_name[disabled]"
           )

    render_click(element(view, "#layout-test-input-state-disabled"))

    assert has_element?(
             view,
             "fieldset#layout-test-input-examples:not([disabled]) input#local_project_name:not([disabled])[value='Preserved draft']"
           )
  end

  test "checkbox and switch variants and checked states change the actual controls", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/dashboard/dev_panel/layout_test")

    for variant <- ~w(default alt) do
      render_click(element(view, "#layout-test-input-variant-#{variant}"))

      for checked <- ~w(false true) do
        render_click(element(view, "#layout-test-input-checked-#{checked}"))

        for field <- ~w(enabled switch) do
          assert has_element?(view, "input#local_#{field}[type=checkbox][name='local[#{field}]']")

          if checked == "true" do
            assert has_element?(view, "#local_#{field}[checked]")
          else
            refute has_element?(view, "#local_#{field}[checked]")
          end

          if variant == "alt" do
            assert has_element?(view, "label[for='local_#{field}'].grid.w-fit")
          else
            refute has_element?(view, "label[for='local_#{field}'].w-fit")
          end
        end
      end
    end

    render_change(view, "local_change", %{"local" => %{"enabled" => "true", "switch" => "false"}})
    render_click(element(view, "#layout-test-input-state-placeholder"))
    assert has_element?(view, "#local_enabled[checked]")
    refute has_element?(view, "#local_switch[checked]")
  end

  test "label, placeholder, required, and error states combine on the same example", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/dashboard/dev_panel/layout_test")

    for state <- ~w(unlabeled placeholder required errors) do
      render_click(element(view, "#layout-test-input-state-#{state}"))
      assert has_element?(view, "#layout-test-input-state-#{state}[aria-pressed=true]")
    end

    assert has_element?(
             view,
             "#local_project_name[required][placeholder='Example Text'][value='Layout Test']"
           )

    assert has_element?(view, "#layout-test-input-example-text", "Example validation error")
    refute has_element?(view, "#layout-test-input-example-text .input-floating-label")

    render_click(element(view, "#layout-test-input-render-hidden-disabled"))
    refute has_element?(view, "#layout-test-input-example-text", "Example validation error")
  end

  test "text boolean modes preserve native changes and submission while read-only sentences follow their state",
       %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/dashboard/dev_panel/layout_test")

    for mode <- ~w(text text-enabled) do
      render_click(element(view, "#layout-test-input-render-#{mode}"))

      for field <- ~w(enabled switch) do
        assert has_element?(
                 view,
                 "input#local_#{field}[type=checkbox][name='local[#{field}]'].sr-only"
               )

        assert has_element?(view, "label[for=local_#{field}]")
        assert has_element?(view, "input[type=hidden][name='local[#{field}]'][value=false]")
      end

      view
      |> form("#layout-test-form", local: %{enabled: "true", switch: "false"})
      |> render_change()

      assert has_element?(view, "input#local_enabled[checked]")
      refute has_element?(view, "input#local_switch[checked]")
      assert has_element?(view, "#layout-test-input-controls summary", "mixed")

      view
      |> form("#layout-test-form", local: %{enabled: "false", switch: "true"})
      |> render_submit()

      refute has_element?(view, "input#local_enabled[checked]")
      assert has_element?(view, "input#local_switch[checked]")
      assert has_element?(view, "#submitted-at")

      render_click(element(view, "#layout-test-input-render-text-disabled"))
      visible = view |> render() |> Floki.parse_document!() |> Floki.filter_out(".hidden")

      assert Floki.text(Floki.find(visible, "#layout-test-input-example-checkbox"))
             |> String.split()
             |> Enum.join(" ") == "Checkbox is disabled"

      assert Floki.text(Floki.find(visible, "#layout-test-input-example-switch"))
             |> String.split()
             |> Enum.join(" ") == "Switch is on"

      assert Floki.find(
               visible,
               "#layout-test-input-example-checkbox input, #layout-test-input-example-switch input"
             ) == []

      assert has_element?(view, ".hidden input#local_switch[checked]")
      refute has_element?(view, ".hidden input#local_enabled[checked]")

      view |> form("#layout-test-form") |> render_submit()
      assert has_element?(view, "#layout-test-input-example-checkbox", "Checkbox is disabled")
      assert has_element?(view, "#layout-test-input-example-switch", "Switch is on")

      render_click(element(view, "#layout-test-input-checked-true"))
      assert has_element?(view, "#layout-test-input-example-checkbox", "Checkbox is enabled")
      assert has_element?(view, "#layout-test-input-example-switch", "Switch is on")

      render_click(element(view, "#layout-test-input-checked-false"))
      assert has_element?(view, "#layout-test-input-example-checkbox", "Checkbox is disabled")
      assert has_element?(view, "#layout-test-input-example-switch", "Switch is off")
    end
  end

  test "checked choices follow edited values and update empty specimens", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/dashboard/dev_panel/layout_test")

    render_change(view, "local_change", %{
      "local" => %{"enabled" => "false", "switch" => "false"}
    })

    assert has_element?(view, "#layout-test-input-checked-false[aria-pressed=true]")
    refute has_element?(view, "#layout-test-input-checked-true[aria-pressed=true]")
    assert has_element?(view, "#layout-test-input-controls summary", "unchecked")

    render_change(view, "local_change", %{
      "local" => %{"enabled" => "true", "switch" => "false"}
    })

    refute has_element?(view, "#layout-test-input-checked-false[aria-pressed=true]")
    refute has_element?(view, "#layout-test-input-checked-true[aria-pressed=true]")
    assert has_element?(view, "#layout-test-input-controls summary", "mixed")

    render_click(element(view, "#layout-test-input-state-empty"))
    render_click(element(view, "#layout-test-input-checked-true"))

    assert has_element?(view, "#local_enabled[checked]")
    assert has_element?(view, "#local_switch[checked]")
    assert has_element?(view, "#layout-test-input-checked-true[aria-pressed=true]")

    render_click(element(view, "#layout-test-input-state-empty"))

    assert has_element?(view, "#local_enabled[checked]")
    assert has_element?(view, "#local_switch[checked]")
    assert has_element?(view, "#layout-test-input-checked-true[aria-pressed=true]")
  end

  test "attribute controls combine native constraints, presentation, and type-specific options",
       %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/dashboard/dev_panel/layout_test")

    for state <-
          ~w(readonly tooltip constraints datalist multiple capture custom_class custom_error_class prompt textarea_size errors) do
      render_click(element(view, "#layout-test-input-state-#{state}"))
    end

    assert has_element?(
             view,
             "#local_project_name[readonly][minlength='3'][maxlength='200'][pattern='[^<>]+'][size='12'][list=layout-test-input-cities].border-brand.border-error"
           )

    assert has_element?(
             view,
             "#layout-test-input-example-text [data-tooltip='Text input in enabled mode']"
           )

    assert has_element?(view, "#layout-test-input-cities option[value=Ipoh]")
    assert has_element?(view, "#local_budget[min='0'][max='100000'][step='5']")

    assert has_element?(
             view,
             "#local_notes[readonly][rows='6'][cols='60'].input-floating-textarea"
           )

    assert has_element?(view, "#local_upload[multiple][capture=environment][accept='image/*']")

    assert has_element?(
             view,
             "#layout-test-local-role-trigger [data-placeholder-text='Choose a role']",
             "Administrator"
           )

    assert has_element?(
             view,
             "#layout-test-local-role-select[name='local[role]'] option[value=admin][selected]"
           )

    refute has_element?(view, "#layout-test-input-example-combobox .input-floating-label")
    refute has_element?(view, "#local_enabled[readonly]")

    render_click(element(view, "#layout-test-input-state-capture"))
    assert has_element?(view, "#local_upload[multiple][accept='image/*,.pdf']:not([capture])")
  end

  test "empty values remain editable and restore the earlier populated fields", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/dashboard/dev_panel/layout_test")

    render_click(element(view, "#layout-test-input-state-empty"))
    render_click(element(view, "#layout-test-input-state-disabled"))
    assert has_element?(view, "#local_project_name[disabled]")
    refute has_element?(view, "#local_project_name[value='Layout Test']")
    refute has_element?(view, "#local_enabled[checked]")

    render_click(element(view, "#layout-test-input-state-disabled"))
    render_change(view, "local_change", %{"local" => %{"project_name" => "Kuching"}})
    render_change(view, "local_change", %{"local" => %{"email" => "new@example.com"}})
    assert has_element?(view, "#local_project_name[value=Kuching]")
    assert has_element?(view, "#local_email[value='new@example.com']")

    render_click(element(view, "#layout-test-input-state-empty"))
    assert has_element?(view, "#local_project_name[value='Layout Test']")
    assert has_element?(view, "#local_email[value='builder@elixirbits.dev']")
    assert has_element?(view, "#local_enabled[checked]")

    view
    |> form("#layout-test-form", local: %{project_name: "Updated"})
    |> render_change()

    render_click(element(view, "#layout-test-input-render-like-disabled"))
    render_change(view, "local_change", %{"local" => %{"email" => "another@example.com"}})
    assert has_element?(view, "#local_project_name[value=Updated]")
  end

  test "select and combobox selection modes preserve their values independently", %{
    conn: conn
  } do
    {:ok, view, _html} = live(conn, ~p"/dashboard/dev_panel/layout_test")

    assert has_element?(
             view,
             "#layout-test-local-role select[name='local[role]'] option[value=admin][selected]"
           )

    assert has_element?(
             view,
             "#layout-test-form-section select#local_native_role-select[name='local[native_role]'] option[value=admin][selected]"
           )

    assert has_element?(
             view,
             "#layout-test-form-section #layout-test-local-role[phx-hook=PetalComboBox]"
           )

    render_click(element(view, "#layout-test-input-combobox-mode-multiple"))

    assert has_element?(
             view,
             "#layout-test-local-role select[multiple][name='local[role][]'] option[value=admin][selected]"
           )

    assert has_element?(
             view,
             "select#local_native_role-select:not([multiple])[name='local[native_role]'] option[value=admin][selected]"
           )

    view
    |> form("#layout-test-form",
      local: %{role: ["designer", "viewer"], native_role: "viewer"}
    )
    |> render_change()

    render_click(element(view, "#layout-test-input-select-mode-multiple"))

    assert has_element?(
             view,
             "select#local_native_role-select[multiple][name='local[native_role][]'] option[value=viewer][selected]"
           )

    assert has_element?(view, "#local_native_role[phx-hook=PetalComboBox]")

    assert has_element?(
             view,
             "#local_native_role-trigger [data-pc-combo-trigger-label]",
             "1 selected"
           )

    assert has_element?(view, "label[for=local_native_role-trigger]", "Select")
    refute has_element?(view, "select#local_native_role")

    for role <- ~w(designer viewer) do
      assert has_element?(
               view,
               "#layout-test-local-role select[multiple][name='local[role][]'] option[value=#{role}][selected]"
             )
    end

    view
    |> form("#layout-test-form",
      local: %{role: ["designer", "viewer"], native_role: ["admin", "viewer"]}
    )
    |> render_change()

    render_click(element(view, "#layout-test-input-combobox-mode-single"))

    assert has_element?(
             view,
             "#layout-test-local-role select[name='local[role]'] option[value=designer][selected]"
           )

    for role <- ~w(admin viewer) do
      assert has_element?(
               view,
               "select#local_native_role-select[multiple][name='local[native_role][]'] option[value=#{role}][selected]"
             )
    end

    refute has_element?(view, "#layout-test-local-role select[multiple]")

    render_click(element(view, "#layout-test-input-select-mode-single"))

    assert has_element?(
             view,
             "select#local_native_role-select:not([multiple])[name='local[native_role]'] option[value=admin][selected]"
           )

    assert has_element?(
             view,
             "#layout-test-local-role select:not([multiple])[name='local[role]'] option[value=designer][selected]"
           )

    render_click(element(view, "#layout-test-input-select-mode-multiple"))

    assert has_element?(
             view,
             "select#local_native_role-select[multiple][name='local[native_role][]']"
           )

    assert has_element?(view, "#local_native_role[phx-hook=PetalComboBox]")

    assert has_element?(
             view,
             "#layout-test-local-role select:not([multiple])[name='local[role]'] option[value=designer][selected]"
           )
  end

  test "disabled forms handle omitted fields on change and submission without losing retained values",
       %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/dashboard/dev_panel/layout_test")

    render_change(view, "local_change", %{
      "local" => %{"project_name" => "Kuching", "email" => "new@example.com"}
    })

    render_click(element(view, "#layout-test-input-state-disabled"))
    render_change(view, "local_change", %{"_target" => ["local", "phone_country_code"]})
    assert has_element?(view, "#local_project_name[disabled][value=Kuching]")
    assert has_element?(view, "#local_email[disabled][value='new@example.com']")

    render_click(element(view, "#layout-test-input-state-empty"))
    render_change(view, "local_change", %{"_target" => ["local", "phone_country_code"]})
    assert has_element?(view, "#local_project_name[disabled]")
    refute has_element?(view, "#local_project_name[value=Kuching]")
    refute has_element?(view, "#layout-test-input-example-select input[type=hidden]")

    render_submit(view, "local_save", %{})
    assert has_element?(view, "#layout-test-form", "Enter a valid date and time.")
    refute has_element?(view, "#submitted-at")

    render_click(element(view, "#layout-test-input-state-empty"))
    assert has_element?(view, "#local_project_name[disabled][value=Kuching]")
    assert has_element?(view, "#local_email[disabled][value='new@example.com']")
  end

  test "empty multiple selection markers clear merged values on change and submission", %{
    conn: conn
  } do
    {:ok, view, _html} = live(conn, ~p"/dashboard/dev_panel/layout_test")

    for control <- ~w(select combobox) do
      render_click(element(view, "#layout-test-input-#{control}-mode-multiple"))
    end

    for {field, selector} <- [
          {"role", "#layout-test-local-role select"},
          {"native_role", "select#local_native_role-select"}
        ],
        event <- ~w(local_change local_save) do
      render_change(view, "local_change", %{"local" => %{field => ["admin"]}})

      assert has_element?(
               view,
               "#{selector}[name='local[#{field}][]'] option[value=admin][selected]"
             )

      params = %{
        "_target" => ["local", field],
        "local" => %{field => [""], "launch_at" => "2026-10-10T09:30"}
      }

      if event == "local_change" do
        render_change(view, event, params)
      else
        render_submit(view, event, params)
      end

      assert has_element?(view, "#{selector}[name='local[#{field}][]']")
      refute has_element?(view, "#{selector} option[selected]")
    end

    assert has_element?(view, "#submitted-at")
  end

  test "omitted multiple choices retain values when their controls cannot be edited", %{
    conn: conn
  } do
    {:ok, view, _html} = live(conn, ~p"/dashboard/dev_panel/layout_test")

    for control <- ~w(select combobox) do
      render_click(element(view, "#layout-test-input-#{control}-mode-multiple"))
    end

    for mode <- ~w(disabled like-enabled like-disabled text-disabled hidden-disabled) do
      render_click(element(view, "#layout-test-input-render-#{mode}"))
      render_change(view, "local_change", %{"_target" => ["local", "role"]})
      render_submit(view, "local_save", %{"local" => %{"launch_at" => "2026-10-10T09:30"}})
      render_click(element(view, "#layout-test-input-render-enabled"))

      assert has_element?(view, "#layout-test-local-role select option[value=admin][selected]")
      assert has_element?(view, "select#local_native_role-select option[value=admin][selected]")
    end

    render_click(element(view, "#layout-test-input-state-disabled"))
    render_change(view, "local_change", %{"_target" => ["local", "native_role"]})
    render_submit(view, "local_save", %{"local" => %{"launch_at" => "2026-10-10T09:30"}})
    render_click(element(view, "#layout-test-input-state-disabled"))

    assert has_element?(view, "#layout-test-local-role select option[value=admin][selected]")
    assert has_element?(view, "select#local_native_role-select option[value=admin][selected]")
  end

  test "submission shows validation errors after earlier unused field metadata", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/dashboard/dev_panel/layout_test")

    render_change(view, "local_change", %{
      "local" => %{
        "project_name" => "Changed",
        "launch_at" => "2026-10-10T09:30",
        "_unused_launch_at" => ""
      }
    })

    render_submit(view, "local_save", %{"local" => %{"launch_at" => "invalid"}})

    assert has_element?(view, "#layout-test-form", "Enter a valid date and time.")
    assert has_element?(view, "#local_project_name[value=Changed]")
  end
end

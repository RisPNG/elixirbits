defmodule ElixirbitsWeb.Dashboard.LayoutTestLiveTest do
  use ElixirbitsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "renders local tab by default and switches to ecosystem tab", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/dashboard/dev_panel/design_standards")

    assert has_element?(view, "h1", "Design Standards")
    assert has_element?(view, "#layout-test-local-tab[aria-selected=\"true\"]")
    assert has_element?(view, "#layout-test-local-panel[aria-hidden=false]:not(.hidden)")
    assert has_element?(view, "#layout-test-form[novalidate]")
    assert has_element?(view, "#layout-test-upload-form[novalidate]")
    assert has_element?(view, "#layout-test-core-table")
    assert has_element?(view, "#local_project_name.input-floating-control[placeholder=\" \"]")

    assert has_element?(
             view,
             "#local_accent[type=text][name='local[accent]'][data-color-value][value='#c9822b']"
           )

    assert has_element?(view, "#local_accent-color-input[phx-hook=ColorInput]")

    assert has_element?(
             view,
             "#local_accent_color_space_select[phx-hook=PetalComboBox] select[name='local[accent_color_space]'] option[value=hex][selected]"
           )

    refute has_element?(view, "#local_accent-color-input [data-color-cycle]")

    assert has_element?(
             view,
             "#local_accent-color-input button[type=button][data-color-trigger][popovertarget=local_accent-color-popover][aria-label='Choose color']"
           )

    assert has_element?(
             view,
             "#local_accent-color-popover[popover=auto][role=dialog] rgba-color-picker#local_accent-color-picker[data-color-picker][phx-update=ignore]:not([name])"
           )

    assert has_element?(view, "#local_notes.input-floating-textarea[placeholder=\" \"]")
    assert has_element?(view, "label[for=\"local_project_name\"] .input-floating-label")
    assert has_element?(view, "label[for=local_accent].input-floating-label")
    assert has_element?(view, "#local_phone_tel_wrapper .input-floating-wrapper.gap-0")
    assert has_element?(view, "label[for=\"local_notes\"] .input-floating-label")
    assert has_element?(view, "#layout-test-ecosystem-panel.hidden[aria-hidden=true]")

    render_click(element(view, "#layout-test-ecosystem-tab"))

    assert_push_event(view, "swipe", %{id: "dashboard-page", direction: "left"})
    assert has_element?(view, "#layout-test-ecosystem-tab[aria-selected=\"true\"]")
    assert has_element?(view, "#layout-test-ecosystem-panel[aria-hidden=false]:not(.hidden)")
    assert has_element?(view, "#layout-test-dependency-form[novalidate]")
    assert has_element?(view, "#layout-test-cinder-collection[data-layout=table]")
    render_click(element(view, "#cinder-layout-grid"))
    assert has_element?(view, "#layout-test-cinder-collection[data-layout=grid]")
    assert has_element?(view, "#layout-test-local-panel.hidden[aria-hidden=true]")

    render_click(element(view, "#layout-test-local-tab"))

    assert_push_event(view, "swipe", %{id: "dashboard-page", direction: "right"})
    assert has_element?(view, "#layout-test-local-panel[aria-hidden=false]:not(.hidden)")
  end

  test "compact component tabs keep their selections and the collection uses searchable cards", %{
    conn: conn
  } do
    conn = put_connect_params(conn, %{"compact_layout" => true})
    {:ok, view, _html} = live(conn, ~p"/dashboard/dev_panel/design_standards")

    compact = "#layout-test-compact"
    group_tabs = "#{compact}-groups"
    local_tabs = "#{compact}-local-tabs"
    ecosystem_tabs = "#{compact}-ecosystem-tabs"
    collection = "#{compact}-collection-pagination"
    controls = "#{collection} form[phx-change=filter_change]"
    cards = "#{collection} .identity-grid article"
    page_info = "#{collection} [data-key=pagination_info_class]"

    assert has_element?(view, "#{compact} h1", "Design Standards")
    assert has_element?(view, "#{group_tabs}-local[aria-selected=true]")
    assert has_element?(view, "#{local_tabs}-inputs[aria-selected=true]")
    assert has_element?(view, "#{compact}-inputs[role=tabpanel]:not([hidden])")
    refute has_element?(view, "#layout-test-core-table")

    view |> element("#{local_tabs}-dates") |> render_click()
    assert has_element?(view, "#{compact}-dates[role=tabpanel]:not([hidden])")
    refute has_element?(view, "#{compact}-inputs:not([hidden])")

    view |> element("#{group_tabs}-ecosystem") |> render_click()
    render_async(view)
    assert has_element?(view, "#{ecosystem_tabs}-lists[aria-selected=true]")
    assert has_element?(view, cards, "Core inputs example 001")
    assert has_element?(view, page_info, "Page 1 of 12")
    refute has_element?(view, "#{collection} table")
    refute has_element?(view, "#cinder-layout-choices")

    view |> element("#{collection} button[title='Next page']") |> render_click()
    render_async(view)
    assert has_element?(view, page_info, "Page 2 of 12")
    refute has_element?(view, cards, "Core inputs example 001")

    view |> form(controls, search: "EX004") |> render_change()
    render_async(view)
    assert has_element?(view, cards, "Calendar example 004")
    refute has_element?(view, cards, "Core inputs example 001")

    view |> element("#{ecosystem_tabs}-ui-kit") |> render_click()
    assert has_element?(view, "#{compact}-ui-kit[role=tabpanel]:not([hidden])")

    view |> element("#{group_tabs}-local") |> render_click()
    assert has_element?(view, "#{local_tabs}-dates[aria-selected=true]")

    view |> element("#{group_tabs}-ecosystem") |> render_click()
    assert has_element?(view, "#{ecosystem_tabs}-ui-kit[aria-selected=true]")
    view |> element("#{ecosystem_tabs}-lists") |> render_click()
    render_async(view)
    assert has_element?(view, "#{controls} input[name=search][value=EX004]")
    assert has_element?(view, cards, "Calendar example 004")

    view |> form(controls, search: "Timers example") |> render_change()
    render_async(view)
    assert has_element?(view, cards, "Timers example 005")
    refute has_element?(view, cards, "Calendar example 004")

    render_click(view, "dashboard_layout", %{"compact" => false})
    render_async(view)
    assert has_element?(view, "#layout-test-core-table")
    assert has_element?(view, "#layout-test-ecosystem-tab[aria-selected=true]")
    assert has_element?(view, "#layout-test-cinder-collection[data-layout=table] table")
    refute has_element?(view, group_tabs)
  end

  test "compact Layout Test exposes the full showcase catalogue through component tabs", %{
    conn: conn
  } do
    conn = put_connect_params(conn, %{"compact_layout" => true})
    {:ok, view, _html} = live(conn, ~p"/dashboard/dev_panel/design_standards")

    for {topic, specimen} <- [
          {"appearance", "#layout-test-compact-colors [data-color-token]"},
          {"calendar", "#calendar-showcase"},
          {"icons", "#layout-test-icon-preview"},
          {"controls", "#layout-test-compact-flash"},
          {"data", "#layout-test-compact-table"}
        ] do
      view |> element("#layout-test-compact-local-tabs-#{topic}") |> render_click()
      assert has_element?(view, "#layout-test-compact-#{topic}:not([hidden]) #{specimen}")
    end

    view |> element("#layout-test-compact-groups-ecosystem") |> render_click()
    view |> element("#layout-test-compact-ecosystem-tabs-ui-kit") |> render_click()
    assert has_element?(view, "#layout-test-compact-ui-kit:not([hidden]) progress")
    view |> element("#layout-test-compact-ecosystem-tabs-pages") |> render_click()

    assert has_element?(
             view,
             "#layout-test-compact-pages:not([hidden]) a[href='/api/json/scalar']"
           )
  end

  test "local color changes and submissions preserve the selected syntax and transparency", %{
    conn: conn
  } do
    {:ok, view, _html} = live(conn, ~p"/dashboard/dev_panel/design_standards")

    for value <- [
          "#12345678",
          "rgb(18 52 86 / 0.5)",
          "rgba(18, 52, 86, 0.5)",
          "hsl(210 65% 20% / 0.5)",
          "hsla(210, 65%, 20%, 0.5)",
          "lab(52 -2 -7 / 0.5)",
          "lch(52 24 270 / 0.5)",
          "oklab(0.32 -0.02 -0.07 / 0.5)",
          "oklch(0.32 0.073 254 / 0.5)",
          "color(xyz-d50 0.2 0.3 0.4 / 0.5)",
          "color(xyz-d65 0.2 0.3 0.4 / 0.5)",
          "device-cmyk(0.1 0.2 0.3 0.4 / 0.5)"
        ] do
      render_change(view, "local_change", %{"local" => %{"accent" => value}})
      document = view |> render() |> Floki.parse_document!()
      assert Floki.attribute(document, "input#local_accent", "value") == [value]

      render_change(view, "local_change", %{"local" => %{"project_name" => "Planning"}})
      document = view |> render() |> Floki.parse_document!()
      assert Floki.attribute(document, "input#local_accent", "value") == [value]

      document =
        view
        |> form("#layout-test-form", local: %{accent: value})
        |> render_submit()
        |> Floki.parse_document!()

      assert Floki.attribute(document, "input#local_accent", "value") == [value]
      assert has_element?(view, "#submitted-at")
      assert has_element?(view, "#flash-info", "Example form submitted.")
    end
  end

  test "invalid color edits and forged submissions retain their text until corrected", %{
    conn: conn
  } do
    {:ok, view, _html} = live(conn, ~p"/dashboard/dev_panel/design_standards")

    for value <- [
          "#12",
          "rgba(18, 52, 86, invalid)",
          "color(--unsupported 1 0 0)",
          "color(display-p3 1 0 0 / 0.5)",
          "hwb(210 7% 66% / 0.5)"
        ] do
      html = render_change(view, "local_change", %{"local" => %{"accent" => value}})
      document = Floki.parse_document!(html)
      assert Floki.attribute(document, "input#local_accent", "value") == [value]
      assert Floki.text(document) =~ "must be a supported color value"
      assert has_element?(view, "#local_accent[aria-invalid=true]")

      html =
        render_submit(view, "local_save", %{
          "local" => %{"accent" => value, "launch_at" => "2026-04-23T09:30"}
        })

      document = Floki.parse_document!(html)
      assert Floki.attribute(document, "input#local_accent", "value") == [value]
      assert Floki.text(document) =~ "must be a supported color value"
      refute has_element?(view, "#submitted-at")
      refute has_element?(view, "#flash-info")
    end

    html =
      render_submit(view, "local_save", %{
        "local" => %{"accent" => "not a color", "launch_at" => "not a datetime"}
      })

    assert html =~ "must be a supported color value"
    assert html =~ "Enter a valid date and time."
    refute has_element?(view, "#submitted-at")

    value = "oklch(0.65 0.15 270 / 0.5)"
    html = render_change(view, "local_change", %{"local" => %{"accent" => value}})
    refute html =~ "must be a supported color value"
    refute has_element?(view, "#local_accent[aria-invalid=true]")

    view
    |> form("#layout-test-form", local: %{accent: value, launch_at: "2026-04-23T09:30"})
    |> render_submit()

    document = view |> render() |> Floki.parse_document!()
    assert Floki.attribute(document, "input#local_accent", "value") == [value]
    assert has_element?(view, "#submitted-at")
    assert has_element?(view, "#flash-info", "Example form submitted.")
  end

  test "color-space combobox offers native output formats and keeps form selections", %{
    conn: conn
  } do
    {:ok, view, _html} = live(conn, ~p"/dashboard/dev_panel/design_standards")
    selector_id = "local_accent_color_space_select"

    document = view |> render() |> Floki.parse_document!()
    assert length(Floki.find(document, "##{selector_id} [role=option]")) == 10

    for label <- [
          "HEX",
          "RGB",
          "HSL",
          "Lab",
          "LCH",
          "OKLab",
          "OKLCH",
          "XYZ D50",
          "XYZ D65",
          "CMYK"
        ] do
      assert has_element?(view, "##{selector_id} [role=option]", label)
    end

    for {label, mode} <- [
          {"RGB", "rgb"},
          {"HSL", "hsl"},
          {"XYZ D50", "xyz-d50"},
          {"CMYK", "cmyk"}
        ] do
      view
      |> form("#layout-test-form", local: %{accent: "", accent_color_space: mode})
      |> render_change()

      assert has_element?(
               view,
               "##{selector_id} select[name='local[accent_color_space]'] option[value=#{mode}][selected]"
             )

      document = view |> render() |> Floki.parse_document!()

      assert document
             |> Floki.find("##{selector_id} [data-pc-combo-trigger-label]")
             |> Floki.text()
             |> String.trim() == label

      assert Floki.attribute(document, "#local_accent[data-color-value]", "value") == [""]
      assert length(Floki.find(document, "[name='local[accent]']")) == 1
    end
  end

  test "pasted color syntax selects its space and incomplete drafts keep the selected space", %{
    conn: conn
  } do
    {:ok, view, _html} = live(conn, ~p"/dashboard/dev_panel/design_standards")
    selector = "#local_accent_color_space_select"
    value = "color(xyz-d50 0.2 0.3 0.4 / 0.375)"

    render_change(view, "local_change", %{
      "local" => %{"accent" => value, "accent_color_space" => "rgb"}
    })

    document = view |> render() |> Floki.parse_document!()
    assert Floki.attribute(document, "#local_accent", "value") == [value]

    assert Floki.attribute(document, "#{selector} select option[selected]", "value") == [
             "xyz-d50"
           ]

    assert document
           |> Floki.find("#{selector} [data-pc-combo-trigger-label]")
           |> Floki.text()
           |> String.trim() == "XYZ D50"

    render_change(view, "local_change", %{
      "local" => %{"accent" => "oklch(", "accent_color_space" => "xyz-d50"}
    })

    document = view |> render() |> Floki.parse_document!()
    assert Floki.attribute(document, "#local_accent", "value") == ["oklch("]

    assert Floki.attribute(document, "#{selector} select option[selected]", "value") == [
             "xyz-d50"
           ]

    assert document
           |> Floki.find("#{selector} [data-pc-combo-trigger-label]")
           |> Floki.text()
           |> String.trim() == "XYZ D50"

    assert has_element?(view, "#local_accent[aria-invalid=true]")

    render_change(view, "local_change", %{
      "local" => %{"accent" => "", "accent_color_space" => "unsupported"}
    })

    document = view |> render() |> Floki.parse_document!()
    assert Floki.attribute(document, "#local_accent", "value") == [""]
    assert Floki.attribute(document, "#{selector} select option[selected]", "value") == ["hex"]

    assert document
           |> Floki.find("#{selector} [data-pc-combo-trigger-label]")
           |> Floki.text()
           |> String.trim() == "HEX"
  end

  test "native validation detects pasted syntax without rewriting the parent form", %{
    conn: conn
  } do
    {:ok, view, _html} = live(conn, ~p"/dashboard/dev_panel/design_standards")
    selector_id = "local_accent_color_space_select"
    value = "  OKLCH(0.656789 0.156789 123.456789 / 0.3756789)  "

    render_hook(view, "color_input", %{
      "id" => "local_accent-color-input",
      "selector_id" => selector_id,
      "value" => value,
      "format" => "rgb",
      "operation" => "validate"
    })

    assert_reply view, %{
      valid: true,
      value: ^value,
      format: "oklch",
      swatch: swatch,
      rgba: %{a: alpha}
    }

    assert is_binary(swatch)
    assert_in_delta alpha, 0.3756789, 1.0e-10
    document = view |> render() |> Floki.parse_document!()

    assert Floki.attribute(document, "##{selector_id} select option[selected]", "value") == [
             "hex"
           ]

    assert document
           |> Floki.find("##{selector_id} [data-pc-combo-trigger-label]")
           |> Floki.text()
           |> String.trim() == "HEX"

    assert Floki.attribute(document, "#local_accent", "value") == ["#c9822b"]

    for {input, format} <- [{"oklch(", "oklch"}, {value, "unsupported"}] do
      render_hook(view, "color_input", %{
        "id" => "local_accent-color-input",
        "selector_id" => selector_id,
        "value" => input,
        "format" => format,
        "operation" => "validate"
      })

      assert_reply view, %{valid: false, error: "Enter a supported color value."}
      document = view |> render() |> Floki.parse_document!()

      assert Floki.attribute(document, "##{selector_id} select option[selected]", "value") == [
               "hex"
             ]

      assert document
             |> Floki.find("##{selector_id} [data-pc-combo-trigger-label]")
             |> Floki.text()
             |> String.trim() == "HEX"

      assert Floki.attribute(document, "#local_accent", "value") == ["#c9822b"]
    end
  end

  test "format conversions return native output and retain precision through a HEX display", %{
    conn: conn
  } do
    {:ok, view, _html} = live(conn, ~p"/dashboard/dev_panel/design_standards")
    value = "oklch(0.656789 0.156789 123.456789 / 0.3756789)"

    render_hook(view, "color_input", %{
      "id" => "local_accent-color-input",
      "selector_id" => "local_accent_color_space_select",
      "value" => value,
      "format" => "hex",
      "operation" => "convert"
    })

    assert_reply view, %{valid: true, value: hex, format: "hex"}
    assert Regex.match?(~r/^#[0-9a-f]{8}$/i, hex)

    render_hook(view, "color_input", %{
      "id" => "local_accent-color-input",
      "selector_id" => "local_accent_color_space_select",
      "value" => hex,
      "format" => "oklch",
      "operation" => "convert"
    })

    assert_reply view, %{valid: true, value: converted, format: "oklch", rgba: %{a: alpha}}
    {:ok, source} = Color.CSS.parse(value)
    assert converted == Color.CSS.to_css(source)
    assert_in_delta alpha, 0.3756789, 1.0e-10
    assert has_element?(view, "#local_accent[value='#c9822b']")
  end

  test "successive format changes keep an optional empty color empty", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/dashboard/dev_panel/design_standards")
    selector_id = "local_accent_color_space_select"
    render_change(view, "local_change", %{"local" => %{"accent" => ""}})

    for format <- ["rgb", "oklch"] do
      render_hook(view, "color_input", %{
        "id" => "local_accent-color-input",
        "selector_id" => selector_id,
        "value" => "",
        "format" => format,
        "operation" => "convert"
      })

      assert_reply view, %{valid: true, value: "", format: ^format, swatch: nil, rgba: nil}

      assert has_element?(view, "#local_accent[value='']")
    end
  end

  test "explicit color clearing keeps both fields empty through parent form updates", %{
    conn: conn
  } do
    {:ok, view, _html} = live(conn, ~p"/dashboard/dev_panel/design_standards")
    selector_id = "local_accent_color_space_select"

    render_hook(view, "color_input", %{
      "id" => "local_accent-color-input",
      "selector_id" => selector_id,
      "value" => "",
      "format" => "",
      "operation" => "clear"
    })

    assert_reply view, %{valid: true, value: "", format: "", label: "", swatch: nil, rgba: nil}

    view
    |> form("#layout-test-form", local: %{accent: "", accent_color_space: ""})
    |> render_change()

    view
    |> form("#layout-test-form", local: %{project_name: "Updated after clearing"})
    |> render_change()

    document = view |> render() |> Floki.parse_document!()
    assert Floki.attribute(document, "#local_accent", "value") == [""]
    assert Floki.find(document, "##{selector_id} select option[value='']") != []

    assert document
           |> Floki.attribute("##{selector_id} select option[selected]", "value")
           |> Enum.reject(&(&1 == "")) == []

    [state] = Floki.attribute(document, "#local_accent-color-input", "data-color-state")
    assert %{"value" => "", "format" => "", "label" => "", "swatch" => nil} = Jason.decode!(state)

    render_hook(view, "color_input", %{
      "id" => "local_accent-color-input",
      "selector_id" => selector_id,
      "value" => "",
      "format" => "",
      "operation" => "validate"
    })

    assert_reply view, %{valid: true, value: "", format: "", label: "", swatch: nil, rgba: nil}

    render_hook(view, "color_input", %{
      "id" => "local_accent-color-input",
      "selector_id" => selector_id,
      "value" => "hsl(30 50% 50%)",
      "format" => "",
      "operation" => "validate"
    })

    assert_reply view, %{valid: true, value: "hsl(30 50% 50%)", format: "hsl", label: "HSL"}

    view
    |> form("#layout-test-form", local: %{accent: "hsl(30 50% 50%)"})
    |> render_change()

    assert has_element?(view, "##{selector_id} select option[value=hsl][selected]")
  end

  test "a picker color uses HEX when its format was explicitly cleared", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/dashboard/dev_panel/design_standards")
    selector_id = "local_accent_color_space_select"

    render_hook(view, "color_input", %{
      "id" => "local_accent-color-input",
      "selector_id" => selector_id,
      "value" => "",
      "format" => "",
      "operation" => "clear"
    })

    assert_reply view, %{valid: true, value: "", format: ""}

    view
    |> form("#layout-test-form", local: %{accent: "", accent_color_space: ""})
    |> render_change()

    render_hook(view, "color_input", %{
      "id" => "local_accent-color-input",
      "selector_id" => selector_id,
      "value" => "",
      "format" => "",
      "operation" => "pick",
      "rgba" => %{"r" => 24, "g" => 68, "b" => 102, "a" => 1},
      "alpha_changed" => true
    })

    assert_reply view, %{valid: true, value: "#184466", format: "hex", label: "HEX"}

    view
    |> form("#layout-test-form", local: %{accent: "#184466", accent_color_space: "hex"})
    |> render_change()

    assert has_element?(view, "#local_accent[value='#184466']")
    assert has_element?(view, "##{selector_id} select option[value=hex][selected]")
  end

  test "picker edits retain source transparency until the alpha control changes", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/dashboard/dev_panel/design_standards")
    value = "rgb(18 52 86 / 0.3756789)"

    render_hook(view, "color_input", %{
      "id" => "local_accent-color-input",
      "selector_id" => "local_accent_color_space_select",
      "value" => value,
      "format" => "rgb",
      "operation" => "validate"
    })

    assert_reply view, %{valid: true, value: ^value, format: "rgb"}

    render_hook(view, "color_input", %{
      "id" => "local_accent-color-input",
      "selector_id" => "local_accent_color_space_select",
      "value" => value,
      "format" => "rgb",
      "operation" => "pick",
      "rgba" => %{"r" => 24, "g" => 68, "b" => 102, "a" => 0.38},
      "alpha_changed" => false
    })

    assert_reply view, %{valid: true, value: picked, format: "rgb", rgba: %{a: preserved_alpha}}
    assert_in_delta preserved_alpha, 0.3756789, 1.0e-10

    render_hook(view, "color_input", %{
      "id" => "local_accent-color-input",
      "selector_id" => "local_accent_color_space_select",
      "value" => picked,
      "format" => "rgb",
      "operation" => "pick",
      "rgba" => %{"r" => 24, "g" => 68, "b" => 102, "a" => 0.5},
      "alpha_changed" => true
    })

    assert_reply view, %{
      valid: true,
      value: "rgb(24 68 102 / 0.5)",
      format: "rgb",
      rgba: %{a: 0.5}
    }

    assert has_element?(view, "#local_accent[value='#c9822b']")
  end

  test "picker integer alpha endpoints create colors from an empty field", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/dashboard/dev_panel/design_standards")
    render_change(view, "local_change", %{"local" => %{"accent" => ""}})

    for {alpha, expected} <- [{1, "rgb(24 68 102)"}, {0, "rgb(24 68 102 / 0)"}] do
      render_hook(view, "color_input", %{
        "id" => "local_accent-color-input",
        "selector_id" => "local_accent_color_space_select",
        "value" => "",
        "format" => "rgb",
        "operation" => "pick",
        "rgba" => %{"r" => 24, "g" => 68, "b" => 102, "a" => alpha},
        "alpha_changed" => true
      })

      assert_reply view, %{valid: true, value: ^expected, format: "rgb", rgba: %{a: actual_alpha}}
      assert actual_alpha == alpha

      assert has_element?(view, "#local_accent[value='']")
    end
  end

  test "switching tabs keeps pending uploads mounted with their original file references", %{
    conn: conn
  } do
    {:ok, view, _html} = live(conn, ~p"/dashboard/dev_panel/design_standards")
    render_click(element(view, "#upload-selection-singles"))

    upload =
      file_input(view, "#layout-test-upload-form", :demo_files, [
        %{name: "notes.txt", content: "Pending across tabs", type: "text/plain"}
      ])

    document = upload |> render_upload("notes.txt") |> Floki.parse_document!()
    selector = "#layout-test-upload-input input[type=file]"
    [input_id] = Floki.attribute(document, selector, "id")
    [entry_refs] = Floki.attribute(document, selector, "data-phx-active-refs")
    assert entry_refs != ""

    render_click(element(view, "#layout-test-ecosystem-tab"))

    assert has_element?(
             view,
             "#layout-test-local-panel.hidden input[id='#{input_id}'][data-phx-active-refs='#{entry_refs}']"
           )

    render_click(element(view, "#layout-test-local-tab"))

    assert has_element?(
             view,
             "#layout-test-local-panel:not(.hidden) input[id='#{input_id}'][data-phx-active-refs='#{entry_refs}']"
           )

    assert Floki.text(preview_document(view)) =~ "notes.txt"
    assert Floki.find(preview_document(view), "button[phx-click=cancel_upload]") != []
    assert has_element?(view, "#layout-test-upload-input [data-file-selection=singles]")
    assert Floki.find(preview_document(view), "[data-file-cycle=previous]") != []
    assert Floki.find(preview_document(view), "[data-file-cycle=next]") != []
  end

  test "preview layout changes preserve native PDF viewers, captions, and upload actions", %{
    conn: conn
  } do
    {:ok, view, _html} = live(conn, ~p"/dashboard/dev_panel/design_standards")

    upload =
      file_input(view, "#layout-test-upload-form", :demo_files, [
        %{name: "document.pdf", content: "%PDF-1.7\nPreview fixture", type: "application/pdf"}
      ])

    document = upload |> render_upload("document.pdf") |> Floki.parse_document!()

    [entry_ref] =
      Floki.attribute(
        document,
        "#layout-test-upload-input input[type=file]",
        "data-phx-active-refs"
      )

    [pdf_id] =
      Floki.attribute(
        preview_document(view),
        "[phx-hook=UploadPdfPreview][data-entry-ref='#{entry_ref}']",
        "id"
      )

    for preview_as <- ~w(tag thumbnail) do
      render_click(element(view, "#upload-preview-#{preview_as}"))
      document = view |> render() |> Floki.parse_document!()
      previews = preview_document(view)

      assert Floki.find(
               previews,
               "##{pdf_id}[phx-hook=UploadPdfPreview][phx-update=ignore][data-entry-ref='#{entry_ref}']"
             ) != []

      assert Floki.find(
               previews,
               "##{pdf_id} iframe[data-pdf-viewer][title='PDF preview of document.pdf']"
             ) != []

      assert Floki.find(
               previews,
               "##{pdf_id} a[data-pdf-open][target=_blank][rel='noopener noreferrer']"
             ) != []

      if preview_as == "tag" do
        assert Floki.find(previews, ".hidden ##{pdf_id}") != []
      else
        assert Floki.find(previews, ".hidden ##{pdf_id}") == []
      end

      assert Floki.attribute(
               document,
               "#layout-test-upload-input input[type=file]",
               "data-phx-active-refs"
             ) == [entry_ref]

      assert Floki.text(previews) =~ "document.pdf"
      assert Floki.find(previews, "[data-file-stored].hidden") != []
      assert Floki.find(previews, "img[src='/images/logo.svg']") != []

      assert Floki.find(previews, "button[phx-click=cancel_upload][phx-value-ref='#{entry_ref}']") !=
               []

      assert Floki.find(previews, "button[phx-click=remove_upload]") != []
    end
  end

  test "flash buttons trigger layout flash output", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/dashboard/dev_panel/design_standards")

    render_click(element(view, "#layout-test-flash-kind-info"))
    render_click(element(view, "#layout-test-flash-show"))
    assert has_element?(view, "#flash-info")

    assert has_element?(
             view,
             "#flash-info[phx-hook=\"FlashAutoDismiss\"][data-duration=\"5000\"]"
           )

    render_click(element(view, "#layout-test-flash-kind-error"))
    render_click(element(view, "#layout-test-flash-show"))
    assert has_element?(view, "#flash-error")

    render_click(element(view, "#layout-test-flash-kind-warning"))
    render_click(element(view, "#layout-test-flash-show"))
    assert has_element?(view, "#flash-warning")

    assert has_element?(
             view,
             "#flash-warning[phx-hook=\"FlashAutoDismiss\"][data-duration=\"8000\"]"
           )
  end

  test "flash accepts structured payloads and prefixed group IDs" do
    html =
      render_component(&ElixirbitsWeb.CoreComponents.flash/1,
        kind: :warning,
        flash: %{
          "warning" => %{
            title: "Heads up",
            msg: "Review this state",
            icon: "hero-bell",
            duration: 1200,
            show_spinner: true
          }
        }
      )

    assert html =~ "Heads up"
    assert html =~ "Review this state"
    assert html =~ "hero-bell"
    assert html =~ "hero-arrow-path"
    assert html =~ ~s(phx-hook="FlashAutoDismiss")
    assert html =~ ~s(data-duration="1200")

    html =
      render_component(&ElixirbitsWeb.CoreComponents.flash_group/1,
        flash: %{},
        id_prefix: "demo-modal"
      )

    assert html =~ ~s(id="demo-modal-flash-group")
    assert html =~ ~s(id="demo-modal-client-error")
    assert html =~ ~s(id="demo-modal-server-error")
  end

  test "dependency combobox keeps all choices available after a form selection", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/dashboard/dev_panel/design_standards")

    assert has_element?(view, "#layout-test-form-section #layout-test-dependency-combobox")

    view
    |> form("#layout-test-dependency-form",
      dependency: %{component_search: "/dashboard/dev/dashboard"}
    )
    |> render_change()

    assert has_element?(view, "#selected-dependency-dashboard")

    assert has_element?(
             view,
             "#layout-test-dependency-combobox select option[value='/dashboard/dev/dashboard'][selected]"
           )

    document = view |> render() |> Floki.parse_document!()
    assert length(Floki.find(document, "#layout-test-dependency-combobox [role=option]")) == 3
  end

  test "core combobox retains its explicit ID and updates the matching form field", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/dashboard/dev_panel/design_standards")
    assert has_element?(view, "#layout-test-local-role")

    view
    |> form("#layout-test-form", local: %{role: "viewer"})
    |> render_change()

    assert has_element?(view, "#layout-test-local-role [role=option]", "Viewer")
    assert has_element?(view, "#layout-test-local-role [role=option]", "Administrator")
    refute has_element?(view, "#layout-test-local-role [role=option]", "Scalar")

    assert has_element?(
             view,
             "#layout-test-local-role select[name='local[role]'] option[value=viewer][selected]"
           )

    assert has_element?(view, "#layout-test-local-role [data-pc-combo-trigger-label]", "Viewer")
  end

  test "upload previews become read-only and finished uploads consume entries", %{
    conn: conn
  } do
    {:ok, view, _html} = live(conn, ~p"/dashboard/dev_panel/design_standards")

    upload =
      file_input(view, "#layout-test-upload-form", :demo_files, [
        %{
          name: "notes.txt",
          content: "Template upload example",
          type: "text/plain",
          last_modified: 1_786_060_800_000
        }
      ])

    render_upload(upload, "notes.txt")
    assert Floki.find(preview_document(view), "button[phx-click=cancel_upload]") != []
    assert Floki.find(preview_document(view), "button[phx-click=remove_upload]") != []

    render_click(element(view, "#upload-mode-text-disabled"))
    assert has_element?(view, "#layout-test-upload-input label.hidden input[type=file][disabled]")

    assert Floki.find(preview_document(view), "button[phx-click=cancel_upload]") == []
    assert Floki.find(preview_document(view), "button[phx-click=remove_upload]") == []

    render_click(element(view, "#upload-mode-enabled"))
    render_submit(form(view, "#layout-test-upload-form"))
    assert has_element?(view, "#uploaded-names", "notes.txt")
    assert Floki.find(preview_document(view), "button[phx-click=cancel_upload]") == []
  end

  test "dialog cancellation and calendar navigation update the showcase", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/dashboard/dev_panel/design_standards")
    render_click(element(view, "#layout-test-dialog-open"))
    assert has_element?(view, "#layout-test-modal [role=dialog]")
    render_click(element(view, "#dialog-cancel"))
    refute has_element?(view, "#layout-test-modal")

    render_hook(view, "calendar_change", %{"view" => "month", "date" => "2026-10-09"})
    render_hook(view, "calendar_change", %{"event" => "planning"})
    assert has_element?(view, "#calendar-selection", "planning")
    assert has_element?(view, "#demo-elapsed-timer[phx-hook=LiveTimer]")
  end

  test "local datetime submission retains UTC and displays the resolved timezone", %{conn: conn} do
    conn = put_connect_params(conn, %{"user_timezone" => "America/New_York"})
    {:ok, view, _html} = live(conn, ~p"/dashboard/dev_panel/design_standards")

    assert has_element?(view, "#local_launch_at[data-vc-timezone='America/New_York']")

    view
    |> form("#layout-test-form", local: %{launch_at: "2026-04-23T09:30"})
    |> render_submit()

    assert has_element?(
             view,
             "#submitted-at[datetime='2026-04-23T13:30:00Z']",
             "23 Apr 2026, 09:30 EDT"
           )

    assert has_element?(view, "#submitted-at-utc", "2026-04-23T13:30:00Z")
    assert has_element?(view, "#local_launch_at[data-vc-value='2026-04-23T09:30']")
  end

  test "local datetime submission rejects DST gaps and repeated clocks without losing edits", %{
    conn: conn
  } do
    conn = put_connect_params(conn, %{"user_timezone" => "America/New_York"})
    {:ok, view, _html} = live(conn, ~p"/dashboard/dev_panel/design_standards")

    for {value, message} <- [
          {"2026-03-08T02:30", "This local time does not exist."},
          {"2026-11-01T01:30", "This local time occurs twice."},
          {"not a datetime", "Enter a valid date and time."}
        ] do
      html =
        view
        |> form("#layout-test-form", local: %{launch_at: value})
        |> render_submit()

      assert html =~ message
      assert has_element?(view, "#local_launch_at[data-vc-value='#{value}']")
      refute has_element?(view, "#submitted-at")
    end
  end

  test "forged local submission without the required datetime receives a field error", %{
    conn: conn
  } do
    {:ok, view, _html} = live(conn, ~p"/dashboard/dev_panel/design_standards")
    html = render_submit(view, "local_save", %{"local" => %{"project_name" => "Planning"}})
    assert html =~ "Enter a valid date and time."
    refute has_element?(view, "#submitted-at")
  end

  defp preview_document(view) do
    view
    |> element("#layout-test-upload-input template[data-phx-portal]")
    |> render()
    |> Floki.parse_document!()
  end
end

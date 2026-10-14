defmodule ElixirbitsWeb.Admin.LayoutTestInputMatrixTest do
  use ElixirbitsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias ElixirbitsWeb.CoreComponents

  test "native file specimens keep preview and editing off for single and multiple selections", %{
    conn: conn
  } do
    {:ok, view, _html} = live(conn, ~p"/dev_panel/layout_test")

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

  test "one specimen per supported type exposes the complete finite option vocabulary", %{
    conn: conn
  } do
    {:ok, _view, html} = live(conn, ~p"/dev_panel/layout_test")
    document = Floki.parse_document!(html)
    attributes = CoreComponents.__components__().input.attrs
    types = Enum.find(attributes, &(&1.name == :type)).opts[:values]

    specimens = Floki.find(document, "#layout-test-input-examples [data-input-type]")
    assert length(specimens) == length(types)
    assert Enum.sort(Floki.attribute(specimens, "data-input-type")) == Enum.sort(types)

    for {attribute, option} <- [
          {:render_as, "render_as"},
          {:variant, "variant"},
          {:mode, "select_mode"}
        ] do
      values = Enum.find(attributes, &(&1.name == attribute)).opts[:values]

      controls =
        Floki.find(document, "#layout-test-input-controls button[phx-value-option='#{option}']")

      assert Enum.sort(Floki.attribute(controls, "phx-value-choice")) ==
               Enum.sort(Enum.map(values, &to_string/1))
    end

    assert Floki.attribute(
             document,
             "#layout-test-input-controls button[phx-value-option=checked]",
             "phx-value-choice"
           ) == ["false", "true"]
  end

  test "changing display modes keeps the same specimens and applies their submission semantics",
       %{conn: conn} do
    {:ok, view, html} = live(conn, ~p"/dev_panel/layout_test")
    specimen_ids = Floki.attribute(Floki.parse_document!(html), "[data-input-type]", "id")
    attributes = CoreComponents.__components__().input.attrs
    modes = Enum.find(attributes, &(&1.name == :render_as)).opts[:values]

    for mode <- modes do
      document =
        view
        |> element("#layout-test-input-render-#{mode}")
        |> render_click()
        |> Floki.parse_document!()

      assert Floki.attribute(document, "[data-input-type]", "id") == specimen_ids

      assert Enum.uniq(Floki.attribute(document, "[data-input-type]", "data-input-mode")) == [
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

  test "checkbox and switch variants and checked states change the actual controls", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/dev_panel/layout_test")

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
    {:ok, view, _html} = live(conn, ~p"/dev_panel/layout_test")

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
    {:ok, view, _html} = live(conn, ~p"/dev_panel/layout_test")

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
    {:ok, view, _html} = live(conn, ~p"/dev_panel/layout_test")

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
    {:ok, view, _html} = live(conn, ~p"/dev_panel/layout_test")

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
             "#layout-test-local-role input[type=text][placeholder='Choose a role']"
           )

    refute has_element?(view, "#layout-test-input-example-select .input-floating-label")
    refute has_element?(view, "#local_enabled[readonly]")

    render_click(element(view, "#layout-test-input-state-capture"))
    assert has_element?(view, "#local_upload[multiple][accept='image/*,.pdf']:not([capture])")
  end

  test "empty values remain editable and restore the earlier populated fields", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/dev_panel/layout_test")

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

  test "select modes preserve selected roles and keep the matching form field names", %{
    conn: conn
  } do
    {:ok, view, _html} = live(conn, ~p"/dev_panel/layout_test")

    assert has_element?(
             view,
             "#layout-test-local-role input[type=hidden][name='local[role]'][value=admin]"
           )

    for mode <- ~w(tags quick_tags) do
      render_click(element(view, "#layout-test-input-select-mode-#{mode}"))

      assert has_element?(
               view,
               "#layout-test-local-role input[type=hidden][name='local[role][]'][value=admin]"
             )

      render_focus(element(view, "#layout-test-local-role input[type=text]"))

      render_hook(view, "live_select_change", %{
        "id" => "layout-test-local-role",
        "text" => "Viewer"
      })

      assert has_element?(view, "#layout-test-local-role li", "Viewer")
      refute has_element?(view, "#layout-test-local-role li", "Designer")
    end

    render_change(view, "local_change", %{"local" => %{"role" => ["designer", "viewer"]}})
    render_click(element(view, "#layout-test-input-select-mode-single"))

    assert has_element?(
             view,
             "#layout-test-local-role input[type=hidden][name='local[role]'][value=designer]"
           )

    refute has_element?(view, "#layout-test-local-role input[name='local[role][]']")
  end

  test "disabled forms handle omitted fields on change and submission without losing retained values",
       %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/dev_panel/layout_test")

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

  test "clearing the final role tag discards merged values on change and submission", %{
    conn: conn
  } do
    {:ok, view, _html} = live(conn, ~p"/dev_panel/layout_test")

    for {mode, event} <- [{"tags", "local_change"}, {"quick_tags", "local_save"}] do
      render_click(element(view, "#layout-test-input-select-mode-#{mode}"))
      render_change(view, "local_change", %{"local" => %{"role" => ["admin"]}})

      assert has_element?(
               view,
               "#layout-test-local-role input[name='local[role][]'][value=admin]"
             )

      params = %{"local" => %{"role_empty_selection" => "", "launch_at" => "2026-10-10T09:30"}}

      if event == "local_change" do
        render_change(view, event, params)
      else
        render_submit(view, event, params)
      end

      assert has_element?(view, "#layout-test-local-role input[data-live-select-empty]")
      refute has_element?(view, "#layout-test-local-role input[name='local[role][]']")
    end

    assert has_element?(view, "#submitted-at")
  end

  test "submission shows validation errors after earlier unused field metadata", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/dev_panel/layout_test")

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

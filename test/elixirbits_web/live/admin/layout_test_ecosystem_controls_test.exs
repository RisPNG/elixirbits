defmodule ElixirbitsWeb.Admin.LayoutTestLive.EcosystemControlsTest do
  use ElixirbitsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "core combobox preserves single and multiple dependency selections", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/dev_panel/layout_test")

    assert has_element?(
             view,
             "#layout-test-form-section #layout-test-dependency-combobox[phx-hook=PetalComboBox]"
           )

    render_change(view, "dependency_change", %{
      "dependency" => %{"component_search" => "/api/json/scalar"}
    })

    assert has_element?(view, "#selected-dependency-scalar")

    render_click(element(view, "#dependency-select-mode-multiple"))

    assert has_element?(
             view,
             "#layout-test-dependency-combobox select[multiple][name='dependency[component_search][]'] option[value='/api/json/scalar'][selected]"
           )

    render_change(view, "dependency_change", %{
      "dependency" => %{"component_search" => ["/api/json/scalar", "/dev/dashboard"]}
    })

    assert has_element?(view, "#selected-dependency-scalar")
    assert has_element?(view, "#selected-dependency-dashboard")

    render_click(element(view, "#dependency-select-mode-single"))
    assert has_element?(view, "#selected-dependency-scalar")
    refute has_element?(view, "#selected-dependency-dashboard")

    render_click(element(view, "#dependency-select-mode-multiple"))

    render_change(view, "dependency_change", %{
      "_target" => ["dependency", "component_search"],
      "dependency" => %{"component_search" => [""]}
    })

    refute has_element?(view, "#selected-dependency-scalar")
    assert has_element?(view, "#layout-test-selected-dependency", "Pick a dependency page")
  end

  test "core combobox display and disabled controls keep the selected preview", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/dev_panel/layout_test")

    assert has_element?(
             view,
             "#layout-test-dependency-combobox input[placeholder='Search dependency pages']"
           )

    render_click(element(view, "#dependency-select-option-prompt"))

    refute has_element?(
             view,
             "#layout-test-dependency-combobox input[placeholder='Search dependency pages']"
           )

    render_click(element(view, "#dependency-select-option-clearable"))
    assert has_element?(view, "#dependency-select-option-clearable[aria-pressed=false]")
    refute has_element?(view, "#layout-test-dependency-combobox [data-pc-combo-clear]")

    render_change(view, "dependency_change", %{
      "dependency" => %{"component_search" => "/api/json/scalar"}
    })

    for render_as <-
          ~w(enabled disabled like-enabled like-disabled hidden hidden-enabled hidden-disabled text text-enabled text-disabled) do
      render_click(element(view, "#dependency-select-render-#{render_as}"))
      assert has_element?(view, "#dependency-select-render-#{render_as}[aria-pressed=true]")
      assert has_element?(view, "#selected-dependency-scalar")
    end

    render_click(element(view, "#dependency-select-render-enabled"))
    render_click(element(view, "#dependency-select-option-disabled"))
    assert has_element?(view, "#layout-test-dependency-form input[type=text][disabled]")
    assert has_element?(view, "#selected-dependency-scalar")
    render_click(element(view, "#dependency-select-option-disabled"))

    assert has_element?(
             view,
             "#layout-test-dependency-combobox select option[value='/api/json/scalar'][selected]"
           )
  end

  test "UI kit controls update one preview for each primitive", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/dev_panel/layout_test")
    render_click(element(view, "#layout-test-ecosystem-tab"))

    for kind <- ~w(info success warning error) do
      render_click(element(view, "#ui-kit-alert-#{kind}"))
      assert has_element?(view, "#ui-kit-alert-preview[data-kind=#{kind}]")
    end

    for style <- ~w(brand outline success warning) do
      render_click(element(view, "#ui-kit-badge-#{style}"))
      assert has_element?(view, "#ui-kit-badge-preview[data-style=#{style}]")
    end

    render_change(form(view, "#ui-kit-progress-form", showcase: %{progress: "35"}))
    assert has_element?(view, "#ui-kit-progress-preview[aria-valuenow='35']")
    assert has_element?(view, "#ui-kit-progress-preview > div[style='width: 35%']")

    render_click(element(view, "#ui-kit-step-3"))
    assert has_element?(view, "#ui-kit-steps-preview li[aria-current=step]", "Routes")
    render_click(element(view, "#ui-kit-step-1"))
    assert has_element?(view, "#ui-kit-steps-preview li[aria-current=step]", "Tokens")

    render_click(element(view, "#ui-kit-option-menu"))
    refute has_element?(view, "#ui-kit-menu-preview")
    render_click(element(view, "#ui-kit-option-menu"))
    assert has_element?(view, "#ui-kit-menu-preview a[href='/api/json/scalar']")
  end

  test "dependency page selection keeps every route reachable from one preview", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/dev_panel/layout_test")
    render_click(element(view, "#layout-test-ecosystem-tab"))

    pages = [
      {"scalar", "/api/json/scalar"},
      {"dashboard", "/dev/dashboard"},
      {"mailbox", "/dev/mailbox"},
      {"ash-admin", "/admin"}
    ]

    for {id, path} <- pages do
      render_click(element(view, "#dependency-page-choice-#{id}"))
      assert has_element?(view, "#dependency-page-#{id} a[href='#{path}']")

      for {other_id, _path} <- pages, other_id != id do
        refute has_element?(view, "#dependency-page-#{other_id}")
      end
    end
  end
end

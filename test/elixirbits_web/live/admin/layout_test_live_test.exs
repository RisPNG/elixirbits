defmodule ElixirbitsWeb.Admin.LayoutTestLiveTest do
  use ElixirbitsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Elixirbits.AccessControl
  alias Elixirbits.AccessControl.Sitenav

  test "renders local tab by default and switches to ecosystem tab", %{conn: conn} do
    Ash.create!(
      Sitenav,
      %{
        code: "LT",
        name: "Layout Test",
        description: "Showcases most, if not all front-end components.",
        level: 2,
        parent: "DP",
        url: "dev_panel/layout_test",
        sequence: 3000,
        state: :ENABLED
      },
      action: :create,
      domain: AccessControl
    )

    {:ok, view, _html} = live(conn, ~p"/dev_panel/layout_test")

    assert has_element?(view, "#layout-test-local-tab[aria-selected=\"true\"]")
    assert has_element?(view, "#layout-test-local-panel")
    assert has_element?(view, "#layout-test-core-table")
    assert has_element?(view, "#local_project_name.input-floating-control[placeholder=\" \"]")
    assert has_element?(view, "label[for=\"local_project_name\"] .input-floating-label")
    refute has_element?(view, "#layout-test-ecosystem-panel")

    render_click(element(view, "#layout-test-ecosystem-tab"))

    assert has_element?(view, "#layout-test-ecosystem-tab[aria-selected=\"true\"]")
    assert has_element?(view, "#layout-test-ecosystem-panel")
    assert has_element?(view, "#layout-test-dependency-form")
    assert has_element?(view, "#layout-test-ash-sign-in-card")
    assert has_element?(view, "#layout-test-cinder-table")
    refute has_element?(view, "#layout-test-local-panel")
  end

  test "flash buttons trigger layout flash output", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/dev_panel/layout_test")

    render_click(element(view, "#layout-test-flash-info"))
    assert has_element?(view, "#flash-info")

    render_click(element(view, "#layout-test-flash-error"))
    assert has_element?(view, "#flash-error")
  end
end

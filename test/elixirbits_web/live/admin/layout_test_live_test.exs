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

    assert has_element?(
             view,
             "#local_accent.input-floating-control[type=\"color\"][placeholder=\" \"]"
           )

    assert has_element?(view, "#local_notes.input-floating-textarea[placeholder=\" \"]")
    assert has_element?(view, "label[for=\"local_project_name\"] .input-floating-label")
    assert has_element?(view, "label[for=\"local_accent\"] .input-floating-label")
    assert has_element?(view, "#local_phone_tel_wrapper .input-floating-wrapper.gap-0")
    assert has_element?(view, "label[for=\"local_notes\"] .input-floating-label")
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

    assert has_element?(
             view,
             "#flash-info[phx-hook=\"FlashAutoDismiss\"][data-duration=\"5000\"]"
           )

    render_click(element(view, "#layout-test-flash-error"))
    assert has_element?(view, "#flash-error")

    render_click(element(view, "#layout-test-flash-warning"))
    assert has_element?(view, "#flash-warning")

    assert has_element?(
             view,
             "#flash-warning[phx-hook=\"FlashAutoDismiss\"][data-duration=\"8000\"]"
           )
  end

  test "flash accepts structured payloads and prefixed group ids" do
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

  test "dependency LiveSelect refreshes backend options after selection", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/dev_panel/layout_test")

    render_click(element(view, "#layout-test-ecosystem-tab"))

    assert has_element?(view, "#layout-test-dependency-live-select")

    render_focus(element(view, "#layout-test-dependency-live-select input[type=\"text\"]"))

    render_hook(view, "live_select_change", %{
      "id" => "layout-test-dependency-live-select",
      "text" => "dashboard"
    })

    assert has_element?(view, "#layout-test-dependency-live-select ul li div[data-idx=\"0\"]")

    render_hook(element(view, "#layout-test-dependency-live-select"), "option_click", %{
      "idx" => "0"
    })

    refute has_element?(view, "#layout-test-dependency-live-select ul")

    render_focus(element(view, "#layout-test-dependency-live-select input[type=\"text\"]"))

    render_hook(view, "live_select_change", %{
      "id" => "layout-test-dependency-live-select",
      "text" => ""
    })

    assert has_element?(view, "#layout-test-dependency-live-select ul li div[data-idx=\"0\"]")
  end
end

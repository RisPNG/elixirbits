defmodule ElixirbitsWeb.Admin.LayoutTestLocalControlsTest do
  use ElixirbitsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "header options configure one preview and its action remains usable", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/dev_panel/layout_test")

    assert has_element?(view, "#layout-test-header-card summary", "Button style: default")

    for choice <- ~w(default text neutral primary danger) do
      render_click(
        element(
          view,
          "#layout-test-header-card button[phx-value-option=variant][phx-value-choice=#{choice}]"
        )
      )

      assert has_element?(view, "#layout-test-header-card summary", "Button style: #{choice}")

      assert has_element?(
               view,
               "#layout-test-header-card button[phx-value-choice=#{choice}][aria-pressed=true]"
             )

      assert has_element?(view, "button#layout-test-inline-action[phx-click=show_flash]")
      render_click(element(view, "#layout-test-inline-action"))
      assert has_element?(view, "#flash-info")

      if choice == "text" do
        render_click(view, "toggle_showcase_option", %{
          "section" => "header",
          "option" => "navigation"
        })

        assert has_element?(view, "a#layout-test-inline-action[href='/']", "Home")

        render_click(view, "toggle_showcase_option", %{
          "section" => "header",
          "option" => "navigation"
        })
      end
    end

    assert has_element?(view, "#layout-test-inline-action.button-danger")

    render_click(view, "toggle_showcase_option", %{"section" => "header", "option" => "disabled"})
    assert has_element?(view, "#layout-test-inline-action[disabled]")
    render_click(view, "toggle_showcase_option", %{"section" => "header", "option" => "subtitle"})
    refute has_element?(view, "#layout-test-header-preview", "An example subtitle")
    render_click(view, "toggle_showcase_option", %{"section" => "header", "option" => "actions"})
    refute has_element?(view, "#layout-test-inline-action")
  end

  test "flash configuration reaches the shared renderer", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/dev_panel/layout_test")
    render_click(element(view, "#layout-test-flash-kind-warning"))

    for option <- ~w(title icon spinner) do
      render_click(view, "toggle_showcase_option", %{"section" => "flash", "option" => option})
    end

    render_click(view, "set_showcase_option", %{
      "section" => "flash",
      "option" => "duration",
      "choice" => "1000"
    })

    render_click(element(view, "#layout-test-flash-show"))
    assert has_element?(view, "#flash-warning[data-duration='1000']", "Example notification")
    assert has_element?(view, "#flash-warning .hero-bell")
    assert has_element?(view, "#flash-warning .hero-arrow-path")
  end

  test "table and list options alter one preview while inspection works", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/dev_panel/layout_test")
    render_click(element(view, "#layout-test-core-table tr:first-child button"))
    assert has_element?(view, "#table-selection", "Header")
    render_click(element(view, "#table-option-actions"))
    refute has_element?(view, "#layout-test-core-table button")
    render_click(element(view, "#table-option-clickable"))
    render_click(element(view, "#layout-test-core-table tr:nth-child(2) td:first-child"))
    assert has_element?(view, "#table-selection", "Inputs")
    render_click(element(view, "#table-option-empty"))
    refute has_element?(view, "#layout-test-core-table tr")
    render_click(element(view, "#table-option-empty"))
    assert has_element?(view, "#layout-test-core-table tr:nth-child(3)")

    render_click(element(view, "#list-count-1"))
    assert has_element?(view, "#layout-test-list-preview li", "Surface")
    refute has_element?(view, "#layout-test-list-preview", "Global toast stack")
    render_click(element(view, "#list-option-titles"))
    refute has_element?(view, "#layout-test-list-preview", "Surface")
    assert has_element?(view, "#layout-test-list-preview", "Local core components")
  end

  test "icon and theme options configure a single preview", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/dev_panel/layout_test")
    render_click(element(view, "#icon-name-tabler-device-floppy"))
    render_click(element(view, "#icon-size-12"))
    render_click(element(view, "#icon-color-success"))

    assert has_element?(
             view,
             "#layout-test-icon-preview .tabler-device-floppy.size-12.text-success"
           )

    render_click(element(view, "#icon-option-label"))
    refute has_element?(view, "#layout-test-icon-preview", "tabler-device-floppy")
    render_click(view, "toggle_showcase_option", %{"section" => "theme", "option" => "inset"})
    refute has_element?(view, "#layout-test-theme-preview.border")
  end

  test "calendar, timer, and dialog options retain their interactions", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/dev_panel/layout_test")
    render_click(view, "toggle_showcase_option", %{"section" => "calendar", "option" => "events"})
    refute has_element?(view, "#calendar-showcase button[phx-value-event=planning]")
    render_click(view, "toggle_showcase_option", %{"section" => "calendar", "option" => "events"})
    assert has_element?(view, "#calendar-showcase button[phx-value-event=planning]")
    render_click(element(view, "#timer-mode-countdown"))
    assert has_element?(view, "#demo-countdown-timer[data-mode=countdown]")
    refute has_element?(view, "#demo-elapsed-timer")
    render_click(element(view, "#timer-reset"))
    render_click(element(view, "#timer-mode-elapsed"))
    assert has_element?(view, "#demo-elapsed-timer[data-mode=elapsed]")

    render_click(element(view, "#dialog-option-title"))
    render_click(element(view, "#dialog-option-actions"))
    render_click(element(view, "#layout-test-dialog-open"))
    assert has_element?(view, "#layout-test-modal [role=dialog]")
    refute has_element?(view, "#layout-test-modal", "Example dialog")
    refute has_element?(view, "#dialog-confirm")
    render_click(view, "hide_modal")
    refute has_element?(view, "#layout-test-modal")
  end
end

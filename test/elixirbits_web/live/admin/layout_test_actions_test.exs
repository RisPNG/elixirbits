defmodule ElixirbitsWeb.Admin.LayoutTestLive.ActionsTest do
  use ElixirbitsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "entry panels add, select, edit, save, and restore the saved state", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/dev_panel/layout_test")

    assert has_element?(view, "#record-entry-panels.grid")
    assert has_element?(view, "#record-entry-2")
    refute has_element?(view, "#record-entry-4")
    render_click(element(view, "#record-option-count-4"))
    assert has_element?(view, "#record-entry-4")
    render_click(element(view, "#record-option-columns-1"))
    refute has_element?(view, "#record-entry-panels.grid")
    render_click(element(view, "#record-option-columns-2"))
    assert has_element?(view, "#record-entry-panels.grid")

    render_click(element(view, "#record-action-create"))
    assert has_element?(view, "#record-name-5[value='New entry']")
    assert has_element?(view, "#record-action-status", "Added entry #5")

    render_change(
      form(view, "#layout-test-record-form", records: %{"5" => %{name: "Saved entry"}})
    )

    render_click(element(view, "#record-option-selected-save"))
    render_click(element(view, "#record-action-save"))

    render_change(
      form(view, "#layout-test-record-form", records: %{"5" => %{name: "Unsaved edit"}})
    )

    render_click(element(view, "#record-option-selected-back"))
    render_click(element(view, "#record-action-back"))
    render_click(element(view, "#record-select-5"))
    assert has_element?(view, "#record-entry-5", "Saved entry")
    refute has_element?(view, "#record-entry-5", "Unsaved edit")

    render_click(element(view, "#record-read-5"))
    assert has_element?(view, "#record-action-status", "Viewing entry #5")
    render_click(element(view, "#record-option-selected-update"))
    render_click(element(view, "#record-action-update"))
    assert has_element?(view, "#record-name-5[value='Saved entry']")

    render_submit(
      form(view, "#layout-test-record-form", records: %{"5" => %{name: "Submitted entry"}})
    )

    render_click(element(view, "#record-option-selected-back"))
    render_click(element(view, "#record-action-back"))
    render_click(element(view, "#record-select-5"))
    assert has_element?(view, "#record-entry-5", "Submitted entry")
  end

  test "record actions change the selected entry and support an empty collection", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/dev_panel/layout_test")
    render_click(element(view, "#record-option-count-4"))
    render_click(element(view, "#record-read-2"))
    render_click(element(view, "#record-option-selected-send"))
    render_click(element(view, "#record-action-send"))
    assert has_element?(view, "#record-entry-2[data-status='Sent']")
    assert has_element?(view, "#record-entry-1[data-status='Draft']")
    render_click(element(view, "#record-option-selected-archive"))
    render_click(element(view, "#record-action-archive"))
    assert has_element?(view, "#record-entry-2[data-status='Archived']")
    render_click(element(view, "#record-option-selected-delete"))
    render_click(element(view, "#record-action-delete"))
    refute has_element?(view, "#record-entry-2")

    for id <- ["1", "3", "4"] do
      render_click(element(view, "#record-delete-#{id}"))
    end

    assert has_element?(view, "#record-empty")
    assert has_element?(view, "#record-action-delete[disabled]")
    render_click(element(view, "#record-option-selected-read"))
    assert has_element?(view, "#record-action-read[disabled]")
    render_click(element(view, "#record-option-selected-create"))
    render_click(element(view, "#record-action-create"))
    assert has_element?(view, "#record-entry-5")
    render_click(element(view, "#record-option-selected-back"))
    render_click(element(view, "#record-action-back"))
    assert has_element?(view, "#record-entry-2[data-status='Draft']")
    refute has_element?(view, "#record-entry-5")
  end

  test "one action preview exposes every action and its state controls", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/dev_panel/layout_test")

    for action <- ~w(create read update save send archive delete back) do
      render_click(element(view, "#record-option-selected-#{action}"))
      assert has_element?(view, "#record-action-#{action}[phx-value-action=#{action}]")

      assert view
             |> render()
             |> Floki.parse_document!()
             |> Floki.find("#layout-test-actions button[id^=record-action-]")
             |> length() == 1
    end

    assert has_element?(view, "#record-action-back[data-tooltip='Back']")
    render_click(element(view, "#showcase-actions-custom_icon"))
    assert has_element?(view, "#record-action-back .tabler-calendar-plus")
    render_click(element(view, "#showcase-actions-tooltip"))
    assert has_element?(view, "#record-action-back[aria-label=Back]")

    refute has_element?(
             view,
             "#record-action-back[data-tooltip]:not([data-tooltip=''])"
           )

    render_click(element(view, "#showcase-actions-disabled"))
    assert has_element?(view, "#record-action-back[disabled]")
    render_click(element(view, "#showcase-actions-disabled"))
    refute has_element?(view, "#record-action-back[disabled]")
  end

  test "entry count and render controls retain edits and keep any selected entry visible", %{
    conn: conn
  } do
    {:ok, view, _html} = live(conn, ~p"/dev_panel/layout_test")

    assert has_element?(view, "#record-select-4")
    refute has_element?(view, "#record-entry-4")
    render_click(element(view, "#record-select-4"))
    assert has_element?(view, "#record-entry-4")
    refute has_element?(view, "#record-entry-2")
    render_click(element(view, "#record-option-selected-update"))
    render_click(element(view, "#record-action-update"))
    render_change(form(view, "#layout-test-record-form", records: %{"4" => %{name: "Kept edit"}}))

    render_click(element(view, "#record-option-count-1"))
    assert has_element?(view, "#record-name-4[value='Kept edit']")
    refute has_element?(view, "#record-entry-1")
    render_click(element(view, "#record-option-count-4"))
    assert has_element?(view, "#record-entry-1")
    assert has_element?(view, "#record-name-4[value='Kept edit']")

    for mode <-
          ~w(enabled disabled like-enabled like-disabled hidden hidden-enabled hidden-disabled text text-enabled text-disabled) do
      render_click(element(view, "#record-option-render_as-#{mode}"))
      assert has_element?(view, "#record-option-render_as-#{mode}[aria-pressed=true]")
    end

    render_click(element(view, "#record-option-render_as-enabled"))
    assert has_element?(view, "#record-name-4[value='Kept edit']")
  end

  test "calendar starts in month view and keeps view changes interactive", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/dev_panel/layout_test")

    assert has_element?(
             view,
             "#calendar-showcase button[aria-pressed=true][phx-value-view=month]"
           )

    render_click(
      element(view, "#calendar-showcase button[phx-value-view=week][aria-pressed=false]")
    )

    assert has_element?(view, "#calendar-showcase button[aria-pressed=true][phx-value-view=week]")
  end
end

defmodule ElixirbitsWeb.Admin.LayoutTestCinderTest do
  use ElixirbitsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "all Cinder layouts paginate across twenty pages of sample records", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/dev_panel/layout_test")
    render_click(element(view, "#layout-test-ecosystem-tab"))

    for layout <- ~w(table list grid) do
      render_click(element(view, "#cinder-layout-#{layout}"))
      selector = "#layout-test-cinder-collection"

      assert has_element?(view, "#{selector}[data-layout=#{layout}]")

      assert has_element?(view, "#{selector} [data-key=pagination_info_class]", "Page 1 of 20")
      assert has_element?(view, selector, "EX001")
      assert has_element?(view, selector, "EX006")
      refute has_element?(view, selector, "EX007")

      render_click(element(view, "#{selector} button[phx-click=goto_page][phx-value-page='20']"))

      assert has_element?(view, "#{selector} [data-key=pagination_info_class]", "Page 20 of 20")
      assert has_element?(view, selector, "EX115")
      assert has_element?(view, selector, "EX120")
      refute has_element?(view, selector, "EX001")
      refute has_element?(view, "#{selector} button[title='Next page']")
    end
  end

  test "search resets pagination and clearing it restores all sample pages", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/dev_panel/layout_test")
    render_click(element(view, "#layout-test-ecosystem-tab"))

    for layout <- ~w(table list grid) do
      render_click(element(view, "#cinder-layout-#{layout}"))
      selector = "#layout-test-cinder-collection"
      filter_form = "#{selector} form[phx-change=filter_change]"

      render_click(element(view, "#{selector} button[phx-click=goto_page][phx-value-page='20']"))
      render_change(form(view, filter_form, search: "Core inputs"))

      assert has_element?(view, "#{selector} [data-key=pagination_info_class]", "Page 1 of 2")
      assert has_element?(view, selector, "EX001")
      refute has_element?(view, selector, "EX002")

      render_click(
        element(
          view,
          "#{selector} button[phx-click=goto_page][phx-value-page='2'][title='Go to page 2']"
        )
      )

      assert has_element?(view, selector, "EX109")

      render_change(form(view, filter_form, search: ""))
      assert has_element?(view, "#{selector} [data-key=pagination_info_class]", "Page 1 of 20")
      assert has_element?(view, selector, "EX002")
    end
  end

  test "native filters and sorting apply to the sample records", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/dev_panel/layout_test")
    render_click(element(view, "#layout-test-ecosystem-tab"))
    render_click(element(view, "#cinder-layout-list"))

    selector = "#layout-test-cinder-collection"
    filter_form = "#{selector} form[phx-change=filter_change]"

    render_change(form(view, filter_form, filters: %{state: "DISABLED"}))
    assert has_element?(view, "#{selector} [data-key=pagination_info_class]", "Page 1 of 5")
    assert has_element?(view, selector, "EX004")
    refute has_element?(view, selector, "EX001")

    render_click(element(view, "#cinder-layout-table"))
    render_click(element(view, "#{selector} button[phx-click=goto_page][phx-value-page='20']"))
    render_click(element(view, "#{selector} [phx-click=toggle_sort][phx-value-key=sequence]"))

    assert has_element?(view, "#{selector} [data-key=pagination_info_class]", "Page 1 of 20")
    assert has_element?(view, selector, "EX120")
    assert has_element?(view, selector, "EX115")
    refute has_element?(view, selector, "EX001")
  end

  test "collection controls change page size and hide only the chosen controls", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/dev_panel/layout_test")
    render_click(element(view, "#layout-test-ecosystem-tab"))
    selector = "#layout-test-cinder-collection"

    render_click(element(view, "#cinder-page-size-12"))
    assert has_element?(view, "#{selector} [data-key=pagination_info_class]", "Page 1 of 10")
    assert has_element?(view, selector, "EX012")
    refute has_element?(view, selector, "EX013")

    render_click(element(view, "#cinder-page-size-24"))
    assert has_element?(view, "#{selector} [data-key=pagination_info_class]", "Page 1 of 5")

    render_click(element(view, "#cinder-option-filters"))
    refute has_element?(view, "#{selector} input[name='filters[code]']")
    assert has_element?(view, "#{selector} input[name=search]")
    render_click(element(view, "#cinder-option-search"))
    refute has_element?(view, "#{selector} form[phx-change=filter_change]")
    render_click(element(view, "#cinder-option-sort"))
    refute has_element?(view, "#{selector} [phx-click=toggle_sort]")
    render_click(element(view, "#cinder-option-pagination"))
    refute has_element?(view, "#{selector} [data-key=pagination_info_class]")
    assert has_element?(view, selector, "EX024")
  end

  test "grid column controls keep the current page and rows", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/dev_panel/layout_test")
    render_click(element(view, "#layout-test-ecosystem-tab"))
    render_click(element(view, "#cinder-layout-grid"))
    selector = "#layout-test-cinder-collection"

    render_click(element(view, "#{selector} button[phx-click=goto_page][phx-value-page='20']"))

    for {columns, grid} <- [
          {"2", "grid-cols-[1fr_1fr]"},
          {"3", "grid-cols-[1fr_1fr_1fr]"},
          {"4", "grid-cols-[1fr_1fr_1fr_1fr]"}
        ] do
      render_click(element(view, "#cinder-columns-#{columns}"))
      assert has_element?(view, "#{selector} [data-key=grid_container_class][class*='#{grid}']")
      assert has_element?(view, "#{selector} [data-key=pagination_info_class]", "Page 20 of 20")
      assert has_element?(view, selector, "EX120")
    end
  end

  test "sample identities remain stable across resource reads" do
    resource = ElixirbitsWeb.Admin.LayoutTestLive.CinderEntry
    query = Ash.Query.for_read(resource, :read)
    first = Ash.read!(query)
    second = Ash.read!(query)

    assert Enum.map(first, &{&1.code, &1.id}) == Enum.map(second, &{&1.code, &1.id})
    assert Enum.all?(first, &match?({:ok, _}, Ash.Type.UUIDv7.cast_input(&1.id, [])))
  end
end

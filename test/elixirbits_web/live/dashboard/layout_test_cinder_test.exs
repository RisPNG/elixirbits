defmodule ElixirbitsWeb.Dashboard.LayoutTestCinderTest do
  use ElixirbitsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "all Cinder layouts default to ten records per page", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/dashboard/dev_panel/layout_test")
    render_click(element(view, "#layout-test-ecosystem-tab"))

    for layout <- ~w(table list grid) do
      render_click(element(view, "#cinder-layout-#{layout}"))
      selector = "#layout-test-cinder-collection"

      assert has_element?(view, "#{selector}[data-layout=#{layout}]")

      assert has_element?(view, "#{selector} [data-key=pagination_info_class]", "Page 1 of 12")
      assert has_element?(view, selector, "EX001")
      assert has_element?(view, selector, "EX010")
      refute has_element?(view, selector, "EX011")

      render_click(element(view, "#{selector} button[phx-click=goto_page][phx-value-page='12']"))

      assert has_element?(view, "#{selector} [data-key=pagination_info_class]", "Page 12 of 12")
      assert has_element?(view, selector, "EX111")
      assert has_element?(view, selector, "EX120")
      refute has_element?(view, selector, "EX001")
      refute has_element?(view, "#{selector} button[title='Next page']")
    end
  end

  test "search resets pagination and clearing it restores all sample pages", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/dashboard/dev_panel/layout_test")
    render_click(element(view, "#layout-test-ecosystem-tab"))

    for layout <- ~w(table list grid) do
      render_click(element(view, "#cinder-layout-#{layout}"))
      selector = "#layout-test-cinder-collection"
      filter_form = "#{selector} form[phx-change=filter_change]"

      render_click(element(view, "#{selector} button[phx-click=goto_page][phx-value-page='12']"))
      render_change(form(view, filter_form, search: "Core inputs"))

      refute has_element?(view, "#{selector} [data-key=pagination_info_class]")
      assert has_element?(view, selector, "EX001")
      assert has_element?(view, selector, "EX109")
      refute has_element?(view, selector, "EX002")

      render_change(form(view, filter_form, search: ""))
      assert has_element?(view, "#{selector} [data-key=pagination_info_class]", "Page 1 of 12")
      assert has_element?(view, selector, "EX002")
    end
  end

  test "native filters and sorting apply to the sample records", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/dashboard/dev_panel/layout_test")
    render_click(element(view, "#layout-test-ecosystem-tab"))
    render_click(element(view, "#cinder-layout-list"))

    selector = "#layout-test-cinder-collection"
    filter_form = "#{selector} form[phx-change=filter_change]"

    render_change(form(view, filter_form, filters: %{state: "DISABLED"}))
    assert has_element?(view, "#{selector} [data-key=pagination_info_class]", "Page 1 of 3")
    assert has_element?(view, selector, "EX004")
    refute has_element?(view, selector, "EX001")

    render_click(element(view, "#cinder-layout-table"))
    render_click(element(view, "#{selector} button[phx-click=goto_page][phx-value-page='12']"))
    render_click(element(view, "#{selector} [phx-click=toggle_sort][phx-value-key=sequence]"))

    assert has_element?(view, "#{selector} [data-key=pagination_info_class]", "Page 1 of 12")
    assert has_element?(view, selector, "EX120")
    assert has_element?(view, selector, "EX111")
    refute has_element?(view, selector, "EX001")
  end

  test "collection controls change page size and hide only the chosen controls", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/dashboard/dev_panel/layout_test")
    render_click(element(view, "#layout-test-ecosystem-tab"))
    selector = "#layout-test-cinder-collection"

    render_click(element(view, "#{selector} [phx-value-page_size='25']"))
    assert has_element?(view, "#{selector} [data-key=pagination_info_class]", "Page 1 of 5")
    assert has_element?(view, selector, "EX025")
    refute has_element?(view, selector, "EX026")

    render_click(element(view, "#cinder-option-filters"))
    refute has_element?(view, "#{selector} input[name='filters[code]']")
    assert has_element?(view, "#{selector} input[name=search]")
    render_click(element(view, "#cinder-option-search"))
    refute has_element?(view, "#{selector} form[phx-change=filter_change]")
    render_click(element(view, "#cinder-option-sort"))
    refute has_element?(view, "#{selector} [phx-click=toggle_sort]")
    render_click(element(view, "#cinder-option-pagination"))
    refute has_element?(view, "#{selector} [data-key=pagination_info_class]")
    assert has_element?(view, selector, "EX025")
  end

  test "core text, search, and select filters retain each other when changed or cleared", %{
    conn: conn
  } do
    {:ok, view, _html} = live(conn, ~p"/dashboard/dev_panel/layout_test")
    render_click(element(view, "#layout-test-ecosystem-tab"))
    selector = "#layout-test-cinder-collection"
    filter_form = "#layout-test-cinder-component-table-filters"
    state_select = "#layout-test-cinder-component-table-filter-state-select"

    assert has_element?(view, "#{filter_form}[phx-change=filter_change][phx-target]")
    assert has_element?(view, "#{state_select} option[value='']")
    refute has_element?(view, "#{state_select} option[selected]:not([value=''])")

    assert has_element?(
             view,
             "#layout-test-cinder-component-table-filter-state-trigger[role=combobox]"
           )

    render_click(element(view, "#{selector} button[phx-click=goto_page][phx-value-page='12']"))

    render_change(form(view, filter_form, search: "Cinder", filters: %{code: "EX0"}))
    assert has_element?(view, "#{selector} [data-key=pagination_info_class]", "Page 1 of 3")
    assert has_element?(view, selector, "EX006")
    refute has_element?(view, selector, "EX001")
    render_click(element(view, "#{selector} button[title='Go to page 3']"))

    render_change(form(view, filter_form, filters: %{state: "ENABLED"}))
    assert has_element?(view, "#{selector} [data-key=pagination_info_class]", "Page 1 of 2")
    assert has_element?(view, "#{state_select} option[value=ENABLED][selected]")
    assert has_element?(view, "#{filter_form} input[name='filters[code]'][value=EX0]")
    assert has_element?(view, "#{filter_form} input[name=search][value=Cinder]")
    refute has_element?(view, selector, "EX008")
    render_click(element(view, "#{selector} button[title='Go to page 2']"))

    render_change(form(view, filter_form, filters: %{state: ""}))
    assert has_element?(view, "#{selector} [data-key=pagination_info_class]", "Page 1 of 3")
    refute has_element?(view, "#{state_select} option[selected]:not([value=''])")
    assert has_element?(view, "#{filter_form} input[name='filters[code]'][value=EX0]")
    assert has_element?(view, "#{filter_form} input[name=search][value=Cinder]")
    assert has_element?(view, selector, "EX008")
    render_click(element(view, "#{selector} button[title='Go to page 3']"))

    render_change(form(view, filter_form, filters: %{code: ""}))
    assert has_element?(view, "#{selector} [data-key=pagination_info_class]", "Page 1 of 3")
    assert has_element?(view, "#{filter_form} input[name='filters[code]'][value='']")
    assert has_element?(view, "#{filter_form} input[name=search][value=Cinder]")
    refute has_element?(view, selector, "EX001")
    render_click(element(view, "#{selector} button[title='Go to page 3']"))

    render_change(form(view, filter_form, search: ""))

    assert has_element?(view, "#{selector} [data-key=pagination_info_class]", "Page 1 of 12")
    assert has_element?(view, "#{filter_form} input[name=search][value='']")
    assert has_element?(view, selector, "EX001")
  end

  test "native page-size presets reset the page and display the requested records", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/dashboard/dev_panel/layout_test")
    render_click(element(view, "#layout-test-ecosystem-tab"))
    selector = "#layout-test-cinder-collection"
    page_size_config = Cinder.PageSize.parse(nil)

    assert page_size_config.default_page_size == 10
    assert page_size_config.configurable

    assert view
           |> render()
           |> Floki.parse_document!()
           |> Floki.attribute("#{selector} [phx-value-page_size]", "phx-value-page_size") ==
             Enum.map(page_size_config.page_size_options, &Integer.to_string/1)

    render_click(element(view, "#{selector} button[phx-click=goto_page][phx-value-page='12']"))

    for size <- page_size_config.page_size_options do
      render_click(element(view, "#{selector} [phx-value-page_size='#{size}']"))
      pages = ceil(120 / size)
      last_code = size |> Integer.to_string() |> String.pad_leading(3, "0")
      next_code = (size + 1) |> Integer.to_string() |> String.pad_leading(3, "0")

      assert has_element?(
               view,
               "#{selector} [data-key=pagination_info_class]",
               "Page 1 of #{pages}"
             )

      assert has_element?(view, selector, "EX001")
      assert has_element?(view, selector, "EX#{last_code}")
      refute has_element?(view, selector, "EX#{next_code}")
    end
  end

  test "changing the native page size retains filters and sorting", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/dashboard/dev_panel/layout_test")
    render_click(element(view, "#layout-test-ecosystem-tab"))
    selector = "#layout-test-cinder-collection"

    render_change(
      form(view, "#{selector} form[phx-change=filter_change]", filters: %{state: "DISABLED"})
    )

    render_click(element(view, "#{selector} [phx-click=toggle_sort][phx-value-key=sequence]"))

    render_click(
      element(
        view,
        "#{selector} button[phx-click=goto_page][phx-value-page='3'][title='Go to page 3']"
      )
    )

    render_click(element(view, "#{selector} [phx-value-page_size='25']"))

    assert has_element?(view, "#{selector} [data-key=pagination_info_class]", "Page 1 of 2")
    assert has_element?(view, selector, "EX120")
    assert has_element?(view, selector, "EX024")
    refute has_element?(view, selector, "EX020")
    refute has_element?(view, selector, "EX001")

    render_click(
      element(
        view,
        "#{selector} button[phx-click=goto_page][phx-value-page='2'][title='Go to page 2']"
      )
    )

    assert has_element?(view, selector, "EX020")
    assert has_element?(view, selector, "EX004")
    refute has_element?(view, selector, "EX120")
  end

  test "unconfigured or invalid native page sizes leave the current results unchanged", %{
    conn: conn
  } do
    {:ok, view, _html} = live(conn, ~p"/dashboard/dev_panel/layout_test")
    render_click(element(view, "#layout-test-ecosystem-tab"))
    selector = "#layout-test-cinder-collection"

    render_click(element(view, "#{selector} [phx-value-page_size='25']"))

    render_click(
      element(
        view,
        "#{selector} button[phx-click=goto_page][phx-value-page='2'][title='Go to page 2']"
      )
    )

    for value <- ["17", "0", "-1", "25rows", "invalid"] do
      render_click(element(view, "#{selector} [phx-value-page_size='25']"), %{page_size: value})

      assert has_element?(view, "#{selector} [data-key=pagination_info_class]", "Page 2 of 5")
      assert has_element?(view, selector, "EX026")
      assert has_element?(view, selector, "EX050")
      refute has_element?(view, selector, "EX001")
      refute has_element?(view, selector, "EX051")
    end
  end

  test "grid column controls keep the current page and rows", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/dashboard/dev_panel/layout_test")
    render_click(element(view, "#layout-test-ecosystem-tab"))
    render_click(element(view, "#cinder-layout-grid"))
    selector = "#layout-test-cinder-collection"

    render_click(element(view, "#{selector} button[phx-click=goto_page][phx-value-page='12']"))

    for {columns, grid} <- [
          {"2", "grid-cols-[1fr_1fr]"},
          {"3", "grid-cols-[1fr_1fr_1fr]"},
          {"4", "grid-cols-[1fr_1fr_1fr_1fr]"}
        ] do
      render_click(element(view, "#cinder-columns-#{columns}"))
      assert has_element?(view, "#{selector} [data-key=grid_container_class][class*='#{grid}']")
      assert has_element?(view, "#{selector} [data-key=pagination_info_class]", "Page 12 of 12")
      assert has_element?(view, selector, "EX120")
    end
  end

  test "sample identities remain stable across resource reads" do
    resource = ElixirbitsWeb.Dashboard.LayoutTestLive.CinderEntry
    query = Ash.Query.for_read(resource, :read)
    first = Ash.read!(query)
    second = Ash.read!(query)

    assert Enum.map(first, &{&1.code, &1.id}) == Enum.map(second, &{&1.code, &1.id})
    assert Enum.all?(first, &match?({:ok, _}, Ash.Type.UUIDv7.cast_input(&1.id, [])))
  end
end

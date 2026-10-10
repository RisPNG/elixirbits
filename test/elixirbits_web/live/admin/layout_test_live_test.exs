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
        description: "Showcases most, if not all, front-end components.",
        level: 2,
        parent: "DP",
        url: "dev_panel/layout_test",
        sequence: 3000,
        state: :ENABLED
      },
      action: :create,
      domain: AccessControl,
      actor: %{system: true}
    )

    {:ok, view, _html} = live(conn, ~p"/dev_panel/layout_test")

    assert has_element?(view, "#layout-test-local-tab[aria-selected=\"true\"]")
    assert has_element?(view, "#layout-test-local-panel")
    assert has_element?(view, "#layout-test-form[novalidate]")
    assert has_element?(view, "#layout-test-upload-form[novalidate]")
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
    assert has_element?(view, "#layout-test-dependency-form[novalidate]")
    assert has_element?(view, "#layout-test-cinder-table")
    assert has_element?(view, "#layout-test-cinder-grid")
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

  test "core selectors retain their explicit IDs and refresh the matching options", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/dev_panel/layout_test")
    assert has_element?(view, "#layout-test-local-role")

    render_focus(element(view, "#layout-test-local-role input[type=text]"))

    render_hook(element(view, "#layout-test-local-role"), "change", %{
      "text" => "viewer"
    })

    render_hook(view, "live_select_change", %{
      "id" => "layout-test-local-role",
      "text" => "viewer"
    })

    assert has_element?(view, "#layout-test-local-role li", "Viewer")
    refute has_element?(view, "#layout-test-local-role li", "Administrator")
    refute has_element?(view, "#layout-test-local-role li", "Swagger UI")

    render_hook(element(view, "#layout-test-local-role"), "option_click", %{"idx" => "0"})

    assert has_element?(
             view,
             "#layout-test-local-role input[type=hidden][name='local[role]'][value=viewer]"
           )

    assert has_element?(view, "#layout-test-local-role input[type=text][value=Viewer]")
  end

  test "upload previews become read-only together and finished uploads consume entries", %{
    conn: conn
  } do
    {:ok, view, _html} = live(conn, ~p"/dev_panel/layout_test")

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
    assert has_element?(view, "#layout-test-uploads button[phx-click=cancel_upload]")
    assert has_element?(view, "#layout-test-uploads button[phx-click=remove_upload]")

    render_click(element(view, "#toggle-upload-mode"))
    refute has_element?(view, "#layout-test-uploads input[type=file]")
    refute has_element?(view, "#layout-test-uploads button[phx-click=cancel_upload]")
    refute has_element?(view, "#layout-test-uploads button[phx-click=remove_upload]")

    render_click(element(view, "#toggle-upload-mode"))
    render_submit(form(view, "#layout-test-upload-form"))
    assert has_element?(view, "#uploaded-names", "notes.txt")
    refute has_element?(view, "#layout-test-uploads button[phx-click=cancel_upload]")
  end

  test "dialog cancellation and calendar navigation update the showcase", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/dev_panel/layout_test")
    render_click(element(view, "button[phx-click=show_modal]"))
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
    {:ok, view, _html} = live(conn, ~p"/dev_panel/layout_test")

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
    {:ok, view, _html} = live(conn, ~p"/dev_panel/layout_test")

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
    {:ok, view, _html} = live(conn, ~p"/dev_panel/layout_test")
    html = render_submit(view, "local_save", %{"local" => %{"project_name" => "Planning"}})
    assert html =~ "Enter a valid date and time."
    refute has_element?(view, "#submitted-at")
  end
end

defmodule ElixirbitsWeb.CalendarComponentsTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest
  alias ElixirbitsWeb.CalendarComponents

  test "overnight events have clipped segments and unique native selection buttons" do
    event = %{
      id: "overnight",
      title: "Maintenance",
      start: ~U[2026-07-08 23:30:00Z],
      finish: ~U[2026-07-09 01:00:00Z],
      color: :info
    }

    html =
      render_component(&CalendarComponents.calendar/1,
        id: "example",
        events: [event],
        view: :week,
        cursor: ~D[2026-07-08],
        now: ~U[2026-07-08 12:00:00Z]
      )

    document = Floki.parse_document!(html)
    buttons = Floki.find(document, "button[phx-value-event=overnight]")

    assert length(buttons) == 2

    assert Floki.attribute(buttons, "id") == [
             "example-event-2-overnight",
             "example-event-3-overnight"
           ]

    assert Enum.all?(Floki.attribute(buttons, "type"), &(&1 == "button"))
    assert Enum.all?(Floki.attribute(buttons, "aria-label"), &String.contains?(&1, "Maintenance"))
    assert Floki.find(document, "rect[phx-click]") == []
    overlays = Floki.find(document, "foreignobject")
    assert length(overlays) == 2
    assert Floki.attribute(overlays, "height") == ["30", "60"]
    assert Floki.attribute(overlays, "y") == ["1410", "0"]
  end

  test "month and schedule views retain each occupied local day" do
    event = %{
      id: "overnight",
      title: "Maintenance",
      start: ~U[2026-07-08 23:30:00Z],
      finish: ~U[2026-07-09 01:00:00Z]
    }

    for view <- [:month, :schedule] do
      html =
        render_component(&CalendarComponents.calendar/1,
          events: [event],
          view: view,
          cursor: ~D[2026-07-08],
          now: ~U[2026-07-08 12:00:00Z]
        )

      assert html
             |> Floki.parse_document!()
             |> Floki.find("button[phx-value-event=overnight]")
             |> length() == 2
    end
  end

  test "short events whose visible extents overlap render in separate lanes" do
    events = [
      %{
        id: "first",
        title: "First",
        start: ~U[2026-07-08 09:00:00Z],
        finish: ~U[2026-07-08 09:05:00Z]
      },
      %{
        id: "second",
        title: "Second",
        start: ~U[2026-07-08 09:10:00Z],
        finish: ~U[2026-07-08 09:15:00Z]
      }
    ]

    html =
      render_component(&CalendarComponents.calendar/1,
        events: events,
        view: :day,
        cursor: ~D[2026-07-08],
        now: ~U[2026-07-08 12:00:00Z]
      )

    overlays = html |> Floki.parse_document!() |> Floki.find("foreignobject")
    assert length(overlays) == 2
    assert Floki.attribute(overlays, "height") == ["16", "16"]
    assert Floki.attribute(overlays, "x") |> Enum.uniq() |> length() == 2
    assert Floki.attribute(overlays, "width") |> Enum.uniq() |> length() == 1
  end

  test "resources use generic labels and match event columns" do
    event = %{
      id: "meeting",
      title: "Meeting",
      resource_id: "room",
      start: ~U[2026-07-08 09:00:00Z],
      finish: ~U[2026-07-08 10:00:00Z]
    }

    html =
      render_component(&CalendarComponents.calendar/1,
        events: [event],
        view: :resource,
        cursor: ~D[2026-07-08],
        now: ~U[2026-07-08 12:00:00Z],
        resources: [%{id: "room", label: "Meeting room"}]
      )

    assert html =~ "Resources"
    assert html =~ "Meeting room"
    assert html =~ "phx-value-event=\"meeting\""
  end

  test "timezone shifts both occupied days and visible event clocks" do
    event = %{
      id: "morning",
      title: "Planning",
      start: ~U[2026-07-08 23:30:00Z],
      finish: ~U[2026-07-09 01:00:00Z]
    }

    for {timezone, cursor, expected} <- [
          {"Asia/Kuala_Lumpur", ~D[2026-07-09], "7:30 AM"},
          {"America/New_York", ~D[2026-07-08], "7:30 PM"}
        ] do
      html =
        render_component(&CalendarComponents.calendar/1,
          events: [event],
          timezone: timezone,
          view: :day,
          cursor: cursor,
          now: ~U[2026-07-09 00:00:00Z]
        )

      document = Floki.parse_document!(html)
      buttons = Floki.find(document, "button[phx-value-event=morning]")
      assert length(buttons) == 1
      assert document |> Floki.find("svg text") |> Floki.text() =~ expected
      assert Floki.attribute(buttons, "aria-label") |> hd() =~ expected
    end
  end
end

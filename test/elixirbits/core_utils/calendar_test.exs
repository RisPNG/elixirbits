defmodule Elixirbits.CoreUtils.CalendarTest do
  use ExUnit.Case, async: true

  alias Elixirbits.CoreUtils.Calendar

  test "month_grid covers the whole month, Monday-first, in 7-day weeks" do
    weeks = Calendar.month_grid(~D[2026-07-15])
    days = List.flatten(weeks)

    assert Enum.all?(weeks, &(length(&1) == 7))
    assert ~D[2026-07-01] in days
    assert ~D[2026-07-31] in days
    assert List.first(days) == ~D[2026-06-29]
    assert Date.day_of_week(List.first(days)) == 1
  end

  test "week_days returns Monday..Sunday containing the date" do
    days = Calendar.week_days(~D[2026-07-08])

    assert length(days) == 7
    assert List.first(days) == ~D[2026-07-06]
    assert List.last(days) == ~D[2026-07-12]
    assert ~D[2026-07-08] in days
  end

  test "lay_out_events splits overlapping events into side-by-side lanes" do
    a = %{id: "a", start: ~U[2026-07-08 12:00:00Z], finish: ~U[2026-07-08 13:00:00Z]}
    b = %{id: "b", start: ~U[2026-07-08 12:30:00Z], finish: ~U[2026-07-08 13:30:00Z]}
    c = %{id: "c", start: ~U[2026-07-08 15:00:00Z], finish: ~U[2026-07-08 16:00:00Z]}

    laid =
      [a, b, c]
      |> Calendar.events_on(~D[2026-07-08])
      |> Calendar.lay_out_events()
      |> Map.new(&{&1.id, &1})

    assert laid["a"].lanes == 2
    assert laid["b"].lanes == 2
    assert laid["a"].lane != laid["b"].lane
    assert laid["c"].lanes == 1
    assert laid["c"].lane == 0
  end

  test "events_on clips local day segments and excludes midnight finishes" do
    e1 = %{id: "1", start: ~U[2026-07-08 12:00:00Z], finish: ~U[2026-07-08 13:00:00Z]}
    e2 = %{id: "2", start: ~U[2026-07-09 12:00:00Z], finish: ~U[2026-07-09 13:00:00Z]}

    assert [%{id: "1", start_minute: 720, finish_minute: 780}] =
             Calendar.events_on([e1, e2], ~D[2026-07-08])

    overnight = %{id: "3", start: ~U[2026-07-08 23:30:00Z], finish: ~U[2026-07-10 00:00:00Z]}

    assert [
             %{
               start: ~U[2026-07-08 23:30:00Z],
               finish: ~U[2026-07-09 00:00:00Z],
               start_minute: 1410,
               finish_minute: 1440
             }
           ] =
             Calendar.events_on([overnight], ~D[2026-07-08])

    assert [
             %{
               start: ~U[2026-07-09 00:00:00Z],
               finish: ~U[2026-07-10 00:00:00Z],
               start_minute: 0,
               finish_minute: 1440
             }
           ] =
             Calendar.events_on([overnight], ~D[2026-07-09])

    assert Calendar.events_on([overnight], ~D[2026-07-10]) == []
  end

  test "adjacent short events share rendered minimum extents with lane allocation" do
    first = %{id: "first", start: ~U[2026-07-08 09:00:00Z], finish: ~U[2026-07-08 09:05:00Z]}
    second = %{id: "second", start: ~U[2026-07-08 09:10:00Z], finish: ~U[2026-07-08 09:15:00Z]}
    later = %{id: "later", start: ~U[2026-07-08 09:30:00Z], finish: ~U[2026-07-08 09:35:00Z]}

    midnight = %{
      id: "midnight",
      start: ~U[2026-07-08 23:55:00Z],
      finish: ~U[2026-07-09 00:00:00Z]
    }

    laid =
      [first, second, later, midnight]
      |> Calendar.events_on(~D[2026-07-08])
      |> Calendar.lay_out_events()
      |> Map.new(&{&1.id, &1})

    assert laid["first"].finish_minute == 545
    assert laid["first"].display_finish_minute == 556
    assert laid["second"].display_finish_minute == 566
    assert laid["first"].lanes == 2
    assert laid["second"].lanes == 2
    assert laid["first"].lane != laid["second"].lane
    assert laid["later"].lanes == 1
    assert laid["midnight"].display_finish_minute == 1440
  end

  test "local day clipping uses wall-clock minutes across daylight saving changes" do
    event = %{
      id: "dst",
      start: DateTime.shift_zone!(~U[2026-03-08 06:00:00Z], "America/New_York"),
      finish: DateTime.shift_zone!(~U[2026-03-08 08:00:00Z], "America/New_York")
    }

    assert [%{start_minute: 60, finish_minute: 240}] =
             Calendar.events_on([event], ~D[2026-03-08])
  end

  test "parse_view maps params to view atoms, defaulting to :week" do
    assert Calendar.parse_view("day") == :day
    assert Calendar.parse_view("resource") == :resource
    assert Calendar.parse_view("bogus") == :week
    assert Calendar.parse_view(nil) == :week
  end

  test "days beginning with a daylight saving gap clip at the first real local instant" do
    day = ~D[2026-09-06]
    assert {:gap, _before, following} = DateTime.new(day, ~T[00:00:00], "America/Santiago")

    event = %{
      id: "midnight-gap",
      start: DateTime.shift_zone!(~U[2026-09-06 03:30:00Z], "America/Santiago"),
      finish: DateTime.shift_zone!(~U[2026-09-06 05:00:00Z], "America/Santiago")
    }

    assert [%{start: ^following, start_minute: 60, finish_minute: 120}] =
             Calendar.events_on([event], day)
  end

  test "ambiguous midnight includes both occurrences of the repeated hour" do
    day = ~D[2026-11-01]
    assert {:ambiguous, _first, _second} = DateTime.new(day, ~T[00:00:00], "America/Havana")

    events =
      Enum.map([~U[2026-11-01 04:10:00Z], ~U[2026-11-01 05:10:00Z]], fn instant ->
        %{
          id: DateTime.to_iso8601(instant),
          start: DateTime.shift_zone!(instant, "America/Havana"),
          finish: instant |> DateTime.add(600, :second) |> DateTime.shift_zone!("America/Havana")
        }
      end)

    assert [first, second] = Calendar.events_on(events, day)
    assert first.start_minute == 10
    assert second.start_minute == 10
    assert first.start.std_offset != second.start.std_offset
  end

  test "repeated fall-back hours use separate display lanes and retain backwards-clock duration" do
    timezone = "America/New_York"

    first = %{
      id: "first",
      start: DateTime.shift_zone!(~U[2026-11-01 05:15:00Z], timezone),
      finish: DateTime.shift_zone!(~U[2026-11-01 05:45:00Z], timezone)
    }

    second = %{
      id: "second",
      start: DateTime.shift_zone!(~U[2026-11-01 06:15:00Z], timezone),
      finish: DateTime.shift_zone!(~U[2026-11-01 06:45:00Z], timezone)
    }

    laid =
      [first, second]
      |> Calendar.events_on(~D[2026-11-01])
      |> Calendar.lay_out_events()
      |> Map.new(&{&1.id, &1})

    assert laid["first"].lanes == 2
    assert laid["second"].lanes == 2
    assert laid["first"].lane != laid["second"].lane

    crossing = %{
      id: "crossing",
      start: DateTime.shift_zone!(~U[2026-11-01 05:45:00Z], timezone),
      finish: DateTime.shift_zone!(~U[2026-11-01 06:15:00Z], timezone)
    }

    assert [%{start_minute: 105, finish_minute: 135.0}] =
             Calendar.events_on([crossing], ~D[2026-11-01])
  end

  test "window covers the right span per view" do
    assert Calendar.window(:day, ~D[2026-07-09]) == {~D[2026-07-09], ~D[2026-07-09]}
    assert Calendar.window(:week, ~D[2026-07-09]) == {~D[2026-07-06], ~D[2026-07-12]}
    assert Calendar.window(:year, ~D[2026-07-09]) == {~D[2026-01-01], ~D[2026-12-31]}
    {from, to} = Calendar.window(:month, ~D[2026-07-09])
    assert from == ~D[2026-06-29] and to == ~D[2026-08-02]
  end

  test "shift moves the cursor by the view's unit" do
    assert Calendar.shift(:day, ~D[2026-07-09], 1) == ~D[2026-07-10]
    assert Calendar.shift(:week, ~D[2026-07-09], -1) == ~D[2026-07-02]
    assert Calendar.shift(:month, ~D[2026-07-31], 1) == ~D[2026-08-01]
    assert Calendar.shift(:month, ~D[2026-01-15], -1) == ~D[2025-12-01]
    assert Calendar.shift(:year, ~D[2026-07-09], 1) == ~D[2027-01-01]
  end
end

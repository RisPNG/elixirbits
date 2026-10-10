defmodule Elixirbits.CoreUtils.Calendar do
  @moduledoc false

  @day_minutes 1440
  @minimum_event_minutes 16

  @doc "The selectable calendar views as `{value, label}`, in display order."
  def views do
    [
      day: "Day",
      week: "Week",
      month: "Month",
      year: "Year",
      schedule: "Schedule",
      resource: "Resources"
    ]
  end

  @doc "Parses a view param string into a view atom, defaulting to `:week`."
  def parse_view("day"), do: :day
  def parse_view("month"), do: :month
  def parse_view("year"), do: :year
  def parse_view("schedule"), do: :schedule
  def parse_view("resource"), do: :resource
  def parse_view(_other), do: :week

  @doc "The inclusive local date span `{from, to}` a view covers for `cursor`."
  def window(:month, cursor) do
    weeks = month_grid(cursor)
    {weeks |> List.first() |> List.first(), weeks |> List.last() |> List.last()}
  end

  def window(:week, cursor) do
    days = week_days(cursor)
    {List.first(days), List.last(days)}
  end

  def window(:day, cursor), do: {cursor, cursor}
  def window(:resource, cursor), do: {cursor, cursor}
  def window(:schedule, cursor), do: {cursor, Date.add(cursor, 13)}

  def window(:year, cursor),
    do: {Date.new!(cursor.year, 1, 1), Date.new!(cursor.year, 12, 31)}

  @doc "Moves `cursor` by `dir` (±1) in the units of `view`."
  def shift(:month, cursor, dir) do
    month = cursor.month + dir

    cond do
      month < 1 -> %{cursor | year: cursor.year - 1, month: 12, day: 1}
      month > 12 -> %{cursor | year: cursor.year + 1, month: 1, day: 1}
      true -> %{cursor | month: month, day: 1}
    end
  end

  def shift(:week, cursor, dir), do: Date.add(cursor, dir * 7)
  def shift(:day, cursor, dir), do: Date.add(cursor, dir)
  def shift(:resource, cursor, dir), do: Date.add(cursor, dir)
  def shift(:schedule, cursor, dir), do: Date.add(cursor, dir * 14)
  def shift(:year, cursor, dir), do: %{cursor | year: cursor.year + dir, month: 1, day: 1}

  @doc "Weeks (Monday-first) covering the whole month `date` falls in, each a list of 7 Dates."
  def month_grid(%Date{} = date) do
    first = Date.beginning_of_month(date)
    last = Date.end_of_month(date)

    Date.beginning_of_week(first, :monday)
    |> Date.range(Date.end_of_week(last, :monday))
    |> Enum.chunk_every(7)
  end

  @doc "The seven Dates (Monday-first) of the week `date` falls in."
  def week_days(%Date{} = date) do
    start = Date.beginning_of_week(date, :monday)
    Enum.map(0..6, &Date.add(start, &1))
  end

  @doc "Clips events to a local day, excluding events that finish exactly at its start."
  def events_on(events, %Date{} = day) do
    Enum.flat_map(events, fn event ->
      start_of_day =
        case DateTime.new(day, ~T[00:00:00], event.start.time_zone) do
          {:ok, datetime} -> datetime
          {:ambiguous, first, _second} -> first
          {:gap, _before, following} -> following
        end

      end_of_day =
        case DateTime.new(Date.add(day, 1), ~T[00:00:00], event.start.time_zone) do
          {:ok, datetime} -> datetime
          {:ambiguous, first, _second} -> first
          {:gap, _before, following} -> following
        end

      if DateTime.compare(event.start, end_of_day) == :lt and
           DateTime.compare(event.finish, start_of_day) == :gt do
        start =
          if DateTime.compare(event.start, start_of_day) == :lt,
            do: start_of_day,
            else: event.start

        finish =
          if DateTime.compare(event.finish, end_of_day) == :gt, do: end_of_day, else: event.finish

        start_minute = start.hour * 60 + start.minute

        finish_minute =
          if DateTime.compare(finish, end_of_day) == :eq,
            do: @day_minutes,
            else: finish.hour * 60 + finish.minute

        finish_minute =
          if finish_minute <= start_minute,
            do: start_minute + DateTime.diff(finish, start, :second) / 60,
            else: finish_minute

        [
          Map.merge(event, %{
            start: start,
            finish: finish,
            start_minute: start_minute,
            finish_minute: finish_minute
          })
        ]
      else
        []
      end
    end)
  end

  @doc """
  Annotates local day segments with `:lane` and `:lanes` so visually overlapping events share a day column side by side: overlapping segments form a cluster, each event takes the first free lane, and every event in a cluster reports the cluster's total lane count for width. `:display_finish_minute` includes the minimum visible extent and is shared by lane allocation and rendering.
  """
  def lay_out_events(events) do
    events
    |> Enum.map(fn event ->
      Map.put(
        event,
        :display_finish_minute,
        min(max(event.finish_minute, event.start_minute + @minimum_event_minutes), @day_minutes)
      )
    end)
    |> Enum.sort_by(& &1.start_minute)
    |> cluster_events()
    |> Enum.flat_map(&assign_lanes/1)
  end

  defp cluster_events(sorted) do
    Enum.chunk_while(
      sorted,
      {[], nil},
      fn
        event, {[], _max} ->
          {:cont, {[event], event.display_finish_minute}}

        event, {group, max_finish} ->
          if event.start_minute < max_finish do
            later =
              if event.display_finish_minute > max_finish,
                do: event.display_finish_minute,
                else: max_finish

            {:cont, {[event | group], later}}
          else
            {:cont, Enum.reverse(group), {[event], event.display_finish_minute}}
          end
      end,
      fn
        {[], _} -> {:cont, {[], nil}}
        {group, _} -> {:cont, Enum.reverse(group), {[], nil}}
      end
    )
  end

  defp assign_lanes(cluster) do
    {placed, lane_ends} =
      Enum.reduce(cluster, {[], []}, fn event, {placed, lane_ends} ->
        case Enum.find_index(lane_ends, &(&1 <= event.start_minute)) do
          nil ->
            {[{event, length(lane_ends)} | placed], lane_ends ++ [event.display_finish_minute]}

          index ->
            {[{event, index} | placed],
             List.replace_at(lane_ends, index, event.display_finish_minute)}
        end
      end)

    total = length(lane_ends)
    Enum.map(placed, fn {event, lane} -> Map.merge(event, %{lane: lane, lanes: total}) end)
  end
end

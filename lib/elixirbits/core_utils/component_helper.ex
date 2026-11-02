# Flash notifications

defmodule Elixirbits.CoreUtils.ComponentHelper do
  @moduledoc false

  def put_flash(%Phoenix.LiveView.Socket{} = socket, kind, message) do
    socket.assigns.flash
    |> Map.keys()
    |> Enum.reduce(socket, &Phoenix.LiveView.clear_flash(&2, &1))
    |> Phoenix.LiveView.put_flash(kind, message)
    |> Phoenix.LiveView.push_event("flash:replace", %{kind: to_string(kind)})
  end

  def put_flash(%Plug.Conn{} = conn, kind, message) do
    conn
    |> Phoenix.Controller.clear_flash()
    |> Phoenix.Controller.put_flash(kind, message)
  end
end

# Calendar components

defmodule Elixirbits.CoreUtils.ComponentHelper.Calendar do
  @moduledoc false

  use Phoenix.Component

  import ElixirbitsWeb.CoreComponents, only: [button: 1, icon: 1]

  @day_minutes 1440
  @minimum_event_minutes 16
  @base 1000
  @gutter 48
  @hour 60
  @header 40

  @event_styles %{
    brand: %{
      fill: "fill-brand",
      label_fill: "fill-content-inverse dark:fill-content",
      stroke: "stroke-brand",
      solid_bar: "bg-brand text-content-inverse dark:text-content",
      outline_bar: "border border-brand bg-primary text-content",
      dot: "bg-brand"
    },
    info: %{
      fill: "fill-info",
      label_fill: "fill-content",
      stroke: "stroke-info",
      solid_bar: "bg-info text-content",
      outline_bar: "border border-info bg-primary text-content",
      dot: "bg-info"
    },
    success: %{
      fill: "fill-success",
      label_fill: "fill-content",
      stroke: "stroke-success",
      solid_bar: "bg-success text-content",
      outline_bar: "border border-success bg-primary text-content",
      dot: "bg-success"
    },
    warning: %{
      fill: "fill-warning",
      label_fill: "fill-content",
      stroke: "stroke-warning",
      solid_bar: "bg-warning text-content",
      outline_bar: "border border-warning bg-primary text-content",
      dot: "bg-warning"
    },
    error: %{
      fill: "fill-error",
      label_fill: "fill-content",
      stroke: "stroke-error",
      solid_bar: "bg-error text-content",
      outline_bar: "border border-error bg-primary text-content",
      dot: "bg-error"
    },
    neutral: %{
      fill: "fill-secondary",
      label_fill: "fill-content",
      stroke: "stroke-secondary",
      solid_bar: "bg-secondary text-content",
      outline_bar: "border border-secondary bg-primary text-content",
      dot: "bg-secondary"
    }
  }

  embed_templates "component_helper/calendar/*", suffix: "_template"

  # Calendar

  @doc """
  Renders day, week, month, year, schedule, and resource views for a list of events. Emits `calendar_change` for navigation (`%{"view" => v, "date" => d}`) and event selection (`%{"event" => id}`). The consumer handles both kinds of event.

  Events are plain maps. Only these keys are read (extra keys are ignored, so the consumer can keep its own domain fields on the same map):

    * `id`: echoed back on selection
    * `title`: block label
    * `subtitle`: optional secondary label
    * `start` / `finish`: UTC `DateTime`s
    * `color`: a theme token (`:brand | :info | :success | :warning | :error | :neutral`)
    * `variant`: `:solid | :outline` (default `:solid`)
    * `resource_id`: matches a `resources[].id` for the resource view

  Event datetimes are supplied in UTC. `timezone` is applied uniformly for display.
  """
  attr :id, :string, default: "calendar"
  attr :events, :list, required: true
  attr :timezone, :string, default: "Etc/UTC"
  attr :now, :any, default: nil, doc: "current instant as a UTC DateTime, defaulting to now"
  attr :view, :atom, default: :week
  attr :cursor, :any, default: nil, doc: "focal Date, defaulting to today in `timezone`"

  attr :resources, :list,
    default: [],
    doc: "columns for the resource view: %{id, label, sublabel}"

  attr :active_event, :any, default: nil, doc: "id of the highlighted event"

  def calendar(assigns) do
    tz = assigns.timezone
    now_local = DateTime.shift_zone!(assigns.now || DateTime.utc_now(), tz)
    today = DateTime.to_date(now_local)

    events =
      Enum.map(assigns.events, fn event ->
        style = Map.get(@event_styles, Map.get(event, :color, :neutral), @event_styles.neutral)
        outline = Map.get(event, :variant, :solid) == :outline
        start = DateTime.shift_zone!(event.start, tz)
        finish = DateTime.shift_zone!(event.finish, tz)

        label =
          "#{event.title}, #{Calendar.strftime(start, "%-d %b %Y %-I:%M %p %Z")} to #{Calendar.strftime(finish, "%-d %b %Y %-I:%M %p %Z")}"

        event
        |> Map.put(:fill_class, if(outline, do: "fill-transparent", else: style.fill))
        |> Map.put(:label_fill_class, if(outline, do: "fill-content", else: style.label_fill))
        |> Map.put(:stroke_class, style.stroke)
        |> Map.put(:bar_class, if(outline, do: style.outline_bar, else: style.solid_bar))
        |> Map.put(:dot_class, style.dot)
        |> Map.put(:label, if(event[:subtitle], do: "#{label}, #{event.subtitle}", else: label))
        |> Map.put(:start, start)
        |> Map.put(:finish, finish)
        |> Map.put_new(:color, :neutral)
        |> Map.put_new(:variant, :solid)
        |> Map.put_new(:subtitle, nil)
      end)

    assigns =
      assigns
      |> assign(:cursor, assigns.cursor || today)
      |> assign(:today, today)
      |> assign(:now_local, now_local)
      |> assign(:events, events)

    calendar_template(assigns)
  end

  # View selection

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

  # Date windows and navigation

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

  @doc "Moves `cursor` by `dir` (1 or -1) in the units of `view`."
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

  # Date grids

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

  # Event placement

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

  # View rendering

  attr :view, :atom, required: true
  attr :cursor, :any, required: true
  attr :today, :any, required: true

  defp cal_nav(assigns) do
    period_title =
      case assigns.view do
        :month ->
          Calendar.strftime(assigns.cursor, "%B %Y")

        :week ->
          days = week_days(assigns.cursor)

          "#{Calendar.strftime(List.first(days), "%-d %b")} to #{Calendar.strftime(List.last(days), "%-d %b %Y")}"

        :day ->
          Calendar.strftime(assigns.cursor, "%A, %-d %b %Y")

        :resource ->
          Calendar.strftime(assigns.cursor, "%A, %-d %b") <> " by resource"

        :year ->
          to_string(assigns.cursor.year)

        :schedule ->
          "#{Calendar.strftime(assigns.cursor, "%-d %b")} to #{Calendar.strftime(Date.add(assigns.cursor, 13), "%-d %b %Y")}"
      end

    assigns = assign(assigns, :period_title, period_title)
    cal_nav_template(assigns)
  end

  attr :id, :string, required: true
  attr :columns, :list, required: true
  attr :now_col, :any, default: nil
  attr :now_minutes, :any, default: nil
  attr :active, :any, default: nil

  defp time_body(assigns) do
    ncols = length(assigns.columns)
    col_w = (@base - @gutter) / max(ncols, 1)

    assigns =
      assigns
      |> assign(:ncols, ncols)
      |> assign(:col_w, col_w)
      |> assign(:width, @base)
      |> assign(:gutter, @gutter)
      |> assign(:hour, @hour)
      |> assign(:day, @day_minutes)
      |> assign(:header, @header)
      |> assign(:now_x1, (assigns.now_col && @gutter + assigns.now_col * col_w) || @gutter)
      |> assign(:now_x2, (assigns.now_col && @gutter + (assigns.now_col + 1) * col_w) || nil)

    time_body_template(assigns)
  end

  attr :events, :list, required: true
  attr :cursor, :any, required: true
  attr :today, :any, required: true

  defp month_body(assigns) do
    assigns = assign(assigns, :days, List.flatten(month_grid(assigns.cursor)))

    month_body_template(assigns)
  end

  attr :events, :list, required: true
  attr :cursor, :any, required: true
  attr :today, :any, required: true

  defp year_body(assigns) do
    assigns =
      assign(
        assigns,
        :event_days,
        assigns.events
        |> Enum.flat_map(fn event ->
          Date.range(
            DateTime.to_date(event.start),
            DateTime.to_date(DateTime.add(event.finish, -1, :microsecond))
          )
          |> Enum.to_list()
        end)
        |> MapSet.new()
      )

    year_body_template(assigns)
  end

  attr :events, :list, required: true
  attr :cursor, :any, required: true
  attr :active, :any, default: nil

  defp agenda_body(assigns) do
    {from, to} = window(:schedule, assigns.cursor)

    groups =
      from
      |> Date.range(to)
      |> Enum.map(fn day -> {day, events_on(assigns.events, day)} end)
      |> Enum.reject(fn {_day, events} -> events == [] end)

    assigns = assign(assigns, :groups, groups)

    agenda_body_template(assigns)
  end

  # Time layout

  defp time_columns(:week, cursor, events, _resources, today, now_local) do
    days = week_days(cursor)
    now_col = Enum.find_index(days, &(&1 == today))

    %{
      columns: Enum.map(days, &day_column(events, &1, today)),
      now_col: now_col,
      now_minutes: (now_col && now_local.hour * 60 + now_local.minute) || nil
    }
  end

  defp time_columns(:day, cursor, events, _resources, today, now_local) do
    %{
      columns: [day_column(events, cursor, today)],
      now_col: (cursor == today && 0) || nil,
      now_minutes: (cursor == today && now_local.hour * 60 + now_local.minute) || nil
    }
  end

  defp time_columns(:resource, cursor, events, resources, today, now_local) do
    day_events = events_on(events, cursor)

    columns =
      Enum.map(resources, fn resource ->
        %{
          label: resource.label,
          sublabel: resource[:sublabel] || "",
          today?: cursor == today,
          events: day_events |> Enum.filter(&(&1.resource_id == resource.id)) |> lay_out_events()
        }
      end)

    %{
      columns: columns,
      now_col: nil,
      now_minutes: (cursor == today && now_local.hour * 60 + now_local.minute) || nil
    }
  end

  defp day_column(events, day, today) do
    %{
      label: Calendar.strftime(day, "%a"),
      sublabel: to_string(day.day),
      today?: day == today,
      events: events |> events_on(day) |> lay_out_events()
    }
  end

  defp event_box(event, col_index, col_w) do
    from_min = event.start_minute
    lanes = event.lanes
    lane_w = col_w / lanes

    %{
      x: @gutter + col_index * col_w + event.lane * lane_w + 1,
      y: from_min,
      w: lane_w - 2,
      h: event.display_finish_minute - from_min
    }
  end

  # Overlap groups

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

# Public uploads

defmodule Elixirbits.CoreUtils.ComponentHelper.Upload do
  @moduledoc "Persists public LiveView uploads outside the application release."

  def consume(socket, upload_name, scope) do
    Phoenix.LiveView.consume_uploaded_entries(socket, upload_name, fn %{path: path}, entry ->
      filename = Ash.UUID.generate() <> Path.extname(entry.client_name)
      directory = Path.join(Application.fetch_env!(:elixirbits, :upload_directory), scope)
      File.mkdir_p!(directory)
      File.cp!(path, Path.join(directory, filename))
      {:ok, "/uploads/#{scope}/#{filename}"}
    end)
  end

  def delete(<<"/uploads/", path::binary>>) do
    if path != "" and Path.type(path) == :relative and
         Enum.all?(Path.split(path), &(&1 not in [".", "..", ""])) do
      path
      |> then(&Path.join(Application.fetch_env!(:elixirbits, :upload_directory), &1))
      |> File.rm()
      |> case do
        :ok -> :ok
        {:error, :enoent} -> :ok
        error -> error
      end
    else
      {:error, :invalid_path}
    end
  end

  def delete(_url), do: {:error, :invalid_path}
end

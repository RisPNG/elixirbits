defmodule ElixirbitsWeb.CalendarComponents do
  @moduledoc false
  use ElixirbitsWeb, :html

  alias Elixirbits.CoreUtils.Calendar, as: Cal

  @base 1000
  @gutter 48
  @hour 60
  @day 1440
  @header 40

  @event_styles %{
    brand: %{
      fill: "fill-brand",
      stroke: "stroke-brand",
      solid_bar: "bg-brand text-content",
      outline_bar: "border border-brand bg-primary text-content",
      dot: "bg-brand"
    },
    info: %{
      fill: "fill-info",
      stroke: "stroke-info",
      solid_bar: "bg-info text-content",
      outline_bar: "border border-info bg-primary text-content",
      dot: "bg-info"
    },
    success: %{
      fill: "fill-success",
      stroke: "stroke-success",
      solid_bar: "bg-success text-content",
      outline_bar: "border border-success bg-primary text-content",
      dot: "bg-success"
    },
    warning: %{
      fill: "fill-warning",
      stroke: "stroke-warning",
      solid_bar: "bg-warning text-content",
      outline_bar: "border border-warning bg-primary text-content",
      dot: "bg-warning"
    },
    error: %{
      fill: "fill-error",
      stroke: "stroke-error",
      solid_bar: "bg-error text-content",
      outline_bar: "border border-error bg-primary text-content",
      dot: "bg-error"
    },
    neutral: %{
      fill: "fill-tertiary",
      stroke: "stroke-tertiary",
      solid_bar: "bg-tertiary text-content",
      outline_bar: "border border-tertiary bg-primary text-content",
      dot: "bg-tertiary"
    }
  }

  embed_templates "calendar_components/*", suffix: "_template"

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

  attr :view, :atom, required: true
  attr :cursor, :any, required: true
  attr :today, :any, required: true

  defp cal_nav(assigns) do
    period_title =
      case assigns.view do
        :month ->
          Calendar.strftime(assigns.cursor, "%B %Y")

        :week ->
          days = Cal.week_days(assigns.cursor)

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
      |> assign(:day, @day)
      |> assign(:header, @header)
      |> assign(:now_x1, (assigns.now_col && @gutter + assigns.now_col * col_w) || @gutter)
      |> assign(:now_x2, (assigns.now_col && @gutter + (assigns.now_col + 1) * col_w) || nil)

    time_body_template(assigns)
  end

  attr :events, :list, required: true
  attr :cursor, :any, required: true
  attr :today, :any, required: true

  defp month_body(assigns) do
    assigns = assign(assigns, :days, List.flatten(Cal.month_grid(assigns.cursor)))

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
    {from, to} = Cal.window(:schedule, assigns.cursor)

    groups =
      from
      |> Date.range(to)
      |> Enum.map(fn day -> {day, Cal.events_on(assigns.events, day)} end)
      |> Enum.reject(fn {_day, events} -> events == [] end)

    assigns = assign(assigns, :groups, groups)

    agenda_body_template(assigns)
  end

  defp time_columns(:week, cursor, events, _resources, today, now_local) do
    days = Cal.week_days(cursor)
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
    day_events = Cal.events_on(events, cursor)

    columns =
      Enum.map(resources, fn resource ->
        %{
          label: resource.label,
          sublabel: resource[:sublabel] || "",
          today?: cursor == today,
          events:
            day_events |> Enum.filter(&(&1.resource_id == resource.id)) |> Cal.lay_out_events()
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
      events: events |> Cal.events_on(day) |> Cal.lay_out_events()
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
end

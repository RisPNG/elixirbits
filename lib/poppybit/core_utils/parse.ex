defmodule Poppybit.CoreUtils.Parse do
  @moduledoc false

  alias Elixir.Color, as: NativeColor
  alias Poppybit.CoreUtils.Options

  @year_first_pattern ~r/^(?<year>\d{4})[-\/](?<month>\d{1,2})[-\/](?<day>\d{1,2})(?:[ T](?<hour>\d{1,2}):(?<minute>\d{2})(?::(?<second>\d{2}))?)?$/
  @day_first_pattern ~r/^(?<day>\d{1,2})[\/-](?<month>\d{1,2})[\/-](?<year>\d{4})(?:[ T](?<hour>\d{1,2}):(?<minute>\d{2})(?::(?<second>\d{2}))?)?$/
  @numeric_pattern ~r/^\d+(\.\d+)?$/

  # Numeric conversions

  def to_integer(value, fallback \\ 0) do
    case value do
      value when is_integer(value) ->
        value

      value when is_float(value) ->
        round(value)

      %Decimal{} = decimal ->
        decimal |> Decimal.round(0) |> Decimal.to_integer()

      value when is_binary(value) ->
        trimmed = String.trim(value)

        cond do
          trimmed == "" ->
            fallback

          String.contains?(trimmed, ".") ->
            case Float.parse(trimmed) do
              {float_value, _rest} -> round(float_value)
              :error -> fallback
            end

          true ->
            case Integer.parse(trimmed) do
              {integer_value, _rest} -> integer_value
              :error -> fallback
            end
        end

      value when is_list(value) ->
        case value do
          [single_value] -> to_integer(single_value, fallback)
          _ -> fallback
        end

      value when is_boolean(value) ->
        if value, do: 1, else: 0

      %DateTime{} = datetime ->
        DateTime.to_unix(datetime)

      %Date{} = date ->
        date |> Date.to_erl() |> :calendar.date_to_gregorian_days()

      nil ->
        fallback

      _ ->
        fallback
    end
  end

  def to_decimal(value, fallback \\ Decimal.new(0))

  def to_decimal(%Decimal{} = value, _fallback), do: value

  def to_decimal(value, fallback) when is_binary(value) do
    case Decimal.cast(String.trim(value)) do
      {:ok, decimal} -> decimal
      :error -> fallback
    end
  end

  def to_decimal([value], fallback), do: to_decimal(value, fallback)
  def to_decimal(true, _fallback), do: Decimal.new(1)
  def to_decimal(false, _fallback), do: Decimal.new(0)

  def to_decimal(value, fallback) when is_number(value) do
    case Decimal.cast(value) do
      {:ok, decimal} -> decimal
      :error -> fallback
    end
  end

  def to_decimal(_value, fallback), do: fallback

  # Datetime conversions

  @doc """
  Interprets local clock values in `:source_timezone` and converts their instant to `:target_timezone`, both defaulting to `Etc/UTC`. Explicit offsets keep their instant. `on_invalid: :error` returns tagged errors for invalid input, ambiguous clocks, and clocks that do not exist. Otherwise, invalid input uses `:fallback`.
  """
  def to_datetime(input, opts \\ []) do
    fallback = Keyword.get(opts, :fallback)
    source_timezone = Keyword.get(opts, :source_timezone, "Etc/UTC")
    target_timezone = Keyword.get(opts, :target_timezone, "Etc/UTC")

    datetime =
      case input do
        nil ->
          fallback

        value when is_binary(value) ->
          value
          |> String.trim()
          |> parse_datetime_string()

        %DateTime{} = datetime ->
          datetime

        %NaiveDateTime{} = naive_datetime ->
          naive_datetime

        %Date{} = date ->
          NaiveDateTime.new!(date, ~T[00:00:00])

        value when is_integer(value) or is_float(value) ->
          excel_serial_to_naive_datetime(value)

        _ ->
          {:error, :invalid_datetime}
      end

    datetime =
      case datetime do
        %NaiveDateTime{} = naive_datetime ->
          case DateTime.from_naive(naive_datetime, source_timezone) do
            {:ok, datetime} -> datetime
            {:ambiguous, _first, _second} -> {:error, :ambiguous_datetime}
            {:gap, _before, _following} -> {:error, :nonexistent_datetime}
            {:error, reason} -> {:error, reason}
          end

        value ->
          value
      end

    case datetime do
      %DateTime{} ->
        datetime =
          if target_timezone, do: DateTime.shift_zone!(datetime, target_timezone), else: datetime

        DateTime.truncate(datetime, Keyword.get(opts, :precision, :microsecond))

      {:error, _reason} = error ->
        if Keyword.get(opts, :on_invalid) == :error do
          error
        else
          case fallback do
            %DateTime{} ->
              DateTime.truncate(fallback, Keyword.get(opts, :precision, :microsecond))

            value ->
              value
          end
        end

      value ->
        value
    end
  end

  def to_naive_datetime(input, opts \\ []) do
    fallback = Keyword.get(opts, :fallback)
    target_timezone = Keyword.get(opts, :target_timezone)

    datetime =
      case input do
        nil ->
          fallback

        value when is_binary(value) ->
          value
          |> String.trim()
          |> to_naive_datetime_from_string(target_timezone, fallback)

        %NaiveDateTime{} = naive_datetime ->
          naive_datetime

        %DateTime{} = datetime ->
          datetime =
            if target_timezone,
              do: DateTime.shift_zone!(datetime, target_timezone),
              else: datetime

          DateTime.to_naive(datetime)

        %Date{} = date ->
          NaiveDateTime.new!(date, ~T[00:00:00])

        value when is_integer(value) or is_float(value) ->
          excel_serial_to_naive_datetime(value)

        _ ->
          fallback
      end

    case datetime do
      %NaiveDateTime{} ->
        NaiveDateTime.truncate(datetime, Keyword.get(opts, :precision, :microsecond))

      value ->
        value
    end
  end

  # Color conversions

  @color_options [
    {"HEX", "hex"},
    {"RGB", "rgb"},
    {"HSL", "hsl"},
    {"Lab", "lab"},
    {"LCH", "lch"},
    {"OKLab", "oklab"},
    {"OKLCH", "oklch"},
    {"XYZ D50", "xyz-d50"},
    {"XYZ D65", "xyz-d65"},
    {"CMYK", "cmyk"}
  ]
  @color_targets %{
    "hex" => NativeColor.SRGB,
    "rgb" => NativeColor.SRGB,
    "hsl" => NativeColor.HSL,
    "lab" => NativeColor.Lab,
    "lch" => NativeColor.LCHab,
    "oklab" => NativeColor.Oklab,
    "oklch" => NativeColor.Oklch,
    "xyz-d50" => NativeColor.XYZ,
    "xyz-d65" => NativeColor.XYZ,
    "cmyk" => NativeColor.CMYK
  }
  @color_formats Map.keys(@color_targets)
  @color_number "[+-]?(?:[0-9]+(?:\\.[0-9]+)?|\\.[0-9]+)(?:e[+-]?[0-9]+)?"
  @color_channel "#{@color_number}%?"
  @color_hue "#{@color_number}(?:deg|grad|rad|turn)?"
  @color_syntax ~r/\A(?:
    \#(?:[0-9a-f]{3}|[0-9a-f]{4}|[0-9a-f]{6}|[0-9a-f]{8})
    | rgba?\(\s*#{@color_channel}\s+#{@color_channel}\s+#{@color_channel}(?:\s*\/\s*#{@color_channel})?\s*\)
    | rgba?\(\s*(?:#{@color_number}\s*,\s*#{@color_number}\s*,\s*#{@color_number}|#{@color_number}%\s*,\s*#{@color_number}%\s*,\s*#{@color_number}%)(?:\s*,\s*#{@color_channel})?\s*\)
    | hsla?\(\s*#{@color_hue}\s+#{@color_number}%\s+#{@color_number}%(?:\s*\/\s*#{@color_channel})?\s*\)
    | hsla?\(\s*#{@color_hue}\s*,\s*#{@color_number}%\s*,\s*#{@color_number}%(?:\s*,\s*#{@color_channel})?\s*\)
    | (?:oklab|lab)\(\s*#{@color_channel}\s+#{@color_number}\s+#{@color_number}(?:\s*\/\s*#{@color_channel})?\s*\)
    | (?:oklch|lch)\(\s*#{@color_channel}\s+#{@color_number}\s+#{@color_hue}(?:\s*\/\s*#{@color_channel})?\s*\)
    | color\(\s*(?:srgb|xyz|xyz-d50|xyz-d65)\s+#{@color_number}\s+#{@color_number}\s+#{@color_number}(?:\s*\/\s*#{@color_channel})?\s*\)
    | device-cmyk\(\s*#{@color_channel}\s+#{@color_channel}\s+#{@color_channel}\s+#{@color_channel}(?:\s*\/\s*#{@color_channel})?\s*\)
  )\z/x
  @color_numbers ~r/#{@color_number}/
  @color_error "must be a supported color value"

  def color_options, do: @color_options

  def inspect_color(value) when is_binary(value) do
    input =
      value
      |> String.trim()
      |> String.downcase()
      |> String.replace(~r/(?<![\d.])([+-]?)\.(?=\d)/, "\\g{1}0.")

    if input == "" do
      {:ok, nil}
    else
      with true <- Regex.match?(@color_syntax, input),
           true <-
             String.starts_with?(input, "#") ||
               Enum.all?(Regex.scan(@color_numbers, input), fn [number] ->
                 match?({_number, ""}, Float.parse(number))
               end),
           {:ok, color} <- NativeColor.CSS.parse(input),
           {:ok, color} <-
             (case color do
                %NativeColor.SRGB{r: r, g: g, b: b}
                when r >= 0 and r <= 1 and g >= 0 and g <= 1 and b >= 0 and b <= 1 ->
                  {:ok, color}

                %NativeColor.SRGB{} ->
                  NativeColor.Gamut.to_gamut(color, :SRGB, method: :clip)

                %NativeColor.HSL{h: hue} ->
                  {:ok,
                   %{
                     color
                     | h: hue - Float.floor(hue),
                       s: color.s |> max(0.0) |> min(1.0),
                       l: color.l |> max(0.0) |> min(1.0)
                   }}

                %NativeColor.CMYK{} ->
                  {:ok,
                   %{
                     color
                     | c: color.c |> max(0.0) |> min(1.0),
                       m: color.m |> max(0.0) |> min(1.0),
                       y: color.y |> max(0.0) |> min(1.0),
                       k: color.k |> max(0.0) |> min(1.0)
                   }}

                color ->
                  {:ok, color}
              end),
           {:ok, preview} <- color_preview(color) do
        format =
          if String.starts_with?(input, "#") do
            "hex"
          else
            case color do
              %NativeColor.XYZ{illuminant: :D50} ->
                "xyz-d50"

              %NativeColor.XYZ{} ->
                "xyz-d65"

              color ->
                Enum.find_value(@color_options, fn {_label, format} ->
                  if format != "hex" && Map.fetch!(@color_targets, format) == color.__struct__,
                    do: format
                end)
            end
          end

        {:ok,
         preview
         |> Map.delete(:srgb)
         |> Map.merge(%{value: value, format: format, color: color})}
      else
        _ -> {:error, @color_error}
      end
    end
  rescue
    ArithmeticError -> {:error, @color_error}
  end

  def inspect_color(nil), do: {:ok, nil}
  def inspect_color(_value), do: {:error, @color_error}

  def convert_color(%_{} = color, target_format) when target_format in @color_formats do
    with {:ok, preview} <- color_preview(color),
         {:ok, converted} <-
           (case target_format do
              format when format in ["hex", "rgb"] ->
                {:ok, preview.srgb}

              format when format in ["hsl", "cmyk"] ->
                NativeColor.convert(preview.srgb, Map.fetch!(@color_targets, format))

              format when format in ["lab", "lch", "xyz-d50", "xyz-d65"] ->
                illuminant = if format == "xyz-d65", do: :D65, else: :D50

                with {:ok, xyz} <- NativeColor.convert(color, NativeColor.XYZ),
                     {:ok, xyz} <- NativeColor.XYZ.adapt(xyz, illuminant) do
                  NativeColor.convert(xyz, Map.fetch!(@color_targets, format))
                end

              format ->
                NativeColor.convert(color, Map.fetch!(@color_targets, format))
            end) do
      value =
        NativeColor.CSS.to_css(converted, as: if(target_format == "hex", do: :hex, else: :rgb))

      {:ok,
       preview
       |> Map.delete(:srgb)
       |> Map.merge(%{value: value, format: target_format, color: color})}
    else
      _ -> {:error, @color_error}
    end
  end

  def convert_color(_color, _target_format), do: {:error, @color_error}

  # Phone conversion

  @doc """
  Splits a composite phone string like `"+60 123456789"` or `"+60123456789"` into `{dial_code, number, iso}`. The longest matching dial-code prefix wins. Returns `{nil, raw, nil}` if no dial-code prefix is detected.
  """
  def to_phone(value) when is_binary(value) do
    trimmed = String.trim(value)

    cond do
      trimmed == "" ->
        {nil, "", nil}

      String.starts_with?(trimmed, "+") ->
        match =
          Options.Phones.list_countries()
          |> Enum.filter(fn c -> String.starts_with?(trimmed, c.dial_code) end)
          |> Enum.max_by(fn c -> String.length(c.dial_code) end, fn -> nil end)

        case match do
          nil ->
            {nil, trimmed, nil}

          c ->
            rest =
              trimmed
              |> String.replace_prefix(c.dial_code, "")
              |> String.trim_leading()

            {c.dial_code, rest, c.iso}
        end

      true ->
        {nil, trimmed, nil}
    end
  end

  def to_phone(_), do: {nil, "", nil}

  # Datetime parsing

  defp parse_datetime_string(""), do: {:error, :invalid_datetime}

  defp parse_datetime_string(value) do
    cond do
      String.match?(value, @numeric_pattern) ->
        case Float.parse(value) do
          {number, ""} ->
            excel_serial_to_naive_datetime(number)

          _ ->
            {:error, :invalid_datetime}
        end

      true ->
        case DateTime.from_iso8601(value) do
          {:ok, datetime, _offset} ->
            datetime

          _ ->
            case parse_naive_datetime_string(value) do
              {:ok, naive_datetime} ->
                naive_datetime

              :error ->
                {:error, :invalid_datetime}
            end
        end
    end
  end

  defp to_naive_datetime_from_string("", _target_timezone, fallback), do: fallback

  defp to_naive_datetime_from_string(value, target_timezone, fallback) do
    cond do
      String.match?(value, @numeric_pattern) ->
        case Float.parse(value) do
          {number, ""} ->
            to_naive_datetime(number, target_timezone: target_timezone, fallback: fallback)

          _ ->
            fallback
        end

      true ->
        case DateTime.from_iso8601(value) do
          {:ok, datetime, _offset} ->
            datetime =
              if target_timezone,
                do: DateTime.shift_zone!(datetime, target_timezone),
                else: datetime

            DateTime.to_naive(datetime)

          _ ->
            case parse_naive_datetime_string(value) do
              {:ok, naive_datetime} -> naive_datetime
              :error -> fallback
            end
        end
    end
  end

  defp excel_serial_to_naive_datetime(value) when is_integer(value) do
    excel_serial_to_naive_datetime(value * 1.0)
  end

  defp excel_serial_to_naive_datetime(value) when is_float(value) do
    days = trunc(value)
    seconds = trunc((value - days) * 86_400)
    NaiveDateTime.add(~N[1900-01-01 00:00:00], (days - 2) * 86_400 + seconds, :second)
  end

  defp parse_naive_datetime_string(value) do
    case DateTime.from_iso8601(value) do
      {:error, :missing_offset} ->
        case NaiveDateTime.from_iso8601(value) do
          {:ok, naive_datetime} -> {:ok, naive_datetime}
          _ -> :error
        end

      _ ->
        case Date.from_iso8601(value) do
          {:ok, date} ->
            {:ok, NaiveDateTime.new!(date, ~T[00:00:00])}

          _ ->
            parse_custom_naive_datetime(value)
        end
    end
  end

  defp parse_custom_naive_datetime(value) do
    case Regex.named_captures(@year_first_pattern, value) do
      captures when is_map(captures) ->
        build_naive_datetime(captures)

      _ ->
        case Regex.named_captures(@day_first_pattern, value) do
          captures when is_map(captures) -> build_naive_datetime(captures)
          _ -> :error
        end
    end
  end

  defp build_naive_datetime(captures) do
    with year when is_integer(year) <- to_integer(Map.get(captures, "year"), nil),
         month when is_integer(month) <- to_integer(Map.get(captures, "month"), nil),
         day when is_integer(day) <- to_integer(Map.get(captures, "day"), nil),
         hour when is_integer(hour) <- to_integer(Map.get(captures, "hour"), 0),
         minute when is_integer(minute) <- to_integer(Map.get(captures, "minute"), 0),
         second when is_integer(second) <- to_integer(Map.get(captures, "second"), 0),
         {:ok, date} <- Date.new(year, month, day),
         {:ok, time} <- Time.new(hour, minute, second),
         {:ok, naive_datetime} <- NaiveDateTime.new(date, time) do
      {:ok, naive_datetime}
    else
      _ -> :error
    end
  end

  # Color preview

  defp color_preview(color) do
    with {:ok, srgb} <-
           (case color do
              %NativeColor.SRGB{} -> {:ok, color}
              %NativeColor.HSL{} -> NativeColor.HSL.to_srgb(color)
              %NativeColor.CMYK{} -> NativeColor.CMYK.to_srgb(color)
              color -> NativeColor.Gamut.to_gamut(color, :SRGB, method: :oklch)
            end) do
      srgb = %{
        srgb
        | r: srgb.r |> max(0.0) |> min(1.0),
          g: srgb.g |> max(0.0) |> min(1.0),
          b: srgb.b |> max(0.0) |> min(1.0),
          alpha: (srgb.alpha || 1.0) |> max(0.0) |> min(1.0)
      }

      {:ok,
       %{
         swatch: NativeColor.CSS.to_css(srgb),
         rgba: %{r: srgb.r * 255, g: srgb.g * 255, b: srgb.b * 255, a: srgb.alpha},
         srgb: srgb
       }}
    end
  end
end

defmodule Poppybit.CoreUtils.Parse.Color do
  @moduledoc false

  use Ash.Type

  alias Poppybit.CoreUtils.Parse

  @impl true
  def storage_type(_constraints), do: :string

  @impl true
  def matches_type?(value, _constraints), do: is_binary(value)

  @impl true
  def cast_input(value, _constraints) do
    case Parse.inspect_color(value) do
      {:ok, nil} -> {:ok, nil}
      {:ok, color} -> {:ok, color.value}
      {:error, _} = error -> error
    end
  end

  @impl true
  def cast_stored(value, constraints), do: cast_input(value, constraints)

  @impl true
  def dump_to_native(value, constraints), do: cast_input(value, constraints)
end

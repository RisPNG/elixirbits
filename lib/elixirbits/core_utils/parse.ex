defmodule Elixirbits.CoreUtils.Parse do
  @moduledoc false

  @year_first_pattern ~r/^(?<year>\d{4})[-\/](?<month>\d{1,2})[-\/](?<day>\d{1,2})(?:[ T](?<hour>\d{1,2}):(?<minute>\d{2})(?::(?<second>\d{2}))?)?$/
  @day_first_pattern ~r/^(?<day>\d{1,2})[\/-](?<month>\d{1,2})[\/-](?<year>\d{4})(?:[ T](?<hour>\d{1,2}):(?<minute>\d{2})(?::(?<second>\d{2}))?)?$/
  @numeric_pattern ~r/^\d+(\.\d+)?$/

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
end

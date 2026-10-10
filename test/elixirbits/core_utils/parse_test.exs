defmodule Elixirbits.CoreUtils.ParseTest do
  use ExUnit.Case, async: true

  alias Elixirbits.CoreUtils.Parse
  alias Decimal, as: D

  test "to_integer handles scalar, structured, and fallback inputs" do
    assert Parse.to_integer(10) == 10
    assert Parse.to_integer(10.9) == 11
    assert Parse.to_integer(D.new("15.4")) == 15
    assert Parse.to_integer("123") == 123
    assert Parse.to_integer("42.6") == 43
    assert Parse.to_integer([42.5]) == 43
    assert Parse.to_integer(true) == 1
    assert Parse.to_integer(false) == 0
    assert Parse.to_integer(~U[2023-02-01 05:00:00Z]) == 1_675_227_600
    assert Parse.to_integer(~D[2023-02-01]) == 738_917
    assert Parse.to_integer("invalid") == 0
    assert Parse.to_integer("invalid", nil) == nil
    assert Parse.to_integer(nil, nil) == nil
  end

  test "to_datetime handles nil and fallback" do
    fallback = ~U[0001-01-01 00:00:00Z]

    assert Parse.to_datetime(nil) == nil
    assert Parse.to_datetime("invalid", fallback: fallback) == fallback
  end

  test "to_decimal converts form values without losing explicit invalid-input fallbacks" do
    assert Parse.to_decimal(D.new("15.40")) == D.new("15.40")
    assert Parse.to_decimal(12) == D.new(12)
    assert Parse.to_decimal(12.5) == D.new("12.5")
    assert Parse.to_decimal(" 42.60 ") == D.new("42.60")
    assert Parse.to_decimal(["42.5"]) == D.new("42.5")
    assert Parse.to_decimal(true) == D.new(1)
    assert Parse.to_decimal(false) == D.new(0)
    assert Parse.to_decimal("invalid", nil) == nil
    assert Parse.to_decimal([1, 2], nil) == nil
    assert Parse.to_decimal(nil) == D.new(0)
  end

  test "datetime precision is preserved unless explicitly reduced" do
    datetime = ~U[2023-02-01 05:00:00.123456Z]
    naive = ~N[2023-02-01 05:00:00.123456]

    assert Parse.to_datetime(datetime) == datetime
    assert Parse.to_datetime("2023-02-01T05:00:00.123456Z") == datetime
    assert Parse.to_datetime(datetime, precision: :second) == ~U[2023-02-01 05:00:00Z]

    assert Parse.to_datetime("2023-02-01T05:00:00.123456Z", precision: :second) ==
             ~U[2023-02-01 05:00:00Z]

    assert Parse.to_naive_datetime(naive) == naive
    assert Parse.to_naive_datetime(naive, precision: :second) == ~N[2023-02-01 05:00:00]
  end

  test "datetime-local values round-trip in their explicitly selected timezone" do
    utc = ~U[2026-07-13 02:00:00Z]

    input =
      utc |> DateTime.shift_zone!("Asia/Kuala_Lumpur") |> Calendar.strftime("%Y-%m-%dT%H:%M")

    assert input == "2026-07-13T10:00"
    assert Parse.to_datetime(input, source_timezone: "Asia/Kuala_Lumpur") == utc
  end

  test "explicit offsets retain their instant and microseconds independently of the source timezone" do
    assert Parse.to_datetime("2026-07-13T10:00:00.123456+08:00",
             source_timezone: "America/New_York"
           ) == ~U[2026-07-13 02:00:00.123456Z]

    assert Parse.to_datetime(
             DateTime.shift_zone!(~U[2026-07-13 02:00:00.123456Z], "Asia/Kuala_Lumpur")
           ) == ~U[2026-07-13 02:00:00.123456Z]
  end

  test "local DST gaps and overlaps return explicit errors without choosing an instant" do
    opts = [source_timezone: "America/New_York", on_invalid: :error]

    assert Parse.to_datetime("2026-03-08T02:30:00.123456", opts) ==
             {:error, :nonexistent_datetime}

    assert Parse.to_datetime(~N[2026-11-01 01:30:00.123456], opts) ==
             {:error, :ambiguous_datetime}

    assert Parse.to_datetime("not a datetime", opts) == {:error, :invalid_datetime}
    assert Parse.to_datetime(nil, opts) == nil

    assert Parse.to_datetime("2026-03-08T02:30", source_timezone: "America/New_York") == nil

    fallback = ~U[2026-01-01 00:00:00Z]

    assert Parse.to_datetime("2026-11-01T01:30",
             source_timezone: "America/New_York",
             fallback: fallback
           ) == fallback

    assert Parse.to_datetime("2026-11-01T01:30:00.123456-04:00", opts) ==
             ~U[2026-11-01 05:30:00.123456Z]

    assert Parse.to_datetime("2026-11-01T01:30:00.123456-05:00", opts) ==
             ~U[2026-11-01 06:30:00.123456Z]
  end

  test "invalid explicit offsets cannot fall back to local clock interpretation" do
    for suffix <- ["+99:99", "+25:00", "Zsuffix"] do
      value = "2026-07-13T10:00:00.123456" <> suffix

      assert Parse.to_datetime(value,
               source_timezone: "Asia/Kuala_Lumpur",
               on_invalid: :error
             ) == {:error, :invalid_datetime}

      assert Parse.to_naive_datetime(value, target_timezone: "Asia/Kuala_Lumpur") == nil
    end
  end

  test "to_datetime parses Excel serial values" do
    assert Parse.to_datetime("44601.75") == ~U[2022-02-09 18:00:00Z]
    assert Parse.to_datetime(44601.75) == ~U[2022-02-09 18:00:00Z]
  end

  test "to_datetime parses non-ISO date formats and naive values interpreted in the source timezone" do
    assert Parse.to_datetime("31/01/2023 14:05:06") == ~U[2023-01-31 14:05:06Z]

    assert Parse.to_datetime(
             "2023-02-01 05:00:00",
             source_timezone: "Asia/Kuala_Lumpur",
             target_timezone: "Etc/UTC"
           ) == ~U[2023-01-31 21:00:00Z]
  end

  test "to_naive_datetime handles fallback, Excel serial, and custom formats" do
    fallback = ~N[0001-01-01 00:00:00]

    assert Parse.to_naive_datetime("invalid", fallback: fallback) == fallback
    assert Parse.to_naive_datetime("44601.75") == ~N[2022-02-09 18:00:00]
    assert Parse.to_naive_datetime("31-01-2023 14:05") == ~N[2023-01-31 14:05:00]
  end

  test "to_naive_datetime can shift zoned datetimes before dropping timezone" do
    assert Parse.to_naive_datetime(
             ~U[2023-02-01 05:00:00Z],
             target_timezone: "Asia/Kuala_Lumpur"
           ) == ~N[2023-02-01 13:00:00]

    assert Parse.to_naive_datetime("2023-02-01T13:00:00.123456+08:00",
             target_timezone: "America/New_York"
           ) == ~N[2023-02-01 00:00:00.123456]

    assert Parse.to_naive_datetime("2023-02-01T13:00:00.123456+08:00") ==
             ~N[2023-02-01 05:00:00.123456]
  end
end

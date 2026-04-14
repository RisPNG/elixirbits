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

  test "to_datetime parses excel serial values" do
    assert Parse.to_datetime("44601.75") == ~U[2022-02-09 18:00:00Z]
    assert Parse.to_datetime(44601.75) == ~U[2022-02-09 18:00:00Z]
  end

  test "to_datetime parses non-iso date formats and source timezone aware naive values" do
    assert Parse.to_datetime("31/01/2023 14:05:06") == ~U[2023-01-31 14:05:06Z]

    assert Parse.to_datetime(
             "2023-02-01 05:00:00",
             source_timezone: "Asia/Kuala_Lumpur",
             target_timezone: "Etc/UTC"
           ) == ~U[2023-01-31 21:00:00Z]
  end

  test "to_naive_datetime handles fallback, excel serial, and custom formats" do
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
  end
end

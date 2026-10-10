defmodule Elixirbits.CoreUtils.SearchDatetimeTest do
  use ExUnit.Case, async: true

  alias Elixirbits.CoreUtils.Search
  alias Elixirbits.CoreUtils.SearchDatetimeTest.Domain
  alias Elixirbits.CoreUtils.SearchDatetimeTest.Record

  test "local date comparisons cover 23-hour and 25-hour days and the final microsecond" do
    for {day, start, next_day} <- [
          {~D[2026-03-08], ~U[2026-03-08 05:00:00Z], ~U[2026-03-09 04:00:00Z]},
          {~D[2026-11-01], ~U[2026-11-01 04:00:00Z], ~U[2026-11-02 05:00:00Z]}
        ] do
      name = Date.to_iso8601(day)

      [before, first, last, following] =
        Enum.map(
          [
            DateTime.add(start, -1, :microsecond),
            start,
            DateTime.add(next_day, -1, :microsecond),
            next_day
          ],
          fn instant ->
            Ash.create!(Record, %{name: name, at: instant, native_at: instant}, domain: Domain)
          end
        )

      for field <- [:at, :native_at],
          {filter, expected} <- [
            {[day, day, "range"], [first, last]},
            {[day, day, "not_range"], [before, following]},
            {[day, "before"], [before]},
            {[day, "before_equal"], [before, first, last]},
            {[day, "after"], [following]},
            {[day, "after_equal"], [first, last, following]}
          ] do
        result =
          Search.search(
            module: Record,
            user_timezone: "America/New_York",
            args: %{field => filter, name: [name, "exact"]}
          )

        assert Enum.sort(Enum.map(result.entries, & &1.id)) ==
                 Enum.sort(Enum.map(expected, & &1.id))
      end

      result =
        Search.search(
          module: Record,
          user_timezone: "America/New_York",
          args: %{name: [name, "exact"], at: [start, "before_equal"]}
        )

      assert Enum.sort(Enum.map(result.entries, & &1.id)) == Enum.sort([before.id, first.id])
    end
  end

  test "date boundaries include midnight gaps and both occurrences of an ambiguous midnight" do
    for {timezone, day, start, next_day} <- [
          {"America/Santiago", ~D[2026-09-06], ~U[2026-09-06 04:00:00Z],
           ~U[2026-09-07 03:00:00Z]},
          {"America/Havana", ~D[2026-11-01], ~U[2026-11-01 04:00:00Z], ~U[2026-11-02 05:00:00Z]}
        ] do
      records =
        Enum.map(
          [
            DateTime.add(start, -1, :microsecond),
            start,
            DateTime.add(start, 30, :minute),
            DateTime.add(start, 90, :minute),
            DateTime.add(next_day, -1, :microsecond),
            next_day
          ],
          fn instant ->
            Ash.create!(Record, %{name: timezone, at: instant}, domain: Domain)
          end
        )

      result =
        Search.search(
          module: Record,
          user_timezone: timezone,
          args: %{name: [timezone, "exact"], at: [Date.to_iso8601(day), day, "range"]}
        )

      assert Enum.sort(Enum.map(result.entries, & &1.id)) ==
               records |> Enum.slice(1, 4) |> Enum.map(& &1.id) |> Enum.sort()
    end
  end

  test "a skipped local calendar date contains no instants" do
    following = ~U[2011-12-30 10:00:00Z]

    Ash.create!(Record, %{at: DateTime.add(following, -1, :microsecond)}, domain: Domain)
    Ash.create!(Record, %{at: following}, domain: Domain)

    result =
      Search.search(
        module: Record,
        user_timezone: "Pacific/Apia",
        args: %{at: ["2011-12-30", "2011-12-30", "range"]}
      )

    assert result.entries == []
  end
end

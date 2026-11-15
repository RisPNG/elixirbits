defmodule Elixirbits.CoreUtils.Resource.SearchTest do
  use ExUnit.Case, async: true

  alias Elixirbits.CoreUtils.Resource, as: CoreResource
  alias Elixirbits.CoreUtils.Resource.Search
  alias Elixirbits.SearchTest.Record

  describe "utility helpers" do
    test "shared metadata reflects Ash types" do
      assert CoreResource.normalize_type(Ash.Type.String) == :string
      assert CoreResource.normalize_type({:array, Ash.Type.String}) == {:array, :string}
    end

    test "option filtering controls whitespace, exact matching, and case sensitivity" do
      options = [{"Picture Frame", 1}, {"pic ture", 2}, {"Pitcher", 3}]

      assert Search.filter(options, "") == options
      assert Search.filter(options, nil) == options
      assert Search.filter(options, "pic ture") == [{"Picture Frame", 1}, {"pic ture", 2}]
      assert Search.filter(options, "FRAME") == [{"Picture Frame", 1}]
      assert Search.filter(options, "FRAME", case_sensitive: true) == []
      assert Search.filter(options, "picture frame", exact: true) == [{"Picture Frame", 1}]
      assert Search.filter(options, "pictureframe", exact: true) == []

      options =
        Elixirbits.CoreUtils.Options.AddressLabel.values()
        |> Enum.map(&{Phoenix.Naming.humanize(&1), to_string(&1)})

      assert Search.filter(options, "oth") == [{"Other", "OTHER"}]
    end

    test "detect_schema_field? reflects resource metadata" do
      assert CoreResource.detect_schema_field?(Record, :name) == :string
      assert CoreResource.detect_schema_field?(Record, :amount) == :decimal
      assert CoreResource.detect_schema_field?(Record, :tags) == {:array, :string}
    end

    test "convert_value_to_field handles date and datetime conversions" do
      assert CoreResource.convert_value_to_field(Record, :due_date, "2023-02-01") ==
               ~D[2023-02-01]

      assert CoreResource.convert_value_to_field(Record, :due_date, "") == nil

      naive = ~N[2023-02-01 10:30:00]

      utc_from_naive =
        CoreResource.convert_value_to_field(Record, :shipped_at, naive, "Asia/Kuala_Lumpur")

      assert utc_from_naive.time_zone == "Etc/UTC"

      existing = ~U[2023-02-01 05:00:00Z]
      assert CoreResource.convert_value_to_field(Record, :shipped_at, existing) == existing

      parsed =
        CoreResource.convert_value_to_field(
          Record,
          :shipped_at,
          "2023-02-01T05:00:00",
          "Asia/Kuala_Lumpur"
        )

      assert parsed.time_zone == "Etc/UTC"

      assert CoreResource.convert_value_to_field(Record, :published_at, "2023-02-01T05:00:00") ==
               ~N[2023-02-01 05:00:00]

      assert CoreResource.convert_value_to_field(Record, :opens_at, "11:59:00") == ~T[11:59:00]
    end

    test "convert_value_to_field handles numeric, decimal, boolean, text, and list types" do
      assert CoreResource.convert_value_to_field(Record, :count, "7") == 7
      assert_in_delta CoreResource.convert_value_to_field(Record, :rating, "4.75"), 4.75, 0.0001

      assert CoreResource.convert_value_to_field(Record, :amount, "15.10") == Decimal.new("15.10")
      assert CoreResource.convert_value_to_field(Record, :amount, 22.5) == Decimal.new("22.5")
      assert CoreResource.convert_value_to_field(Record, :active, true)
      refute CoreResource.convert_value_to_field(Record, :active, "false")
      assert CoreResource.convert_value_to_field(Record, :active, "maybe") == nil

      assert CoreResource.convert_value_to_field(Record, :name, 123) == "123"
      binary = <<1, 2>>
      assert CoreResource.convert_value_to_field(Record, :code, binary) == binary
      assert CoreResource.convert_value_to_field(Record, :code, 123) == 123
      map_value = %{"k" => "v"}
      assert CoreResource.convert_value_to_field(Record, :meta, map_value) == map_value

      list_value = ["a", "b"]
      assert CoreResource.convert_value_to_field(Record, :tags, list_value) == list_value
    end

    test "construct_date_map handles atom and string keys" do
      assert Search.construct_date_map("2023-01-01", "2023-01-03", :due_date) ==
               %{due_date: ["2023-01-01", "2023-01-03", "range"]}

      assert Search.construct_date_map("2023-01-01", nil, :due_date) ==
               %{due_date: ["2023-01-01", "after_equal"]}

      assert Search.construct_date_map(nil, "2023-01-02", :due_date) ==
               %{due_date: ["2023-01-02", "before_equal"]}

      assert Search.construct_date_map(nil, nil, :due_date) == %{due_date: []}

      assert Search.construct_date_map("2023-01-01", "2023-01-02", "due_date") ==
               %{"due_date" => ["2023-01-01", "2023-01-02", "range"]}
    end

    test "construct_date_list mirrors map helper semantics" do
      assert Search.construct_date_list("2023-01-01", "2023-01-03") ==
               ["2023-01-01", "2023-01-03", "range"]

      assert Search.construct_date_list("2023-01-01", nil) == ["2023-01-01", "after_equal"]
      assert Search.construct_date_list(nil, "2023-01-03") == ["2023-01-03", "before_equal"]
      assert Search.construct_date_list(nil, nil) == []
    end
  end
end

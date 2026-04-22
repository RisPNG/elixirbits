defmodule Elixirbits.CoreUtils.SearchTest do
  use Elixirbits.DataCase, async: true

  @domain Elixirbits.SearchTest.Domain

  alias Elixirbits.CoreUtils
  alias Elixirbits.CoreUtils.Resource, as: CoreResource
  alias Elixirbits.CoreUtils.Search
  alias Elixirbits.Repo
  alias Elixirbits.SearchTest.Category
  alias Elixirbits.SearchTest.Record

  setup_all do
    Ecto.Adapters.SQL.Sandbox.unboxed_run(Repo, fn ->
      Repo.query!("""
      CREATE TABLE IF NOT EXISTS search_test_categories (
        id serial PRIMARY KEY,
        name text,
        code text,
        inserted_at timestamptz DEFAULT now(),
        updated_at timestamptz DEFAULT now()
      )
      """)

      Repo.query!("""
      CREATE TABLE IF NOT EXISTS search_test_records (
        id serial PRIMARY KEY,
        name text,
        description text,
        count integer,
        secondary_count integer,
        rating double precision,
        amount numeric,
        due_date date,
        shipped_at timestamptz,
        published_at timestamp without time zone,
        opens_at time without time zone,
        active boolean,
        meta jsonb DEFAULT '{}'::jsonb,
        code bytea,
        tags text[] DEFAULT '{}',
        category_id integer REFERENCES search_test_categories(id),
        inserted_at timestamptz DEFAULT now(),
        updated_at timestamptz DEFAULT now()
      )
      """)
    end)

    on_exit(fn ->
      Ecto.Adapters.SQL.Sandbox.unboxed_run(Repo, fn ->
        Repo.query!("DROP TABLE IF EXISTS search_test_records")
        Repo.query!("DROP TABLE IF EXISTS search_test_categories")
      end)
    end)

    :ok
  end

  defp category_fixture(attrs \\ %{}) do
    unique = System.unique_integer([:positive])

    defaults = %{
      name: "Category #{unique}",
      code: "CAT-#{unique}"
    }

    attrs = Map.merge(defaults, attrs)

    Ash.create!(Category, attrs, domain: @domain)
  end

  defp record_fixture(attrs \\ %{}) do
    category = Map.get(attrs, :category) || category_fixture()
    attrs = Map.delete(attrs, :category)

    defaults = %{
      name: "Item #{System.unique_integer([:positive])}",
      description: "Test record",
      count: 10,
      secondary_count: 3,
      rating: 4.5,
      amount: Decimal.new("12.34"),
      due_date: ~D[2023-01-15],
      shipped_at: ~U[2023-01-15 00:00:00Z],
      published_at: ~N[2023-01-10 10:30:00],
      opens_at: ~T[09:00:00],
      active: true,
      meta: %{"key" => "value"},
      code: <<1, 2, 3>>,
      tags: ["alpha", "beta"],
      category_id: category.id
    }

    params = Map.merge(defaults, attrs)

    Ash.create!(Record, params, domain: @domain)
  end

  describe "search/1 basic filtering" do
    test "returns all entries when no filters applied" do
      record1 = record_fixture(%{name: "Alpha"})
      record2 = record_fixture(%{name: "Beta"})

      result = Search.search(module: Record, args: %{})

      assert Enum.map(result.entries, & &1.id) |> Enum.sort() ==
               Enum.sort([record1.id, record2.id])

      assert result.page_number == 1
      assert result.page_size == 2
      assert result.total_entries == 2
      assert result.total_pages == 1
    end

    test "filters string fields using case-insensitive matching" do
      matching = record_fixture(%{name: "Searchable"})
      record_fixture(%{name: "Irrelevant"})

      result =
        Search.search(
          module: Record,
          args: %{name: "search"}
        )

      assert Enum.map(result.entries, & &1.id) == [matching.id]
    end

    test "filters numeric fields using equality" do
      record_fixture(%{count: 7})
      target = record_fixture(%{count: 42})

      result =
        Search.search(
          module: Record,
          args: %{count: 42}
        )

      assert Enum.map(result.entries, & &1.id) == [target.id]
    end

    test "ignores blank and sentinel filter values" do
      record1 = record_fixture(%{name: "Any"})
      record2 = record_fixture(%{name: "Thing"})

      result =
        Search.search(
          module: Record,
          args: %{name: "", description: nil, count: -1, secondary_count: "-1", tags: []}
        )

      assert Enum.map(result.entries, & &1.id) |> Enum.sort() ==
               Enum.sort([record1.id, record2.id])
    end

    test "drops sensitive args and custom drop_args" do
      matching = record_fixture(%{name: "Secured"})
      record_fixture(%{name: "Other"})

      result =
        Search.search(
          module: Record,
          args: %{name: "secured", hashed_password: "ignored", secret: "ignored"},
          drop_args: [:secret]
        )

      assert Enum.map(result.entries, & &1.id) == [matching.id]
    end

    test "raises when referencing unknown associations" do
      assert_raise RuntimeError, fn ->
        Search.search(module: Record, args: %{name@unknown: "value"})
      end
    end

    test "accepts association filters expressed with string keys" do
      category = category_fixture(%{name: "String Assoc"})
      matching = record_fixture(%{name: "Matches", category: category})
      record_fixture(%{name: "Miss", category: category_fixture()})

      result =
        Search.search(
          module: Record,
          args: %{"name@category" => "string assoc"}
        )

      assert Enum.map(result.entries, & &1.id) == [matching.id]
    end
  end

  describe "search/1 list filters" do
    test "applies unkeyworded list filters with AND semantics even when use_or is true" do
      both = record_fixture(%{name: "Alpha Beta"})
      only_alpha = record_fixture(%{name: "Alpha"})

      result_and =
        Search.search(
          module: Record,
          args: %{name: ["alpha", "beta"]}
        )

      assert Enum.map(result_and.entries, & &1.id) == [both.id]

      result_or =
        Search.search(
          module: Record,
          args: %{name: ["alpha", "beta"]},
          use_or: true
        )

      assert Enum.map(result_or.entries, & &1.id) == [both.id]
      refute Enum.any?(result_or.entries, &(&1.id == only_alpha.id))
    end

    test "supports range keyword on numeric fields" do
      inside = record_fixture(%{count: 5})
      record_fixture(%{count: 20})

      result =
        Search.search(
          module: Record,
          args: %{count: ["4", "10", "range"]}
        )

      assert Enum.map(result.entries, & &1.id) == [inside.id]
    end

    test "supports not_range keyword on numeric fields" do
      record_fixture(%{count: 5})
      outside = record_fixture(%{count: 20})

      result =
        Search.search(
          module: Record,
          args: %{count: ["4", "10", "not_range"]}
        )

      assert Enum.map(result.entries, & &1.id) == [outside.id]
    end

    test "supports temporal keywords on date fields" do
      after_only = record_fixture(%{due_date: ~D[2023-01-25]})
      equal = record_fixture(%{due_date: ~D[2023-01-20]})
      record_fixture(%{due_date: ~D[2023-01-10]})

      result_after =
        Search.search(
          module: Record,
          args: %{due_date: ["2023-01-21", "after"]}
        )

      assert Enum.map(result_after.entries, & &1.id) == [after_only.id]

      result_after_equal =
        Search.search(
          module: Record,
          args: %{due_date: ["2023-01-20", "after_equal"]}
        )

      assert Enum.map(result_after_equal.entries, & &1.id) |> Enum.sort() ==
               Enum.sort([after_only.id, equal.id])

      result_before =
        Search.search(
          module: Record,
          args: %{due_date: ["2023-01-20", "before"]}
        )

      assert Enum.all?(result_before.entries, fn record -> record.due_date < ~D[2023-01-20] end)

      result_before_equal =
        Search.search(
          module: Record,
          args: %{due_date: ["2023-01-20", "before_equal"]}
        )

      assert Enum.any?(result_before_equal.entries, &(&1.id == equal.id))
    end

    test "supports temporal keywords on utc datetime fields and adjusts range end" do
      inside = record_fixture(%{shipped_at: ~U[2023-01-10 05:30:00Z]})
      later = record_fixture(%{shipped_at: ~U[2023-01-11 00:00:01Z]})

      result_before_equal =
        Search.search(
          module: Record,
          args: %{shipped_at: ["2023-01-10", "before_equal"]}
        )

      assert Enum.map(result_before_equal.entries, & &1.id) == [inside.id]

      result_after_equal =
        Search.search(
          module: Record,
          args: %{shipped_at: [inside.shipped_at, "after_equal"]}
        )

      assert Enum.map(result_after_equal.entries, & &1.id) |> Enum.sort() ==
               Enum.sort([inside.id, later.id])
    end

    test "supports not keyword for exact and fuzzy types" do
      record_fixture(%{count: 10, name: "Alpha"})
      remaining = record_fixture(%{count: 20, name: "Bravo"})

      result_int =
        Search.search(
          module: Record,
          args: %{count: ["10", "not"]}
        )

      assert Enum.map(result_int.entries, & &1.id) == [remaining.id]

      result_string =
        Search.search(
          module: Record,
          args: %{name: ["alpha", "not"]}
        )

      assert Enum.map(result_string.entries, & &1.id) == [remaining.id]
    end

    test "supports exact_not keyword for string fields" do
      record_fixture(%{name: "Alpha"})
      survivor = record_fixture(%{name: "Bravo"})

      result =
        Search.search(
          module: Record,
          args: %{name: ["Alpha", "exact_not"]}
        )

      assert Enum.map(result.entries, & &1.id) == [survivor.id]
    end

    test "supports or and exact_or keywords" do
      alpha = record_fixture(%{name: "Alpha"})
      beta = record_fixture(%{name: "Beta"})

      result_or =
        Search.search(
          module: Record,
          args: %{name: ["Alpha", "Beta", "or"]}
        )

      assert Enum.map(result_or.entries, & &1.id) |> Enum.sort() == Enum.sort([alpha.id, beta.id])

      result_exact_or =
        Search.search(
          module: Record,
          args: %{name: ["Alpha", "alpha", "exact_or"]}
        )

      assert Enum.map(result_exact_or.entries, & &1.id) == [alpha.id]
    end

    test "supports exact_not, exact_or, and exact_and for exact-type fields" do
      keep = record_fixture(%{count: 30})
      record_fixture(%{count: 10})
      record_fixture(%{count: 20})

      result_exact_not =
        Search.search(
          module: Record,
          args: %{count: ["10", "20", "exact_not"]}
        )

      assert Enum.map(result_exact_not.entries, & &1.id) == [keep.id]

      or_a = record_fixture(%{count: 7})
      or_b = record_fixture(%{count: 9})

      result_exact_or =
        Search.search(
          module: Record,
          args: %{count: ["7", "9", "exact_or"]}
        )

      assert Enum.map(result_exact_or.entries, & &1.id) |> Enum.sort() ==
               Enum.sort([or_a.id, or_b.id])

      duplicated = record_fixture(%{count: 11})

      result_exact_and =
        Search.search(
          module: Record,
          args: %{count: ["11", "11", "exact_and"]}
        )

      assert Enum.map(result_exact_and.entries, & &1.id) == [duplicated.id]
    end

    test "supports and and exact_and keywords" do
      match = record_fixture(%{description: "alpha beta"})
      record_fixture(%{description: "alpha only"})

      result_and =
        Search.search(
          module: Record,
          args: %{description: ["alpha", "beta", "and"]}
        )

      assert Enum.map(result_and.entries, & &1.id) == [match.id]

      exact = record_fixture(%{name: "Exact"})

      result_exact_and =
        Search.search(
          module: Record,
          args: %{name: ["Exact", "Exact", "exact_and"]}
        )

      assert Enum.map(result_exact_and.entries, & &1.id) == [exact.id]
    end

    test "supports array field matching" do
      both = record_fixture(%{tags: ["alpha", "beta"]})
      alpha = record_fixture(%{tags: ["alpha"]})

      result_and =
        Search.search(
          module: Record,
          args: %{tags: ["alpha", "beta"]}
        )

      assert Enum.map(result_and.entries, & &1.id) == [both.id]

      result_or =
        Search.search(
          module: Record,
          args: %{tags: ["alpha", "beta", "or"]}
        )

      assert Enum.map(result_or.entries, & &1.id) |> Enum.sort() ==
               Enum.sort([both.id, alpha.id])
    end

    test "ignores list filters made solely of blank values" do
      record1 = record_fixture(%{name: "Alpha"})
      record2 = record_fixture(%{name: "Beta"})

      result =
        Search.search(
          module: Record,
          args: %{name: ["", "", "or"]}
        )

      assert Enum.map(result.entries, & &1.id) |> Enum.sort() ==
               Enum.sort([record1.id, record2.id])
    end

    test "ignores malformed range and temporal keyword lists" do
      record1 = record_fixture(%{count: 1, due_date: ~D[2023-01-01]})
      record2 = record_fixture(%{count: 2, due_date: ~D[2023-01-02]})

      range_result =
        Search.search(
          module: Record,
          args: %{count: ["5", "range"]}
        )

      assert Enum.map(range_result.entries, & &1.id) |> Enum.sort() ==
               Enum.sort([record1.id, record2.id])

      temporal_result =
        Search.search(
          module: Record,
          args: %{due_date: ["2023-01-01", "2023-01-02", "before"]}
        )

      assert Enum.map(temporal_result.entries, & &1.id) |> Enum.sort() ==
               Enum.sort([record1.id, record2.id])
    end
  end

  describe "search/1 field operations" do
    test "applies _fields_diff when provided sufficient field atoms" do
      match = record_fixture(%{count: 20, secondary_count: 10})
      record_fixture(%{count: 12, secondary_count: 10})

      result =
        Search.search(
          module: Record,
          args: %{_fields_diff: [:count, :secondary_count, "5", "after"]}
        )

      assert Enum.map(result.entries, & &1.id) == [match.id]
    end

    test "ignores _fields_diff when fewer than two fields present" do
      record1 = record_fixture(%{count: 5})
      record2 = record_fixture(%{count: 6})

      result =
        Search.search(
          module: Record,
          args: %{_fields_diff: [:count]}
        )

      assert Enum.map(result.entries, & &1.id) |> Enum.sort() ==
               Enum.sort([record1.id, record2.id])
    end

    test "applies _fields_sum thresholds" do
      match = record_fixture(%{count: 15, secondary_count: 10})
      record_fixture(%{count: 5, secondary_count: 5})

      result =
        Search.search(
          module: Record,
          args: %{_fields_sum: [:count, :secondary_count, "25", "after_equal"]}
        )

      assert Enum.map(result.entries, & &1.id) == [match.id]
    end

    test "ignores _fields_sum when no field atoms supplied" do
      record1 = record_fixture()
      record2 = record_fixture()

      result =
        Search.search(
          module: Record,
          args: %{_fields_sum: ["10", "after"]}
        )

      assert Enum.map(result.entries, & &1.id) |> Enum.sort() ==
               Enum.sort([record1.id, record2.id])
    end

    test "honors use_or for field operations" do
      record = record_fixture(%{active: true, count: 20, secondary_count: 10})

      result =
        Search.search(
          module: Record,
          args: %{active: false, _fields_diff: [:count, :secondary_count, "5", "after"]},
          use_or: true
        )

      assert Enum.map(result.entries, & &1.id) == [record.id]
    end
  end

  describe "search/1 OR filters" do
    test "applies _or filters with direct and association fields, dropping blanks" do
      cat1 = category_fixture(%{name: "Alpha Category"})
      cat2 = category_fixture(%{name: "Beta Category"})
      record1 = record_fixture(%{name: "Alpha", category: cat1})
      record2 = record_fixture(%{name: "Gamma", category: cat2})

      result =
        Search.search(
          module: Record,
          args: %{
            _or: %{
              name: "Alpha",
              name@category: "beta category",
              code@category: ""
            }
          }
        )

      assert Enum.map(result.entries, & &1.id) |> Enum.sort() ==
               Enum.sort([record1.id, record2.id])
    end

    test "leaves query untouched when _or filters become empty" do
      record1 = record_fixture(%{name: "Alpha"})
      record2 = record_fixture(%{name: "Beta"})

      result =
        Search.search(
          module: Record,
          args: %{_or: %{name: "", name@category: []}}
        )

      assert Enum.map(result.entries, & &1.id) |> Enum.sort() ==
               Enum.sort([record1.id, record2.id])
    end

    test "applies _multi_or filters with groups and association joins" do
      cat1 = category_fixture(%{name: "Group One"})
      cat2 = category_fixture(%{name: "Group Two"})
      record1 = record_fixture(%{name: "Alpha", count: 5, category: cat1})
      record2 = record_fixture(%{name: "Omega", count: 10, category: cat2})
      record_fixture(%{name: "Other", count: 20})

      result =
        Search.search(
          module: Record,
          args: %{
            _multi_or: [
              %{name: "Alpha", count: 5},
              %{name@category: "Group Two"},
              %{name: ""}
            ]
          }
        )

      assert Enum.map(result.entries, & &1.id) |> Enum.sort() ==
               Enum.sort([record1.id, record2.id])
    end

    test "ignores _multi_or when all groups empty" do
      record1 = record_fixture()
      record2 = record_fixture()

      result =
        Search.search(
          module: Record,
          args: %{_multi_or: [%{name: ""}, %{name@category: []}]}
        )

      assert Enum.map(result.entries, & &1.id) |> Enum.sort() ==
               Enum.sort([record1.id, record2.id])
    end
  end

  describe "search/1 ordering and pagination" do
    test "orders by single atom using provided order_method" do
      record_fixture(%{name: "Alpha"})
      later = record_fixture(%{name: "Zulu"})

      result =
        Search.search(
          module: Record,
          order_by: :name,
          order_method: :desc
        )

      assert Enum.map(result.entries, & &1.id) |> hd() == later.id
    end

    test "orders by list of atoms sharing the same direction" do
      low = record_fixture(%{name: "Alpha", count: 5})
      high = record_fixture(%{name: "Alpha", count: 10})

      result =
        Search.search(
          module: Record,
          order_by: [:name, :count],
          order_method: :desc
        )

      assert Enum.map(result.entries, & &1.id) |> hd() == high.id
      assert Enum.at(result.entries, 1).id == low.id
    end

    test "orders by mixed tuple list respecting individual directions" do
      a_low = record_fixture(%{name: "Alpha", count: 1})
      b_high = record_fixture(%{name: "Beta", count: 10})
      a_high = record_fixture(%{name: "Alpha", count: 5})

      result =
        Search.search(
          module: Record,
          order_by: [{:name, :asc}, {:count, :desc}]
        )

      ids = Enum.map(result.entries, & &1.id)
      assert ids == [a_high.id, a_low.id, b_high.id]
    end

    test "orders by association fields" do
      cat_a = category_fixture(%{code: "AAA"})
      cat_z = category_fixture(%{code: "ZZZ"})
      first = record_fixture(%{name: "One", category: cat_a})
      last = record_fixture(%{name: "Two", category: cat_z})

      result =
        Search.search(
          module: Record,
          order_by: :code@category
        )

      assert Enum.map(result.entries, & &1.id) == [first.id, last.id]
    end

    test "falls back to primary key ordering when given unsupported order_by" do
      first = record_fixture()
      second = record_fixture()

      result =
        Search.search(
          module: Record,
          order_by: "not-valid"
        )

      assert Enum.map(result.entries, & &1.id) == [first.id, second.id]
    end

    test "paginates results and reports metadata" do
      first = record_fixture(%{name: "Page 1"})
      second = record_fixture(%{name: "Page 2"})
      _third = record_fixture(%{name: "Page 3"})

      result =
        Search.search(
          module: Record,
          pagination: %{page: 2, per_page: 1}
        )

      assert Enum.map(result.entries, & &1.id) == [second.id]
      assert result.page_number == 2
      assert result.page_size == 1
      assert result.total_entries == 3
      assert result.total_pages == 3

      unpaged = Search.search(module: Record, order_by: :id)

      assert unpaged.page_number == 1
      assert unpaged.total_pages == 1
      assert length(unpaged.entries) == unpaged.page_size
      assert Enum.map(unpaged.entries, & &1.id) |> Enum.take(1) == [first.id]
    end
  end

  describe "search/1 preload handling" do
    test "supports explicit preload lists" do
      record_fixture(%{category: category_fixture()})

      result = Search.search(module: Record, preload: [:category])

      assert Enum.all?(result.entries, fn entry -> Ash.Resource.loaded?(entry, :category) end)
    end

    test "preload true loads direct relationships" do
      category = category_fixture()
      record_fixture(%{category: category})

      result = Search.search(module: Category, preload: true)

      assert Enum.all?(result.entries, fn entry -> Ash.Resource.loaded?(entry, :records) end)
    end

    test "preload disabled leaves associations as not loaded" do
      record_fixture(%{category: category_fixture()})

      result = Search.search(module: Record, preload: false)

      refute Enum.any?(result.entries, &Ash.Resource.loaded?(&1, :category))
    end

    test "ensure_loaded_associations loads specified and default relationships" do
      category = category_fixture()
      record_fixture(%{category: category})

      fresh = Ash.get!(Category, category.id, domain: @domain)
      refute Ash.Resource.loaded?(fresh, :records)

      skipped = CoreResource.ensure_loaded_associations(fresh, [:other])
      refute Ash.Resource.loaded?(skipped, :records)

      loaded = CoreResource.ensure_loaded_associations(fresh, [:records])
      assert Ash.Resource.loaded?(loaded, :records)

      loaded_default = CoreResource.ensure_loaded_associations(fresh)
      assert Ash.Resource.loaded?(loaded_default, :records)
    end
  end

  describe "utility helpers" do
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

    test "extract_square_bracket_from_string picks indexed segment" do
      id = "ID[alpha][beta][]"

      assert CoreUtils.extract_square_bracket_from_string(id, 0) == "alpha"
      assert CoreUtils.extract_square_bracket_from_string(id, 1) == "beta"
      assert CoreUtils.extract_square_bracket_from_string(id, 2) == nil
    end
  end
end

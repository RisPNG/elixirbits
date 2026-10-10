defmodule Elixirbits.NumberingTest do
  use Elixirbits.DataCase, async: true

  alias Elixirbits.Numbering

  test "allocations are independent across document types and complete calendar dates" do
    doc_type = Ash.UUID.generate()
    other_type = Ash.UUID.generate()

    assert Numbering.next_number(doc_type, ~D[2026-06-18]) == "#{doc_type}-20260618-00001"
    assert Numbering.next_number(doc_type, ~D[2026-06-18]) == "#{doc_type}-20260618-00002"
    assert Numbering.next_number(other_type, ~D[2026-06-18]) == "#{other_type}-20260618-00001"
    assert Numbering.next_number(doc_type, ~D[2027-06-18]) == "#{doc_type}-20270618-00001"
  end

  test "instant-based allocation follows the selected timezone at a year boundary" do
    doc_type = Ash.UUID.generate()
    instant = ~U[2026-12-31 18:00:00Z]

    assert Numbering.next_number(doc_type, instant, timezone: "Asia/Kuala_Lumpur") ==
             "#{doc_type}-20270101-00001"

    assert Numbering.next_number(doc_type, instant, timezone: "Etc/UTC") ==
             "#{doc_type}-20261231-00001"
  end

  test "formatting options never change the allocated counter" do
    doc_type = Ash.UUID.generate()
    opts = [prefix: "INV", suffix: "MY", separator: "/", padding: 3, start: 99, increment: 99]

    assert Numbering.next_number(doc_type, ~D[2026-06-18], opts) == "INV/001/MY"
    assert Numbering.next_number(doc_type, ~D[2026-06-18], opts) == "INV/002/MY"
  end
end

defmodule Elixirbits.NumberingConcurrencyTest do
  use ExUnit.Case, async: false
  import Ecto.Query

  alias Ecto.Adapters.SQL.Sandbox
  alias Elixirbits.Numbering
  alias Elixirbits.Repo

  test "independent connections allocate each counter once under contention" do
    doc_type = "concurrent-#{Ash.UUID.generate()}"

    on_exit(fn ->
      Sandbox.unboxed_run(Repo, fn ->
        Repo.delete_all(
          from sequence in "number_sequences", where: sequence.doc_type == ^doc_type
        )
      end)
    end)

    numbers =
      1..12
      |> Task.async_stream(
        fn _index ->
          Sandbox.unboxed_run(Repo, fn -> Numbering.next_number(doc_type, ~D[2026-06-18]) end)
        end,
        max_concurrency: 4,
        timeout: 15_000
      )
      |> Enum.map(fn {:ok, number} -> number end)

    expected =
      Enum.map(1..12, fn counter ->
        "#{doc_type}-20260618-#{String.pad_leading(to_string(counter), 5, "0")}"
      end)

    assert Enum.sort(numbers) == expected
  end
end

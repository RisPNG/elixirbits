defmodule Elixirbits.AshActionBoundaryTest do
  use ExUnit.Case, async: true

  @repo_operation ~r/\bRepo\.(aggregate|all|delete|delete!|delete_all|exists\?|get|get!|insert|insert!|insert_all|insert_or_update|insert_or_update!|one|one!|preload|query|query!|reload|reload!|stream|transaction|update|update!|update_all)\b/
  @ecto_sql_operation ~r/\bEcto\.Adapters\.SQL\.(query|query!|stream)\b/

  @allowed_matches %{
    "lib/elixirbits/events/clear_all_records.ex" => [~r/Repo\.query!/],
    "test/elixirbits/core_utils/search_test.exs" => [~r/Repo\.query!/]
  }

  test "project uses Ash actions for database access unless bypass is explicit" do
    violations =
      project_files()
      |> Enum.flat_map(&file_violations/1)

    assert violations == [],
           "Direct database operations must go through Ash actions unless allowlisted:\n#{Enum.join(violations, "\n")}"
  end

  defp project_files do
    ["lib/**/*.ex", "test/**/*.ex", "test/**/*.exs"]
    |> Enum.flat_map(&Path.wildcard/1)
    |> Enum.sort()
  end

  defp file_violations(path) do
    path
    |> File.read!()
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.reduce([], fn {line, line_number}, violations ->
      if direct_db_operation?(line) and not allowlisted?(path, line) do
        ["#{path}:#{line_number}: #{String.trim(line)}" | violations]
      else
        violations
      end
    end)
    |> Enum.reverse()
  end

  defp direct_db_operation?(line) do
    String.match?(line, @repo_operation) or String.match?(line, @ecto_sql_operation)
  end

  defp allowlisted?(path, line) do
    @allowed_matches
    |> Map.get(path, [])
    |> Enum.any?(&String.match?(line, &1))
  end
end

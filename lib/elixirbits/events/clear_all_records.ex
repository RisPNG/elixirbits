defmodule Elixirbits.Events.ClearAllRecords do
  use AshEvents.ClearRecordsForReplay

  alias Elixirbits.Repo

  @impl true
  def clear_records!(_opts) do
    tables =
      :elixirbits
      |> Ash.Info.domains_and_resources()
      |> Map.values()
      |> List.flatten()
      |> Enum.filter(fn resource ->
        match?({:ok, Elixirbits.Events.Event}, AshEvents.Events.Info.events_event_log(resource))
      end)
      |> Enum.map(&AshPostgres.DataLayer.Info.table/1)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()
      |> Enum.sort()

    Repo.query!("TRUNCATE TABLE #{Enum.join(tables, ", ")} RESTART IDENTITY CASCADE")

    :ok
  end
end

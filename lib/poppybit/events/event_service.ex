defmodule Poppybit.Events.ClearAllRecords do
  use AshEvents.ClearRecordsForReplay

  alias Poppybit.Repo

  @impl true
  def clear_records!(_opts) do
    tables =
      :poppybit
      |> Ash.Info.domains_and_resources()
      |> Map.values()
      |> List.flatten()
      |> Enum.filter(fn resource ->
        match?({:ok, Poppybit.Events.Event}, AshEvents.Events.Info.events_event_log(resource))
      end)
      |> Enum.flat_map(fn resource ->
        if AshPaperTrail.Resource in Spark.extensions(resource),
          do: [resource, AshPaperTrail.Resource.Info.version_resource(resource)],
          else: [resource]
      end)
      |> Enum.map(&AshPostgres.DataLayer.Info.table/1)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()
      |> Enum.sort()

    Repo.query!("TRUNCATE TABLE #{Enum.join(tables, ", ")} RESTART IDENTITY CASCADE")

    :ok
  end
end

defmodule Poppybit.Events.EventService do
  use Ash.Domain, otp_app: :poppybit

  resources do
    resource Poppybit.Events.Event
  end
end

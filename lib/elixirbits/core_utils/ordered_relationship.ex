defmodule Elixirbits.CoreUtils.OrderedRelationship do
  use Ash.Resource.Change

  @impl true
  def change(changeset, opts, _context) do
    argument = Keyword.fetch!(opts, :argument)

    case Ash.Changeset.get_argument(changeset, argument) do
      nil ->
        changeset

      records ->
        records =
          records
          |> Enum.with_index(1)
          |> Enum.map(fn {record, sequence} ->
            record |> Map.delete("sequence") |> Map.put(:sequence, sequence)
          end)

        Ash.Changeset.set_argument(changeset, argument, records)
    end
  end
end

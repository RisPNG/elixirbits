defmodule Elixirbits.Events.ClearAllRecords do
  use AshEvents.ClearRecordsForReplay

  alias Elixirbits.Repo

  @impl true
  def clear_records!(_opts) do
    Repo.query!(
      "TRUNCATE TABLE users, api_keys, ledger_accounts, ledger_transfers, ledger_balances RESTART IDENTITY CASCADE"
    )

    :ok
  end
end

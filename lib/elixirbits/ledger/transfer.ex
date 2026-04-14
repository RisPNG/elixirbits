defmodule Elixirbits.Ledger.Transfer do
  use Ash.Resource,
    domain: Elixir.Elixirbits.Ledger,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshDoubleEntry.Transfer, AshEvents.Events, AshPaperTrail.Resource]

  transfer do
    account_resource Elixirbits.Ledger.Account
    balance_resource Elixirbits.Ledger.Balance
  end

  postgres do
    table "ledger_transfers"
    repo Elixirbits.Repo
  end

  events do
    event_log Elixirbits.Events.Event
  end

  paper_trail do
    primary_key_type :uuid_v7
    change_tracking_mode :changes_only
    store_action_name? true
  end

  actions do
    defaults [:read]

    create :transfer do
      accept [:amount, :timestamp, :from_account_id, :to_account_id]
    end
  end

  attributes do
    attribute :id, AshDoubleEntry.ULID do
      primary_key? true
      allow_nil? false
      default &AshDoubleEntry.ULID.generate/0
    end

    attribute :amount, :money do
      allow_nil? false
    end

    timestamps()
  end

  relationships do
    belongs_to :from_account, Elixirbits.Ledger.Account do
      attribute_writable? true
    end

    belongs_to :to_account, Elixirbits.Ledger.Account do
      attribute_writable? true
    end

    has_many :balances, Elixirbits.Ledger.Balance
  end
end

defmodule Poppybit.Ledger.Account do
  use Ash.Resource,
    domain: Poppybit.Ledgers.LedgerService,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshDoubleEntry.Account, AshEvents.Events, AshPaperTrail.Resource]

  account do
    transfer_resource Poppybit.Ledger.Transfer
    balance_resource Poppybit.Ledger.Balance
  end

  postgres do
    table "ledger_accounts"
    repo Poppybit.Repo
  end

  events do
    event_log Poppybit.Events.Event
  end

  paper_trail do
    primary_key_type :uuid_v7
    change_tracking_mode :snapshot
    store_action_name? true
    operation_id_field :operation_id
    belongs_to_actor :actor, Poppybit.Accounts.User, domain: Poppybit.Users.UserService
    metadata :actor_name, :string
    metadata :restored_from_version_id, :uuid
    version_extensions authorizers: [Ash.Policy.Authorizer]
    mixin Poppybit.CoreUtils.Resource.AuditLog.Version
  end

  actions do
    defaults [:read]

    create :open do
      accept [:identifier, :currency]
    end

    read :lock_accounts do
      # Used to lock accounts while doing ledger operations
      prepare {AshDoubleEntry.Account.Preparations.LockForUpdate, []}
    end
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :identifier, :string do
      allow_nil? false
    end

    attribute :currency, :string do
      allow_nil? false
    end

    timestamps()
  end

  relationships do
    has_many :balances, Poppybit.Ledger.Balance do
      destination_attribute :account_id
    end
  end

  calculations do
    calculate :balance_as_of_ulid, :money do
      calculation {AshDoubleEntry.Account.Calculations.BalanceAsOfUlid, resource: __MODULE__}

      argument :ulid, AshDoubleEntry.ULID do
        allow_nil? false
        allow_expr? true
      end
    end

    calculate :balance_as_of, :money do
      calculation {AshDoubleEntry.Account.Calculations.BalanceAsOf, resource: __MODULE__}

      argument :timestamp, :utc_datetime_usec do
        allow_nil? false
        allow_expr? true
        default &DateTime.utc_now/0
      end
    end
  end

  identities do
    identity :unique_identifier, [:identifier]
  end
end

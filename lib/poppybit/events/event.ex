defmodule Poppybit.Events.Event do
  use Ash.Resource,
    otp_app: :poppybit,
    domain: Poppybit.Events.EventService,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshEvents.EventLog]

  postgres do
    table "events"
    repo Poppybit.Repo
  end

  event_log do
    clear_records_for_replay Poppybit.Events.ClearAllRecords
    primary_key_type Ash.Type.UUIDv7
    record_id_type :string
    persist_actor_primary_key :user_id, Poppybit.Accounts.User
  end

  actions do
    defaults [:read]
  end

  policies do
    bypass actor_attribute_equals(:system, true) do
      authorize_if always()
    end
  end
end

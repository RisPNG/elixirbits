defmodule Elixirbits.Events.Event do
  use Ash.Resource,
    otp_app: :elixirbits,
    domain: Elixirbits.Events,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshEvents.EventLog]

  postgres do
    table "events"
    repo Elixirbits.Repo
  end

  event_log do
    clear_records_for_replay Elixirbits.Events.ClearAllRecords
    primary_key_type Ash.Type.UUIDv7
    persist_actor_primary_key :user_id, Elixirbits.Accounts.User
  end

  policies do
    bypass actor_attribute_equals(:system, true) do
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if always()
    end
  end
end

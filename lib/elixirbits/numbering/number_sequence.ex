defmodule Elixirbits.Numbering.NumberSequence do
  use Ash.Resource,
    domain: Elixirbits.Numbering,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "number_sequences"
    repo Elixirbits.Repo
  end

  actions do
    defaults [:read]

    create :ensure do
      upsert? true
      upsert_identity :unique_doc_period
      upsert_fields [:doc_type]
      accept [:doc_type, :period_key]
    end

    update :increment do
      accept []
      change atomic_update(:current_value, expr(current_value + 1))
    end
  end

  policies do
    bypass actor_attribute_equals(:system, true) do
      authorize_if always()
    end
  end

  attributes do
    uuid_v7_primary_key :id
    attribute :doc_type, :string, allow_nil?: false
    attribute :period_key, :date, allow_nil?: false
    attribute :current_value, :integer, allow_nil?: false, default: 0
    timestamps()
  end

  identities do
    identity :unique_doc_period, [:doc_type, :period_key]
  end
end

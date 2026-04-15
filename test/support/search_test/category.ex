defmodule Elixirbits.SearchTest.Category do
  use Ash.Resource,
    domain: Elixirbits.SearchTest.Domain,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "search_test_categories"
    repo Elixirbits.Repo
  end

  actions do
    defaults [:read]
  end

  attributes do
    integer_primary_key :id

    attribute :name, :string
    attribute :code, :string

    timestamps()
  end

  relationships do
    has_many :records, Elixirbits.SearchTest.Record do
      destination_attribute :category_id
    end
  end
end

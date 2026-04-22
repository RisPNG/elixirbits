defmodule Elixirbits.SearchTest.Record do
  use Ash.Resource,
    domain: Elixirbits.SearchTest.Domain,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "search_test_records"
    repo Elixirbits.Repo
  end

  actions do
    defaults [:read]

    create :create do
      primary? true

      accept [
        :name,
        :description,
        :count,
        :secondary_count,
        :rating,
        :amount,
        :due_date,
        :shipped_at,
        :published_at,
        :opens_at,
        :active,
        :meta,
        :code,
        :tags,
        :category_id
      ]
    end
  end

  attributes do
    integer_primary_key :id

    attribute :name, :string
    attribute :description, :string
    attribute :count, :integer
    attribute :secondary_count, :integer
    attribute :rating, :float
    attribute :amount, :decimal
    attribute :due_date, :date
    attribute :shipped_at, :utc_datetime
    attribute :published_at, :naive_datetime
    attribute :opens_at, :time
    attribute :active, :boolean
    attribute :meta, :map
    attribute :code, :binary
    attribute :tags, {:array, :string}

    timestamps()
  end

  relationships do
    belongs_to :category, Elixirbits.SearchTest.Category do
      allow_nil? false
      attribute_type :integer
      attribute_writable? true
    end
  end
end

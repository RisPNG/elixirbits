defmodule Elixirbits.Address do
  use Ash.Resource,
    domain: Elixirbits.Accounts,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshEvents.Events, AshPaperTrail.Resource]

  postgres do
    table "addresses"
    repo Elixirbits.Repo

    references do
      reference :user, on_delete: :delete, on_update: :update, index?: true
    end
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
    defaults [:read, :destroy]

    create :create do
      accept [
        :user_id,
        :contact_name,
        :contact_tel_no,
        :country,
        :line_1,
        :line_2,
        :line_3,
        :postal_code,
        :city,
        :state,
        :latitudde,
        :longitude,
        :label,
        :other_label
      ]
    end

    update :update do
      accept [
        :user_id,
        :contact_name,
        :contact_tel_no,
        :country,
        :line_1,
        :line_2,
        :line_3,
        :postal_code,
        :city,
        :state,
        :latitudde,
        :longitude,
        :label,
        :other_label
      ]
    end
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :contact_name, :string
    attribute :contact_tel_no, :string
    attribute :country, :string
    attribute :line_1, :string
    attribute :line_2, :string
    attribute :line_3, :string
    attribute :postal_code, :string
    attribute :city, :string
    attribute :state, :string
    attribute :latitudde, :decimal
    attribute :longitude, :decimal
    attribute :label, Elixirbits.CoreUtils.EnumTypes.AddressLabel
    attribute :other_label, :string

    timestamps()
  end

  relationships do
    belongs_to :user, Elixirbits.Accounts.User do
      allow_nil? false
      attribute_writable? true
    end
  end
end

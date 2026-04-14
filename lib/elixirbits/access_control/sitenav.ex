defmodule Elixirbits.AccessControl.Sitenav do
  use Ash.Resource,
    domain: Elixirbits.AccessControl,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshEvents.Events, AshPaperTrail.Resource]

  postgres do
    table "sitenav"
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
    defaults [:read, :destroy]

    create :create do
      accept [
        :code,
        :name,
        :description,
        :level,
        :parent,
        :url,
        :sequence,
        :state,
        :roles_bypass,
        :users_bypass
      ]
    end

    update :update do
      accept [
        :code,
        :name,
        :description,
        :level,
        :parent,
        :url,
        :sequence,
        :roles_bypass,
        :users_bypass
      ]
    end

    update :enable do
      accept []
      change set_attribute(:state, :ENABLED)
    end

    update :disable do
      accept []
      change set_attribute(:state, :DISABLED)
    end
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :code, :string do
      allow_nil? false
    end

    attribute :name, :string do
      allow_nil? false
    end

    attribute :description, :string

    attribute :level, :integer do
      allow_nil? false
    end

    attribute :parent, :string
    attribute :url, :string
    attribute :sequence, :integer

    attribute :state, Elixirbits.CoreUtils.EnumTypes.SitenavState do
      allow_nil? false
      default :ENABLED
    end

    attribute :roles_bypass, {:array, :string} do
      allow_nil? false
      default []
    end

    attribute :users_bypass, {:array, :string} do
      allow_nil? false
      default []
    end

    timestamps()
  end

  relationships do
    has_many :role_perms, Elixirbits.AccessControl.RolePerm do
      source_attribute :code
      destination_attribute :sitenav_code
    end
  end

  identities do
    identity :unique_code, [:code]
  end
end

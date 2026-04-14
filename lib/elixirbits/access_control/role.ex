defmodule Elixirbits.AccessControl.Role do
  use Ash.Resource,
    domain: Elixirbits.AccessControl,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshEvents.Events, AshPaperTrail.Resource]

  postgres do
    table "roles"
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
      accept [:code, :name, :description]
    end

    update :update do
      accept [:code, :name, :description]
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

    timestamps()
  end

  relationships do
    has_many :role_perms, Elixirbits.AccessControl.RolePerm do
      source_attribute :code
      destination_attribute :roles_code
    end
  end

  identities do
    identity :unique_code, [:code]
  end
end

defmodule Elixirbits.AccessControl.RolePerm do
  use Ash.Resource,
    domain: Elixirbits.AccessControl,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshEvents.Events, AshPaperTrail.Resource]

  postgres do
    table "role_perms"
    repo Elixirbits.Repo

    references do
      reference :role, on_delete: :delete, on_update: :update, index?: true
      reference :sitenav, on_delete: :restrict, on_update: :update, index?: true
    end
  end

  events do
    event_log Elixirbits.Events.Event
  end

  paper_trail do
    primary_key_type :uuid_v7
    reference_source? false
    change_tracking_mode :changes_only
    store_action_name? true
  end

  use Elixirbits.AccessControl.ResourcePolicies, path: "/admin/roles"

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:sitenav_code, :roles_code, :level]
    end

    update :update do
      primary? true
      accept [:sitenav_code, :roles_code, :level]
    end
  end

  policies do
    policy action_type([:create, :update, :destroy]) do
      authorize_if {Elixirbits.AccessControl.ResourcePolicy,
                    paths: ["/admin/roles"], capability: :su}
    end
  end

  validations do
    validate one_of(:level, [0, 4, 5, 6, 7, 12, 13, 14, 15, 16])
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :level, :integer do
      allow_nil? false
    end

    timestamps()
  end

  relationships do
    belongs_to :sitenav, Elixirbits.AccessControl.Sitenav do
      source_attribute :sitenav_code
      destination_attribute :code
      attribute_type :string
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :role, Elixirbits.AccessControl.Role do
      source_attribute :roles_code
      destination_attribute :code
      attribute_type :string
      allow_nil? false
      attribute_writable? true
    end
  end

  identities do
    identity :unique_role_sitenav, [:roles_code, :sitenav_code]
  end
end

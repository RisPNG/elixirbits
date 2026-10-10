defmodule Elixirbits.Address do
  use Ash.Resource,
    domain: Elixirbits.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshEvents.Events, AshPaperTrail.Resource]

  postgres do
    table "addresses"
    repo Elixirbits.Repo

    references do
      reference :user, on_delete: :delete, on_update: :update, index?: true
      reference :organisation, on_delete: :restrict, on_update: :update, index?: true
    end

    check_constraints do
      check_constraint [:user_id, :organisation_id], "addresses_exactly_one_owner",
        check: "(user_id IS NULL) <> (organisation_id IS NULL)",
        message: "must belong to a user or the organisation"
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

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true

      accept [
        :contact_name,
        :contact_tel_no,
        :country,
        :line_1,
        :line_2,
        :line_3,
        :postal_code,
        :city,
        :state,
        :latitude,
        :longitude,
        :label,
        :other_label
      ]
    end

    update :update do
      primary? true

      accept [
        :contact_name,
        :contact_tel_no,
        :country,
        :line_1,
        :line_2,
        :line_3,
        :postal_code,
        :city,
        :state,
        :latitude,
        :longitude,
        :label,
        :other_label
      ]
    end
  end

  policies do
    default_access_type :strict

    bypass actor_attribute_equals(:system, true) do
      authorize_if always()
    end

    policy [action_type(:read), accessing_from(Elixirbits.Accounts.User, :addresses)] do
      authorize_if {Elixirbits.AccessControl.ResourcePolicy,
                    paths: ["/admin/users"], capability: :read}
    end

    policy [action_type(:create), accessing_from(Elixirbits.Accounts.User, :addresses)] do
      authorize_if {Elixirbits.AccessControl.ResourcePolicy,
                    paths: ["/admin/users"], capability: :create}
    end

    policy [action_type(:update), accessing_from(Elixirbits.Accounts.User, :addresses)] do
      authorize_if {Elixirbits.AccessControl.ResourcePolicy,
                    paths: ["/admin/users"], capability: :update}
    end

    policy [action_type(:destroy), accessing_from(Elixirbits.Accounts.User, :addresses)] do
      authorize_if {Elixirbits.AccessControl.ResourcePolicy,
                    paths: ["/admin/users"], capability: :delete}
    end

    policy [
      action_type(:read),
      accessing_from(Elixirbits.Organisations.Organisation, :addresses)
    ] do
      authorize_if {Elixirbits.AccessControl.ResourcePolicy,
                    paths: ["/admin/organisation"], capability: :read}
    end

    policy [
      action_type(:create),
      accessing_from(Elixirbits.Organisations.Organisation, :addresses)
    ] do
      authorize_if {Elixirbits.AccessControl.ResourcePolicy,
                    paths: ["/admin/organisation"], capability: :create}
    end

    policy [
      action_type(:update),
      accessing_from(Elixirbits.Organisations.Organisation, :addresses)
    ] do
      authorize_if {Elixirbits.AccessControl.ResourcePolicy,
                    paths: ["/admin/organisation"], capability: :update}
    end

    policy [
      action_type(:destroy),
      accessing_from(Elixirbits.Organisations.Organisation, :addresses)
    ] do
      authorize_if {Elixirbits.AccessControl.ResourcePolicy,
                    paths: ["/admin/organisation"], capability: :delete}
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
    attribute :latitude, :decimal
    attribute :longitude, :decimal
    attribute :label, Elixirbits.CoreUtils.EnumTypes.AddressLabel
    attribute :other_label, :string

    timestamps()
  end

  relationships do
    belongs_to :user, Elixirbits.Accounts.User do
      attribute_writable? true
    end

    belongs_to :organisation, Elixirbits.Organisations.Organisation do
      attribute_writable? true
    end
  end
end

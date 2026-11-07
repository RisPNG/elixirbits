defmodule Poppybit.Address do
  use Ash.Resource,
    domain: Poppybit.Addresses.AddressService,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshEvents.Events, AshPaperTrail.Resource]

  postgres do
    table "addresses"
    repo Poppybit.Repo

    references do
      reference :user, on_delete: :delete, on_update: :update, index?: true
      reference :organization, on_delete: :restrict, on_update: :update, index?: true
    end

    check_constraints do
      check_constraint [:user_id, :organization_id], "addresses_exactly_one_owner",
        check: "(user_id IS NULL) <> (organization_id IS NULL)",
        message: "must belong to a user or the organization"
    end
  end

  events do
    event_log Poppybit.Events.Event
  end

  paper_trail do
    primary_key_type :uuid_v7
    reference_source? false
    change_tracking_mode :snapshot
    store_action_name? true
    attributes_as_attributes [:user_id, :organization_id]
    operation_id_field :operation_id
    belongs_to_actor :actor, Poppybit.Accounts.User, domain: Poppybit.Users.UserService
    metadata :actor_name, :string
    metadata :restored_from_version_id, :uuid
    version_extensions authorizers: [Ash.Policy.Authorizer]
    mixin Poppybit.CoreUtils.Resource.AuditLog.Version
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true

      accept [
        :sequence,
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
        :sequence,
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

    policy [action_type(:read), accessing_from(Poppybit.Accounts.User, :addresses)] do
      authorize_if {Poppybit.AccessControl.ResourcePolicy,
                    paths: ["/dashboard/admin/users"], capability: :read}
    end

    policy [action_type(:create), accessing_from(Poppybit.Accounts.User, :addresses)] do
      authorize_if {Poppybit.AccessControl.ResourcePolicy,
                    paths: ["/dashboard/admin/users"], capability: :create}
    end

    policy [action_type(:update), accessing_from(Poppybit.Accounts.User, :addresses)] do
      authorize_if {Poppybit.AccessControl.ResourcePolicy,
                    paths: ["/dashboard/admin/users"], capability: :update}
    end

    policy [action_type(:destroy), accessing_from(Poppybit.Accounts.User, :addresses)] do
      authorize_if {Poppybit.AccessControl.ResourcePolicy,
                    paths: ["/dashboard/admin/users"], capability: :delete}
    end

    policy [
      action_type(:read),
      accessing_from(Poppybit.Organizations.Organization, :addresses)
    ] do
      authorize_if {Poppybit.AccessControl.ResourcePolicy,
                    paths: ["/dashboard/admin/organization"], capability: :read}
    end

    policy [
      action_type(:create),
      accessing_from(Poppybit.Organizations.Organization, :addresses)
    ] do
      authorize_if {Poppybit.AccessControl.ResourcePolicy,
                    paths: ["/dashboard/admin/organization"], capability: :create}
    end

    policy [
      action_type(:update),
      accessing_from(Poppybit.Organizations.Organization, :addresses)
    ] do
      authorize_if {Poppybit.AccessControl.ResourcePolicy,
                    paths: ["/dashboard/admin/organization"], capability: :update}
    end

    policy [
      action_type(:destroy),
      accessing_from(Poppybit.Organizations.Organization, :addresses)
    ] do
      authorize_if {Poppybit.AccessControl.ResourcePolicy,
                    paths: ["/dashboard/admin/organization"], capability: :delete}
    end
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :sequence, :integer do
      allow_nil? false
      default 1
      constraints min: 1
    end

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
    attribute :label, Poppybit.CoreUtils.Options.AddressLabel
    attribute :other_label, :string

    timestamps()
  end

  relationships do
    belongs_to :user, Poppybit.Accounts.User do
      attribute_writable? true
    end

    belongs_to :organization, Poppybit.Organizations.Organization do
      attribute_writable? true
    end
  end
end

defmodule Elixirbits.Organizations.Organization do
  use Ash.Resource,
    domain: Elixirbits.Organizations,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshEvents.Events, AshPaperTrail.Resource]

  postgres do
    table "organizations"
    repo Elixirbits.Repo

    check_constraints do
      check_constraint :key, "organizations_application_key",
        check: "key = 'application'",
        message: "must identify the application settings"
    end
  end

  events do
    event_log Elixirbits.Events.Event
  end

  paper_trail do
    primary_key_type :uuid_v7
    change_tracking_mode :snapshot
    only_when_changed? false
    store_action_name? true
    operation_id_field :operation_id
    belongs_to_actor :actor, Elixirbits.Accounts.User, domain: Elixirbits.Accounts
    metadata :actor_name, :string
    metadata :restored_from_version_id, :uuid
    version_extensions authorizers: [Ash.Policy.Authorizer]
    mixin Elixirbits.AuditLog.Version
  end

  actions do
    defaults [:read]

    action :current, :map do
      allow_nil? true

      run fn _input, _context ->
        fields = [:id, :name, :base_currency, :locale, :timezone]

        __MODULE__
        |> Ash.Query.for_read(:settings, %{}, actor: %{system: true})
        |> Ash.Query.select(fields)
        |> Ash.read_one(actor: %{system: true})
        |> case do
          {:ok, nil} -> {:ok, nil}
          {:ok, organization} -> {:ok, Map.take(organization, fields)}
          error -> error
        end
      end
    end

    read :settings do
      get? true
      filter expr(key == "application")
    end

    create :create do
      accept [
        :name,
        :registration_no,
        :tax_identification_no,
        :base_currency,
        :locale,
        :timezone,
        :email,
        :phone
      ]

      argument :addresses, {:array, :map}

      change {Ash.Resource.Change.Function,
              fun: {Elixirbits.CoreUtils.Resource, :normalize_ordered_relationship, [:addresses]}}

      change manage_relationship(:addresses, type: :direct_control)
    end

    update :update do
      require_atomic? false

      accept [
        :name,
        :registration_no,
        :tax_identification_no,
        :base_currency,
        :locale,
        :timezone,
        :email,
        :phone
      ]

      argument :addresses, {:array, :map}

      change {Ash.Resource.Change.Function,
              fun: {Elixirbits.CoreUtils.Resource, :normalize_ordered_relationship, [:addresses]}}

      change manage_relationship(:addresses, type: :direct_control)
    end
  end

  policies do
    bypass action(:current) do
      authorize_if always()
    end
  end

  use Elixirbits.AccessControl.ResourcePolicies, path: "/admin/organization"

  validations do
    validate one_of(:base_currency, Enum.map(Cldr.Currency.known_currency_codes(), &to_string/1))
    validate one_of(:locale, Enum.map(Elixirbits.Cldr.known_locale_names(), &to_string/1))

    validate fn changeset, _context ->
               case DateTime.now(Ash.Changeset.get_attribute(changeset, :timezone)) do
                 {:ok, _datetime} ->
                   :ok

                 {:error, _reason} ->
                   {:error, field: :timezone, message: "is not a known timezone"}
               end
             end,
             only_when_valid?: true
  end

  attributes do
    uuid_v7_primary_key :id
    attribute :key, :string, allow_nil?: false, default: "application"
    attribute :name, :string, allow_nil?: false
    attribute :registration_no, :string
    attribute :tax_identification_no, :string
    attribute :base_currency, :string, allow_nil?: false, default: "MYR"
    attribute :locale, :string, allow_nil?: false, default: "en"
    attribute :timezone, :string, allow_nil?: false, default: "Asia/Kuala_Lumpur"
    attribute :email, :string
    attribute :phone, :string
    timestamps()
  end

  relationships do
    has_many :addresses, Elixirbits.Address do
      destination_attribute :organization_id
      sort sequence: :asc, id: :asc
    end
  end

  identities do
    identity :singleton, [:key]
  end
end

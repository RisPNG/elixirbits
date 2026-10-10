defmodule Elixirbits.Organisations.Organisation do
  use Ash.Resource,
    domain: Elixirbits.Organisations,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshEvents.Events, AshPaperTrail.Resource]

  postgres do
    table "organisations"
    repo Elixirbits.Repo

    check_constraints do
      check_constraint :key, "organisations_application_key",
        check: "key = 'application'",
        message: "must identify the application settings"
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
          {:ok, organisation} -> {:ok, Map.take(organisation, fields)}
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
      change manage_relationship(:addresses, type: :direct_control)
    end
  end

  policies do
    bypass action(:current) do
      authorize_if always()
    end
  end

  use Elixirbits.AccessControl.ResourcePolicies, path: "/admin/organisation"

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
      destination_attribute :organisation_id
    end
  end

  identities do
    identity :singleton, [:key]
  end
end

defmodule Elixirbits.AccessControl.Sitenav do
  use Ash.Resource,
    domain: Elixirbits.AccessControl,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshEvents.Events, AshPaperTrail.Resource]

  @icon_sets [
    {"hero-", Path.expand("../../../deps/heroicons/optimized/24/outline", __DIR__), ""},
    {"hero-", Path.expand("../../../deps/heroicons/optimized/24/solid", __DIR__), "-solid"},
    {"hero-", Path.expand("../../../deps/heroicons/optimized/20/solid", __DIR__), "-mini"},
    {"hero-", Path.expand("../../../deps/heroicons/optimized/16/solid", __DIR__), "-micro"},
    {"tabler-", Path.expand("../../../deps/tabler_icons/icons/outline", __DIR__), ""},
    {"tabler-", Path.expand("../../../deps/tabler_icons/icons/filled", __DIR__), "-filled"}
  ]
  @icon_catalog for {prefix, directory, suffix} <- @icon_sets,
                    file <- Path.wildcard(Path.join(directory, "*.svg")),
                    do: {file, prefix <> Path.basename(file, ".svg") <> suffix}
  @icon_files_hash @icon_catalog |> Enum.map(&elem(&1, 0)) |> :erlang.md5()
  @navigation_icons Enum.map(@icon_catalog, &elem(&1, 1))

  @doc false
  def __mix_recompile__? do
    @icon_sets
    |> Enum.flat_map(fn {_, directory, _} -> Path.wildcard(Path.join(directory, "*.svg")) end)
    |> :erlang.md5()
    |> Kernel.!=(@icon_files_hash)
  end

  postgres do
    table "sitenav"
    repo Elixirbits.Repo
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

      accept [
        :code,
        :name,
        :description,
        :icon,
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
      primary? true

      accept [
        :code,
        :name,
        :description,
        :icon,
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

  policies do
    policy action_type([:create, :update, :destroy]) do
      authorize_if {Elixirbits.AccessControl.ResourcePolicy,
                    paths: ["/admin/roles"], capability: :su}
    end
  end

  validations do
    validate one_of(:icon, @navigation_icons), message: "must be a supported navigation icon"
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

    attribute :icon, :string

    attribute :level, :integer do
      allow_nil? false
    end

    attribute :parent, :string

    attribute :url, :string do
      constraints allow_empty?: true
    end

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

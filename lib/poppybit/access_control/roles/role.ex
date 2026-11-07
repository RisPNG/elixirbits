defmodule Poppybit.AccessControl.Role do
  require Ash.Query

  use Ash.Resource,
    domain: Poppybit.AccessControl.AccessControlService,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshEvents.Events, AshPaperTrail.Resource]

  postgres do
    table "roles"
    repo Poppybit.Repo
  end

  events do
    event_log Poppybit.Events.Event
  end

  paper_trail do
    primary_key_type :uuid_v7
    reference_source? false
    change_tracking_mode :snapshot
    only_when_changed? false
    store_action_name? true
    operation_id_field :operation_id
    belongs_to_actor :actor, Poppybit.Accounts.User, domain: Poppybit.Users.UserService
    metadata :actor_name, :string
    metadata :restored_from_version_id, :uuid
    version_extensions authorizers: [Ash.Policy.Authorizer]
    mixin Poppybit.CoreUtils.Resource.AuditLog.Version
  end

  use Poppybit.AccessControl.ResourcePolicies,
    path: "/dashboard/admin/roles",
    read_paths: ["/dashboard/admin/roles", "/dashboard/admin/users"]

  code_interface do
    define? false
    define :get_role, action: :read, get_by: :id
    define :list_roles, action: :read
    define :delete_role, action: :destroy
  end

  actions do
    defaults [:read]

    destroy :destroy do
      primary? true
      require_atomic? false
      touches_resources [Poppybit.Accounts.User]

      argument :remove_assignments?, :boolean, allow_nil?: false, default: false

      validate attribute_does_not_equal(:code, "superuser"),
        message: "cannot delete the superuser role"

      change before_action(fn changeset, _context ->
               Ash.get!(__MODULE__, changeset.data.id, lock: :for_update, authorize?: false)
               code = changeset.data.code

               assigned? =
                 Poppybit.Accounts.User
                 |> Ash.Query.new(base_filter?: false)
                 |> Ash.Query.filter(^code in roles)
                 |> Ash.Query.select([])
                 |> Ash.Query.limit(1)
                 |> Ash.read!(authorize?: false)
                 |> Enum.any?()

               if assigned? and not Ash.Changeset.get_argument(changeset, :remove_assignments?) do
                 Ash.Changeset.add_error(
                   changeset,
                   Ash.Error.Changes.InvalidArgument.exception(
                     field: :remove_assignments?,
                     value: false,
                     message: "must confirm removing this role from assigned accounts"
                   )
                 )
               else
                 changeset
               end
             end)

      change after_action(fn changeset, role, context ->
               if Ash.Changeset.get_argument(changeset, :remove_assignments?) do
                 code = role.code

                 users =
                   Poppybit.Accounts.User
                   |> Ash.Query.new(base_filter?: false)
                   |> Ash.Query.filter(^code in roles)
                   |> Ash.Query.sort(id: :asc)
                   |> Ash.Query.lock(:for_update)
                   |> Ash.read!(authorize?: false)

                 case users do
                   [] ->
                     {:ok, role}

                   users ->
                     result =
                       Ash.bulk_update!(users, :remove_deleted_role, %{role_code: code},
                         actor: context.actor,
                         authorize?: false,
                         strategy: [:stream],
                         transaction: false,
                         return_errors?: true,
                         return_notifications?: true
                       )

                     {:ok, role, result.notifications}
                 end
               else
                 {:ok, role}
               end
             end)
    end

    create :create do
      primary? true
      accept [:code, :name, :description]

      argument :permissions, {:array, :map}

      change manage_relationship(:permissions, :role_perms,
               type: :direct_control,
               use_identities: [:unique_role_sitenav],
               on_missing: :ignore
             )
    end

    update :update do
      primary? true
      require_atomic? false
      accept [:name, :description]

      argument :permissions, {:array, :map}

      change manage_relationship(:permissions, :role_perms,
               type: :direct_control,
               use_identities: [:unique_role_sitenav],
               on_missing: :ignore
             )
    end

    update :restore do
      require_atomic? false
      accept [:name, :description]
      argument :permissions, {:array, :map}

      change fn changeset, context ->
        case Ash.Changeset.get_argument(changeset, :permissions) do
          nil ->
            changeset

          permissions ->
            role = Ash.load!(changeset.data, :role_perms, actor: context.actor)
            pages = MapSet.new(permissions, &Map.get(&1, "sitenav_code", &1[:sitenav_code]))

            missing =
              for grant <- role.role_perms,
                  grant.level != 0 and not MapSet.member?(pages, grant.sitenav_code),
                  do: %{sitenav_code: grant.sitenav_code, level: 0}

            permissions = permissions ++ missing

            if permissions == [],
              do: Ash.Changeset.delete_argument(changeset, :permissions),
              else: Ash.Changeset.set_argument(changeset, :permissions, permissions)
        end
      end

      change manage_relationship(:permissions, :role_perms,
               type: :direct_control,
               use_identities: [:unique_role_sitenav],
               on_missing: :ignore
             )
    end
  end

  policies do
    policy changing_relationship(:role_perms) do
      authorize_if {Poppybit.AccessControl.ResourcePolicy,
                    paths: ["/dashboard/admin/roles"], capability: :su}
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
    has_many :role_perms, Poppybit.AccessControl.RolePerm do
      source_attribute :code
      destination_attribute :roles_code
    end
  end

  identities do
    identity :unique_code, [:code]
  end
end

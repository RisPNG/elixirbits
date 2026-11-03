defmodule Elixirbits.AccessControl.ResourcePolicy do
  use Ash.Policy.SimpleCheck

  alias Elixirbits.AccessControl.Permissions

  @impl true
  def describe(opts), do: "actor can #{opts[:capability]} #{Enum.join(opts[:paths], ", ")}"

  @impl true
  def match?(%{system: true}, _context, _opts), do: true

  def match?(nil, _context, _opts), do: false

  def match?(actor, _context, opts) do
    permissions = Permissions.load(actor)

    Enum.any?(opts[:paths], &Permissions.can?(permissions, &1, opts[:capability]))
  end

  def scopes(resource, capability, visited \\ []) do
    if resource in visited do
      []
    else
      scopes =
        Ash.Policy.Info.policies(Ash.Resource.Info.domain(resource), resource)
        |> Enum.flat_map(fn policy ->
          attribute =
            Enum.find_value(List.wrap(policy.condition), fn
              {Ash.Policy.Check.AccessingFrom, opts} ->
                relationship =
                  Ash.Resource.Info.relationship(opts[:source], opts[:relationship])

                relationship.destination_attribute

              _ ->
                nil
            end)

          for %{check_module: __MODULE__, check_opts: opts, type: :authorize_if} <-
                policy.policies,
              opts[:capability] == capability,
              do: %{paths: opts[:paths], attribute: attribute}
        end)

      if scopes == [] do
        resource
        |> Ash.Resource.Info.relationships()
        |> Enum.filter(&(&1.type == :belongs_to))
        |> Enum.flat_map(fn relationship ->
          relationship.destination
          |> scopes(capability, [resource | visited])
          |> Enum.map(&%{&1 | attribute: relationship.source_attribute})
        end)
        |> Enum.uniq()
      else
        Enum.uniq(scopes)
      end
    end
  end
end

defmodule Elixirbits.AccessControl.ResourcePolicies do
  defmacro __using__(opts) do
    paths = opts |> Keyword.fetch!(:path) |> List.wrap()
    read_paths = opts |> Keyword.get(:read_paths, paths) |> List.wrap()

    quote do
      policies do
        default_access_type :strict

        bypass actor_attribute_equals(:system, true) do
          authorize_if always()
        end

        policy action_type(:read) do
          authorize_if {Elixirbits.AccessControl.ResourcePolicy,
                        paths: unquote(read_paths), capability: :read}
        end

        policy action_type(:create) do
          authorize_if {Elixirbits.AccessControl.ResourcePolicy,
                        paths: unquote(paths), capability: :create}
        end

        policy action_type(:update) do
          authorize_if {Elixirbits.AccessControl.ResourcePolicy,
                        paths: unquote(paths), capability: :update}
        end

        policy action_type(:destroy) do
          authorize_if {Elixirbits.AccessControl.ResourcePolicy,
                        paths: unquote(paths), capability: :delete}
        end
      end
    end
  end
end

defmodule Elixirbits.AccessControl.Permissions do
  import Ash.Query
  import Bitwise, only: [band: 2, bor: 2]

  alias Elixirbits.AccessControl.RolePerm
  alias Elixirbits.AccessControl.RolePerms.RolePermService
  alias Elixirbits.AccessControl.Sitenav
  alias Elixirbits.AccessControl.Sitenav.SitenavService
  alias Elixirbits.Users.UserService

  @level_options [
    {"None", 0},
    {"Read", 4},
    {"Read + Update", 5},
    {"Read + Create", 6},
    {"Read + Create + Update", 7},
    {"Read + Delete", 12},
    {"Read + Update + Delete", 13},
    {"Read + Create + Delete", 14},
    {"Read + Create + Update + Delete", 15},
    {"Superuser Access", 16}
  ]
  @levels for {_label, level} <- @level_options, level != 0, do: level
  @capabilities %{read: 4, create: 2, update: 1, delete: 8, su: 16}

  defstruct user: nil, entries: [], by_code: %{}, levels: %{}

  def level_options, do: @level_options

  def load(user) do
    user =
      if is_struct(user, Elixirbits.Accounts.User),
        do: UserService.get_user!(user.id, authorize?: false, not_found_error?: false),
        else: user

    entries = SitenavService.list_sitenav!(authorize?: false)
    roles = if user, do: user.roles, else: []

    levels =
      if roles == [] do
        %{}
      else
        query = filter(RolePerm, roles_code in ^roles)

        RolePermService.list_role_permissions!(query: query, authorize?: false)
        |> Enum.reduce(%{}, fn grant, levels ->
          if grant.level in [0 | @levels] do
            Map.update(levels, grant.sitenav_code, grant.level, fn level ->
              if level == 16 or grant.level == 16, do: 16, else: bor(level, grant.level)
            end)
          else
            levels
          end
        end)
      end

    %__MODULE__{
      user: user,
      entries: entries,
      by_code: Map.new(entries, &{&1.code, &1}),
      levels: levels
    }
  end

  def superuser?(%{roles: roles}), do: "superuser" in roles
  def superuser?(nil), do: false

  def visible_sitenav(%__MODULE__{} = permissions) do
    visible_codes =
      permissions.entries
      |> Enum.filter(&accessible?(permissions, &1))
      |> Enum.flat_map(&[&1.code | ancestor_codes(&1, permissions.by_code)])
      |> MapSet.new()

    permissions.entries
    |> Enum.filter(&(MapSet.member?(visible_codes, &1.code) and &1.state == :ENABLED))
    |> Enum.sort_by(& &1.sequence)
  end

  def can_access_path?(%__MODULE__{} = permissions, path) do
    case entry_for_path(permissions, path) do
      nil -> false
      entry -> accessible?(permissions, entry)
    end
  end

  def public_path?(%__MODULE__{} = permissions, path) do
    case entry_for_path(permissions, path) do
      %Sitenav{roles_bypass: roles} = entry ->
        "public" in roles and accessible?(permissions, entry)

      _ ->
        false
    end
  end

  def active_branch_codes(%__MODULE__{} = permissions, path) do
    case entry_for_path(permissions, path) do
      nil -> []
      entry -> [entry.code | ancestor_codes(entry, permissions.by_code)]
    end
  end

  def accessible?(%__MODULE__{} = permissions, %Sitenav{} = entry) do
    entry_level(permissions, entry) in @levels
  end

  def perm_level(%__MODULE__{} = permissions, path) do
    case entry_for_path(permissions, path) do
      nil -> 0
      entry -> entry_level(permissions, entry)
    end
  end

  def can?(%__MODULE__{} = permissions, path, capability) do
    level = perm_level(permissions, path)
    bit = Map.fetch!(@capabilities, capability)

    level == 16 or (level in @levels and band(level, bit) == bit)
  end

  def can?(user, path, capability), do: can?(load(user), path, capability)

  defp entry_level(%__MODULE__{user: user, levels: levels, by_code: by_code}, entry) do
    branch = [entry | Enum.map(ancestor_codes(entry, by_code), &Map.fetch!(by_code, &1))]

    cond do
      Enum.any?(branch, &(&1.state != :ENABLED)) ->
        0

      user && superuser?(user) ->
        16

      user && Enum.any?(user.roles, &(&1 != "public" and &1 in entry.roles_bypass)) ->
        16

      user && to_string(user.id) in entry.users_bypass ->
        16

      is_nil(user) ->
        if "public" in entry.roles_bypass, do: 4, else: 0

      true ->
        level = Map.get(levels, entry.code, 0)
        level = if level in @levels, do: level, else: 0

        if "public" in entry.roles_bypass and level != 16, do: bor(level, 4), else: level
    end
  end

  defp ancestor_codes(%{parent: nil}, _by_code), do: []

  defp ancestor_codes(%{parent: parent}, by_code) do
    case Map.get(by_code, parent) do
      nil -> []
      entry -> [entry.code | ancestor_codes(entry, by_code)]
    end
  end

  defp entry_for_path(permissions, path) do
    normalized = path |> to_string() |> String.trim("/")

    permissions.entries
    |> Enum.filter(fn entry ->
      prefix = entry.url |> to_string() |> String.trim("/")

      not is_nil(entry.url) and
        (normalized == prefix or (prefix != "" and String.starts_with?(normalized, prefix <> "/")))
    end)
    |> Enum.max_by(&String.length(&1.url), fn -> nil end)
  end
end

defmodule Elixirbits.AccessControl.AccessControlService do
  use Ash.Domain,
    otp_app: :elixirbits,
    extensions: [AshPaperTrail.Domain]

  paper_trail do
    include_versions? true
  end

  resources do
    resource Elixirbits.AccessControl.Sitenav
    resource Elixirbits.AccessControl.Role
    resource Elixirbits.AccessControl.RolePerm
  end
end

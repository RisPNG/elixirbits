defmodule Elixirbits.AuditLog.Version do
  use Ash.Policy.FilterCheck

  alias Elixirbits.AccessControl.Permissions
  alias Elixirbits.AccessControl.ResourcePolicy

  defmacro __using__(_opts) do
    quote do
      changes do
        change fn changeset, context ->
                 actor_name =
                   case context.actor do
                     %{__struct__: Elixirbits.Accounts.User} = actor ->
                       actor.display_name || actor.username || to_string(actor.email)

                     %{system: true} ->
                       "System"

                     _ ->
                       "Unknown"
                   end

                 Ash.Changeset.force_change_attribute(changeset, :actor_name, actor_name)
               end,
               on: :create
      end

      policies do
        policy action_type(:create) do
          authorize_if context_equals(:ash_paper_trail?, true)
        end

        policy action_type(:read) do
          access_type :filter
          authorize_if Elixirbits.AuditLog.Version
        end
      end
    end
  end

  @impl true
  def describe(_opts), do: "actor can update the page that owns this history"

  @impl true
  def filter(%{system: true}, _context, _opts), do: true

  def filter(actor, context, _opts) when not is_nil(actor) do
    permissions = Permissions.load(actor)

    context.resource.version_source_resource()
    |> ResourcePolicy.scopes(:update)
    |> Enum.reduce(false, fn scope, filter ->
      if Enum.any?(scope.paths, &Permissions.can?(permissions, &1, :update)) do
        scope_filter =
          cond do
            is_nil(scope.attribute) ->
              true

            Ash.Resource.Info.attribute(context.resource, scope.attribute) ->
              expr(not is_nil(^Ash.Expr.ref(scope.attribute)))

            true ->
              path = [to_string(scope.attribute)]
              expr(not is_nil(get_path(changes, ^path)))
          end

        expr(^filter or ^scope_filter)
      else
        filter
      end
    end)
  end

  def filter(nil, _context, _opts), do: false
end

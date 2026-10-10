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

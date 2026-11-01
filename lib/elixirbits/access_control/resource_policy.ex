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

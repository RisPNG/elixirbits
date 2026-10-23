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
end

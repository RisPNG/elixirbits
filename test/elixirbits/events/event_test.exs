defmodule Elixirbits.Events.EventTest do
  use Elixirbits.DataCase, async: false

  require Ash.Query

  import ElixirbitsWeb.ConnCase, only: [create_user: 1]

  alias Elixirbits.Events.Event
  alias Elixirbits.Accounts.User
  alias Elixirbits.AccessControl.Role
  alias Elixirbits.Numbering
  alias Elixirbits.Ledger.Account
  alias Elixirbits.Ledger.Transfer

  test "the event log records UUID accounts and ULID transfers in a real ledger transaction" do
    source = Ash.create!(Account, %{identifier: "source", currency: "MYR"}, action: :open)

    destination =
      Ash.create!(Account, %{identifier: "destination", currency: "MYR"}, action: :open)

    transfer =
      Ash.create!(
        Transfer,
        %{
          from_account_id: source.id,
          to_account_id: destination.id,
          amount: Money.new!(:MYR, 10)
        },
        action: :transfer
      )

    assert String.length(source.id) == 36
    assert String.length(transfer.id) == 26

    for {record, resource, action} <- [{source, Account, :open}, {transfer, Transfer, :transfer}] do
      event =
        Event
        |> Ash.Query.for_read(:read, %{}, actor: %{system: true})
        |> Ash.Query.filter(record_id == ^record.id and resource == ^resource)
        |> Ash.read_one!()

      assert event.record_id == record.id
      assert event.resource == resource
      assert event.action == action
      assert event.action_type == :create
    end

    source = Ash.load!(source, balance_as_of_ulid: %{ulid: transfer.id})
    destination = Ash.load!(destination, balance_as_of_ulid: %{ulid: transfer.id})
    assert Money.equal?(source.balance_as_of_ulid, Money.new!(:MYR, -10))
    assert Money.equal?(destination.balance_as_of_ulid, Money.new!(:MYR, 10))
  end

  test "event histories are private and native authentication inputs are redacted" do
    user = create_user(roles: [])

    for actor <- [nil, user] do
      assert {:error, %Ash.Error.Forbidden{}} =
               Event
               |> Ash.Query.for_read(:read, %{}, actor: actor)
               |> Ash.Query.filter(record_id == ^user.id)
               |> Ash.read()
    end

    event =
      Event
      |> Ash.Query.for_read(:read, %{}, actor: %{system: true})
      |> Ash.Query.filter(
        record_id == ^user.id and resource == ^User and action == :register_with_password
      )
      |> Ash.read_one!()

    data = Map.new(event.data, fn {key, value} -> {to_string(key), value} end)
    assert Map.has_key?(data, "password")
    assert Map.has_key?(data, "password_confirmation")
    assert data["password"] == nil
    assert data["password_confirmation"] == nil
    assert data["email"] == to_string(user.email)
  end

  test "replay reset clears detached audit versions and regenerates consistent history" do
    assert String.starts_with?(Elixirbits.Repo.config()[:database], "elixirbits_template_test")
    system = %{system: true}
    code = "replay-#{Ash.UUID.generate()}"
    active = Ash.create!(Role, %{code: code, name: "Original"}, actor: system)
    active = Ash.update!(active, %{name: "Updated"}, actor: system)
    removed = Ash.create!(Role, %{code: code <> "-removed", name: "Removed"}, actor: system)
    Ash.destroy!(removed, actor: system)

    version_resource = AshPaperTrail.Resource.Info.version_resource(Role)
    record_ids = [active.id, removed.id]

    Repo.delete_all(from event in Event, where: event.record_id not in ^record_ids)

    version_query =
      version_resource
      |> Ash.Query.for_read(:read)
      |> Ash.Query.filter(version_source_id in ^record_ids)

    old_versions = Ash.read!(version_query, actor: system)
    assert length(old_versions) == 4
    old_version_ids = MapSet.new(old_versions, & &1.id)

    history =
      Enum.map(old_versions, fn version ->
        version
        |> Map.take([:version_source_id, :version_action_type, :version_action_name, :changes])
        |> Map.update!(:changes, fn changes -> Map.delete(changes, "updated_at") end)
      end)
      |> Enum.sort()

    event_query = Ash.Query.for_read(Event, :read, %{}, actor: system)
    event_ids = event_query |> Ash.read!() |> Enum.map(& &1.id) |> Enum.sort()
    assert Numbering.next_number(code, ~D[2026-07-08]) == "#{code}-20260708-00001"

    assert :ok = Elixirbits.Events.ClearAllRecords.clear_records!([])
    assert Ash.read!(version_query, actor: system) == []
    assert {:ok, nil} = Ash.get(Role, active.id, actor: system, not_found_error?: false)

    assert :ok =
             Event |> Ash.ActionInput.for_action(:replay, %{}, actor: system) |> Ash.run_action!()

    restored = Ash.get!(Role, active.id, actor: system)
    assert restored.name == "Updated"
    assert restored.inserted_at == active.inserted_at
    assert restored.updated_at == active.updated_at
    assert {:ok, nil} = Ash.get(Role, removed.id, actor: system, not_found_error?: false)

    versions = Ash.read!(version_query, actor: system)
    assert length(versions) == 4
    assert MapSet.disjoint?(old_version_ids, MapSet.new(versions, & &1.id))

    assert Enum.map(versions, fn version ->
             version
             |> Map.take([
               :version_source_id,
               :version_action_type,
               :version_action_name,
               :changes
             ])
             |> Map.update!(:changes, fn changes -> Map.delete(changes, "updated_at") end)
           end)
           |> Enum.sort() == history

    assert event_query |> Ash.read!() |> Enum.map(& &1.id) |> Enum.sort() == event_ids
    assert Numbering.next_number(code, ~D[2026-07-08]) == "#{code}-20260708-00002"
  end
end

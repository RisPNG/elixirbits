defmodule Elixirbits.Organisations.OrganisationTest do
  use Elixirbits.DataCase, async: false

  import ElixirbitsWeb.ConnCase, only: [create_user: 0, create_user: 1]
  alias Elixirbits.AccessControl.Sitenav
  alias Elixirbits.Address
  alias Elixirbits.Organisations
  alias Elixirbits.Organisations.Organisation

  @system %{system: true}

  setup do
    Ash.create!(
      Sitenav,
      %{code: "ORG", name: "Organisation", url: "admin/organisation", level: 1},
      actor: @system
    )

    %{actor: create_user(roles: ["superuser"])}
  end

  test "the application has one organisation and current metadata is public", %{actor: actor} do
    assert {:ok, nil} = Organisations.current_organisation()
    assert {:ok, nil} = Organisations.organisation_settings(actor: actor)

    organisation = Organisations.create_organisation!(%{name: "Template business"}, actor: actor)
    assert organisation.key == "application"
    assert organisation.inserted_at
    assert organisation.updated_at

    assert {:ok, current} = Organisations.current_organisation()
    assert current.id == organisation.id
    assert current.name == "Template business"
    assert current.base_currency == "MYR"
    assert current.locale == "en"
    assert current.timezone == "Asia/Kuala_Lumpur"

    assert {:error, %Ash.Error.Invalid{}} =
             Organisations.create_organisation(%{name: "Second business"}, actor: actor)

    assert length(Ash.read!(Organisation, actor: @system)) == 1
  end

  test "public current reads cannot expose private settings or addresses", %{actor: actor} do
    organisation =
      Organisations.create_organisation!(
        %{
          name: "Private business",
          registration_no: "REG-123",
          tax_identification_no: "TAX-456",
          email: "private@example.com",
          phone: "+60123456789",
          addresses: [%{line_1: "Private office"}]
        },
        actor: actor
      )

    assert {:ok, current} = Organisations.current_organisation()
    assert Enum.sort(Map.keys(current)) == [:base_currency, :id, :locale, :name, :timezone]
    refute is_struct(current)

    assert {:error, %Ash.Error.Forbidden{}} = Organisations.organisation_settings()
    assert {:error, %Ash.Error.Forbidden{}} = Ash.read(Organisation)

    settings = Organisations.organisation_settings!(actor: actor, load: [:addresses])
    assert settings.id == organisation.id
    assert settings.registration_no == "REG-123"
    assert settings.tax_identification_no == "TAX-456"
    assert settings.email == "private@example.com"
    assert settings.phone == "+60123456789"
    assert [%{line_1: "Private office"}] = settings.addresses
  end

  test "organisation actions manage addresses with exactly one owner", %{actor: actor} do
    organisation =
      Organisations.create_organisation!(
        %{name: "Office", addresses: [%{line_1: "Original office"}]},
        actor: actor
      )
      |> Ash.load!(:addresses, actor: actor)

    assert [address] = organisation.addresses
    assert address.organisation_id == organisation.id
    assert is_nil(address.user_id)

    organisation =
      Organisations.update_organisation!(
        organisation,
        %{addresses: [%{id: address.id, line_1: "Updated office"}]},
        actor: actor
      )
      |> Ash.load!(:addresses, actor: actor)

    assert [%{id: id, line_1: "Updated office"}] = organisation.addresses
    assert id == address.id

    user = create_user()

    for owners <- [%{}, %{user_id: user.id, organisation_id: organisation.id}] do
      changeset =
        Address
        |> Ash.Changeset.for_create(:create, %{line_1: "Invalid owner"}, actor: @system)
        |> Ash.Changeset.force_change_attributes(owners)

      assert {:error, %Ash.Error.Invalid{} = error} = Ash.create(changeset)
      assert Exception.message(error) =~ "must belong to a user or the organisation"
    end
  end

  test "direct address access cannot bypass its parent resource", %{actor: actor} do
    organisation =
      Organisations.create_organisation!(
        %{name: "Office", addresses: [%{line_1: "Authorised office"}]},
        actor: actor
      )
      |> Ash.load!(:addresses, actor: actor)

    [address] = organisation.addresses
    assert {:error, %Ash.Error.Forbidden{}} = Ash.read(Address, actor: actor)

    assert {:error, %Ash.Error.Forbidden{}} =
             Ash.create(Address, %{line_1: "Direct"}, actor: actor)

    assert {:error, %Ash.Error.Forbidden{}} =
             Ash.update(address, %{line_1: "Direct"}, actor: actor)

    assert {:error, %Ash.Error.Forbidden{}} = Ash.destroy(address, actor: actor)
    assert Ash.get!(Address, address.id, actor: @system).line_1 == "Authorised office"
  end

  test "regional settings reject unknown currency and timezone", %{actor: actor} do
    for attrs <- [%{base_currency: "INVALID"}, %{timezone: "Unknown/Zone"}, %{locale: "invalid"}] do
      assert {:error, %Ash.Error.Invalid{}} =
               Organisations.create_organisation(Map.put(attrs, :name, "Office"), actor: actor)
    end
  end
end

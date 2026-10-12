defmodule Elixirbits.Organizations.OrganizationTest do
  use Elixirbits.DataCase, async: false

  import ElixirbitsWeb.ConnCase, only: [create_user: 0, create_user: 1]
  alias Elixirbits.AccessControl.Sitenav
  alias Elixirbits.Address
  alias Elixirbits.Organizations
  alias Elixirbits.Organizations.Organization

  @system %{system: true}

  setup do
    Ash.create!(
      Sitenav,
      %{code: "ORG", name: "Organization", url: "admin/organization", level: 1},
      actor: @system
    )

    %{actor: create_user(roles: ["superuser"])}
  end

  test "the application has one organization and current metadata is public", %{actor: actor} do
    assert {:ok, nil} = Organizations.current_organization()
    assert {:ok, nil} = Organizations.organization_settings(actor: actor)

    organization = Organizations.create_organization!(%{name: "Template business"}, actor: actor)
    assert organization.key == "application"
    assert organization.inserted_at
    assert organization.updated_at

    assert {:ok, current} = Organizations.current_organization()
    assert current.id == organization.id
    assert current.name == "Template business"
    assert current.base_currency == "MYR"
    assert current.locale == "en"
    assert current.timezone == "Asia/Kuala_Lumpur"

    assert {:error, %Ash.Error.Invalid{}} =
             Organizations.create_organization(%{name: "Second business"}, actor: actor)

    assert length(Ash.read!(Organization, actor: @system)) == 1
  end

  test "public current reads cannot expose private settings or addresses", %{actor: actor} do
    organization =
      Organizations.create_organization!(
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

    assert {:ok, current} = Organizations.current_organization()
    assert Enum.sort(Map.keys(current)) == [:base_currency, :id, :locale, :name, :timezone]
    refute is_struct(current)

    assert {:error, %Ash.Error.Forbidden{}} = Organizations.organization_settings()
    assert {:error, %Ash.Error.Forbidden{}} = Ash.read(Organization)

    settings = Organizations.organization_settings!(actor: actor, load: [:addresses])
    assert settings.id == organization.id
    assert settings.registration_no == "REG-123"
    assert settings.tax_identification_no == "TAX-456"
    assert settings.email == "private@example.com"
    assert settings.phone == "+60123456789"
    assert [%{line_1: "Private office"}] = settings.addresses
  end

  test "organization actions manage addresses with exactly one owner", %{actor: actor} do
    organization =
      Organizations.create_organization!(
        %{name: "Office", addresses: [%{line_1: "Original office"}]},
        actor: actor
      )
      |> Ash.load!(:addresses, actor: actor)

    assert [address] = organization.addresses
    assert address.organization_id == organization.id
    assert is_nil(address.user_id)

    organization =
      Organizations.update_organization!(
        organization,
        %{addresses: [%{id: address.id, line_1: "Updated office"}]},
        actor: actor
      )
      |> Ash.load!(:addresses, actor: actor)

    assert [%{id: id, line_1: "Updated office"}] = organization.addresses
    assert id == address.id

    user = create_user()

    for owners <- [%{}, %{user_id: user.id, organization_id: organization.id}] do
      changeset =
        Address
        |> Ash.Changeset.for_create(:create, %{line_1: "Invalid owner"}, actor: @system)
        |> Ash.Changeset.force_change_attributes(owners)

      assert {:error, %Ash.Error.Invalid{} = error} = Ash.create(changeset)
      assert Exception.message(error) =~ "must belong to a user or the organization"
    end
  end

  test "direct address access cannot bypass its parent resource", %{actor: actor} do
    organization =
      Organizations.create_organization!(
        %{name: "Office", addresses: [%{line_1: "Authorized office"}]},
        actor: actor
      )
      |> Ash.load!(:addresses, actor: actor)

    [address] = organization.addresses
    assert {:error, %Ash.Error.Forbidden{}} = Ash.read(Address, actor: actor)

    assert {:error, %Ash.Error.Forbidden{}} =
             Ash.create(Address, %{line_1: "Direct"}, actor: actor)

    assert {:error, %Ash.Error.Forbidden{}} =
             Ash.update(address, %{line_1: "Direct"}, actor: actor)

    assert {:error, %Ash.Error.Forbidden{}} = Ash.destroy(address, actor: actor)
    assert Ash.get!(Address, address.id, actor: @system).line_1 == "Authorized office"
  end

  test "regional settings reject unknown currency and timezone", %{actor: actor} do
    for attrs <- [%{base_currency: "INVALID"}, %{timezone: "Unknown/Zone"}, %{locale: "invalid"}] do
      assert {:error, %Ash.Error.Invalid{}} =
               Organizations.create_organization(Map.put(attrs, :name, "Office"), actor: actor)
    end
  end
end

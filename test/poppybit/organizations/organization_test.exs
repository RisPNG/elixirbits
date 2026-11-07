defmodule Poppybit.Organizations.OrganizationTest do
  use Poppybit.DataCase, async: false

  import PoppybitWeb.ConnCase, only: [create_user: 0, create_user: 1]
  alias Poppybit.AccessControl.Sitenav
  alias Poppybit.Accounts.User
  alias Poppybit.Address
  alias Poppybit.Organizations.OrganizationService
  alias Poppybit.Organizations.Organization

  @system %{system: true}

  setup do
    Ash.create!(
      Sitenav,
      %{code: "ORG", name: "Organization", url: "dashboard/admin/organization", level: 1},
      actor: @system
    )

    %{actor: create_user(roles: ["superuser"])}
  end

  test "the application has one organization and current metadata is public", %{actor: actor} do
    assert {:ok, nil} = OrganizationService.current_organization()
    assert {:ok, nil} = OrganizationService.organization_settings(actor: actor)

    organization =
      OrganizationService.create_organization!(%{name: "Template business"}, actor: actor)

    assert organization.key == "application"
    assert organization.inserted_at
    assert organization.updated_at

    assert {:ok, current} = OrganizationService.current_organization()
    assert current.id == organization.id
    assert current.name == "Template business"
    assert current.base_currency == "MYR"
    assert current.locale == "en"
    assert current.timezone == "Asia/Kuala_Lumpur"

    assert {:error, %Ash.Error.Invalid{}} =
             OrganizationService.create_organization(%{name: "Second business"}, actor: actor)

    assert length(Ash.read!(Organization, actor: @system)) == 1
  end

  test "public current reads cannot expose private settings or addresses", %{actor: actor} do
    organization =
      OrganizationService.create_organization!(
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

    assert {:ok, current} = OrganizationService.current_organization()
    assert Enum.sort(Map.keys(current)) == [:base_currency, :id, :locale, :name, :timezone]
    refute is_struct(current)

    assert {:error, %Ash.Error.Forbidden{}} = OrganizationService.organization_settings()
    assert {:error, %Ash.Error.Forbidden{}} = Ash.read(Organization)

    settings = OrganizationService.organization_settings!(actor: actor, load: [:addresses])
    assert settings.id == organization.id
    assert settings.registration_no == "REG-123"
    assert settings.tax_identification_no == "TAX-456"
    assert settings.email == "private@example.com"
    assert settings.phone == "+60123456789"
    assert [%{line_1: "Private office"}] = settings.addresses
  end

  test "organization actions manage addresses with exactly one owner", %{actor: actor} do
    organization =
      OrganizationService.create_organization!(
        %{name: "Office", addresses: [%{line_1: "Original office"}]},
        actor: actor
      )
      |> Ash.load!(:addresses, actor: actor)

    assert [address] = organization.addresses
    assert address.organization_id == organization.id
    assert is_nil(address.user_id)

    organization =
      OrganizationService.update_organization!(
        organization,
        %{addresses: [%{id: address.id, line_1: "Updated office"}]},
        actor: actor
      )
      |> Ash.load!(:addresses, actor: actor)

    assert [%{id: id, line_1: "Updated office"}] = organization.addresses
    assert id == address.id

    native =
      Address
      |> Ash.Changeset.for_create(:create, %{line_1: "Native default"}, actor: @system)
      |> Ash.Changeset.force_change_attribute(:organization_id, organization.id)
      |> Ash.create!()

    assert native.sequence == 1

    for sequence <- [0, -1] do
      changeset =
        Address
        |> Ash.Changeset.for_create(:create, %{line_1: "Invalid sequence", sequence: sequence},
          actor: @system
        )
        |> Ash.Changeset.force_change_attribute(:organization_id, organization.id)

      assert {:error, %Ash.Error.Invalid{} = error} = Ash.create(changeset)
      assert Enum.any?(error.errors, &(Map.get(&1, :field) == :sequence))
    end

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

  test "user and organization address positions survive reordering, removal, and insertion", %{
    actor: actor
  } do
    Ash.create!(Sitenav, %{code: "USERS", name: "Users", url: "dashboard/admin/users", level: 1},
      actor: @system
    )

    for resource <- [User, Organization] do
      addresses = [
        %{line_1: "A", sequence: 0},
        %{"line_1" => "B", "sequence" => 90},
        %{line_1: "C", sequence: 0}
      ]

      parent =
        case resource do
          User ->
            Ash.create!(
              User,
              %{
                email: "ordered@example.com",
                password: "password1234",
                password_confirmation: "password1234",
                addresses: addresses
              },
              action: :create,
              actor: actor
            )

          Organization ->
            OrganizationService.create_organization!(
              %{name: "Ordered organization", addresses: addresses},
              actor: actor
            )
        end

      parent = Ash.get!(resource, parent.id, actor: actor, load: [:addresses])

      assert Enum.map(parent.addresses, &{&1.sequence, &1.line_1}) == [
               {1, "A"},
               {2, "B"},
               {3, "C"}
             ]

      [first, second, third] = parent.addresses
      original_contents = Map.new(parent.addresses, &{&1.id, &1.line_1})

      params = %{
        addresses: [
          %{id: third.id, sequence: 0},
          %{"id" => first.id, "sequence" => 999},
          %{id: second.id, sequence: 0}
        ]
      }

      case resource do
        User -> Ash.update!(parent, params, action: :update, actor: actor)
        Organization -> OrganizationService.update_organization!(parent, params, actor: actor)
      end

      reordered = Ash.get!(resource, parent.id, actor: actor, load: [:addresses])
      assert Enum.map(reordered.addresses, & &1.id) == [third.id, first.id, second.id]
      assert Enum.map(reordered.addresses, & &1.sequence) == [1, 2, 3]
      assert Map.new(reordered.addresses, &{&1.id, &1.line_1}) == original_contents

      params = %{
        addresses: [
          %{"id" => first.id, "sequence" => 0},
          %{line_1: "D", sequence: 90},
          %{"id" => second.id, "sequence" => 222}
        ]
      }

      case resource do
        User -> Ash.update!(reordered, params, action: :update, actor: actor)
        Organization -> OrganizationService.update_organization!(reordered, params, actor: actor)
      end

      saved = Ash.get!(resource, parent.id, actor: actor, load: [:addresses])

      assert Enum.map(saved.addresses, &{&1.sequence, &1.line_1}) == [
               {1, "A"},
               {2, "D"},
               {3, "B"}
             ]

      assert hd(saved.addresses).id == first.id
      assert List.last(saved.addresses).id == second.id
      assert Ash.get!(Address, third.id, actor: @system, not_found_error?: false) == nil
    end
  end

  test "direct address access cannot bypass its parent resource", %{actor: actor} do
    organization =
      OrganizationService.create_organization!(
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
               OrganizationService.create_organization(Map.put(attrs, :name, "Office"),
                 actor: actor
               )
    end
  end
end

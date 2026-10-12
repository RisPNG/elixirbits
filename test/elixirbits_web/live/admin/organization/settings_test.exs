defmodule ElixirbitsWeb.Admin.OrganizationLive.SettingsTest do
  use ElixirbitsWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Elixirbits.AccessControl.RolePerm
  alias Elixirbits.AccessControl.Sitenav
  alias Elixirbits.Organizations

  @system %{system: true}

  setup do
    Ash.create!(
      Sitenav,
      %{code: "ORG", name: "Organization", url: "admin/organization", level: 1},
      actor: @system
    )

    :ok
  end

  test "an authorized operator creates settings and updates their nested address", %{conn: conn} do
    actor = create_user(roles: ["superuser"])
    conn = log_in_user(conn, actor)
    {:ok, view, _html} = live(conn, ~p"/admin/organization")

    assert has_element?(view, "#organization-form[novalidate]")
    assert has_element?(view, "#organization-form button[type='submit']")
    assert has_element?(view, "button[phx-click=add_form][data-tooltip='Add']")
    render_click(view, "add_form", %{})

    html =
      view
      |> form("#organization-form",
        form: %{
          name: "Template business",
          registration_no: "REG-123",
          base_currency: "GBP",
          locale: "en",
          timezone: "Europe/London",
          email: "office@example.com",
          addresses: %{"0" => %{line_1: "Original office", city: "London"}}
        }
      )
      |> render_submit()

    assert html =~ "Organization settings saved."
    organization = Organizations.organization_settings!(actor: @system, load: [:addresses])
    assert organization.name == "Template business"
    assert organization.base_currency == "GBP"
    assert organization.registration_no == "REG-123"
    assert [address] = organization.addresses
    assert address.organization_id == organization.id
    assert is_nil(address.user_id)

    view
    |> form("#organization-form",
      form: %{
        name: "Updated business",
        addresses: %{"0" => %{line_1: "Updated office"}}
      }
    )
    |> render_submit()

    updated = Organizations.organization_settings!(actor: @system, load: [:addresses])
    assert updated.id == organization.id
    assert updated.name == "Updated business"
    assert [%{id: address_id, line_1: "Updated office"}] = updated.addresses
    assert address_id == address.id
  end

  test "a settings reader cannot submit a forged update", %{conn: conn} do
    Organizations.create_organization!(%{name: "Original"}, actor: @system)
    role = "organization-reader"
    actor = create_user(roles: [role])
    Ash.create!(RolePerm, %{roles_code: role, sitenav_code: "ORG", level: 4}, actor: @system)
    {:ok, view, _html} = live(log_in_user(conn, actor), ~p"/admin/organization")

    refute has_element?(view, "#organization-form button[type='submit']")

    assert render_submit(view, "save", %{"form" => %{"name" => "Forged"}}) =~
             "do not have permission"

    assert Organizations.organization_settings!(actor: @system).name == "Original"
  end

  test "create-only access can initialize settings and discard an unsaved address", %{conn: conn} do
    role = "organization-creator"
    actor = create_user(roles: [role])
    Ash.create!(RolePerm, %{roles_code: role, sitenav_code: "ORG", level: 6}, actor: @system)
    {:ok, view, _} = live(log_in_user(conn, actor), ~p"/admin/organization")

    assert has_element?(view, "#organization-form button[type=submit]")
    view |> element("button[phx-click=add_form]") |> render_click()
    view |> element("button[phx-click=remove_form]") |> render_click()
    refute has_element?(view, "input[name='form[addresses][0][line_1]']")
    view |> element("button[phx-click=add_form]") |> render_click()

    view
    |> form("#organization-form",
      form: %{
        name: "First organization",
        addresses: %{"0" => %{line_1: "First office"}}
      }
    )
    |> render_submit()

    organization = Organizations.organization_settings!(actor: @system, load: [:addresses])
    assert organization.name == "First organization"
    assert [%{line_1: "First office"}] = organization.addresses
    refute has_element?(view, "#organization-form button[type=submit]")
    refute has_element?(view, "button[phx-click=add_form]")
    refute has_element?(view, "button[phx-click=remove_form]")
  end

  test "anonymous and ungranted users cannot read the settings screen", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/sign-in"}}} = live(conn, ~p"/admin/organization")
    conn = log_in_user(conn, create_user())
    assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/admin/organization")
  end
end

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

  defp grant(conn, level) do
    code = "organization-operator-#{System.unique_integer([:positive])}"
    actor = create_user(roles: [code])
    Ash.create!(RolePerm, %{roles_code: code, sitenav_code: "ORG", level: level}, actor: @system)
    log_in_user(conn, actor)
  end

  test "an authorized operator creates settings and updates their nested address", %{conn: conn} do
    actor = create_user(roles: ["superuser"])
    conn = log_in_user(conn, actor)
    {:ok, view, _html} = live(conn, ~p"/admin/organization/update")

    assert has_element?(view, "#organization-form[novalidate]")
    assert has_element?(view, "#organization-form button[type='submit']")
    assert has_element?(view, "button[phx-click=add_form][data-tooltip='Add']")
    render_click(view, "add_form", %{})

    result =
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

    {:ok, view, html} = follow_redirect(result, conn, ~p"/admin/organization")
    assert html =~ "Organization settings saved."
    organization = Organizations.organization_settings!(actor: @system, load: [:addresses])
    assert organization.name == "Template business"
    assert organization.base_currency == "GBP"
    assert organization.registration_no == "REG-123"
    assert [address] = organization.addresses
    assert address.organization_id == organization.id
    assert is_nil(address.user_id)

    result =
      view
      |> element("#organization-form header a[href='/admin/organization/update']")
      |> render_click()

    {:ok, view, _html} = follow_redirect(result, conn, ~p"/admin/organization/update")

    assert {:error, {:live_redirect, %{to: "/admin/organization"}}} =
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
    {:ok, view, _html} = live(grant(conn, 4), ~p"/admin/organization/update")

    refute has_element?(view, "#organization-form button[type='submit']")

    assert render_submit(view, "save", %{"form" => %{"name" => "Forged"}}) =~
             "do not have permission"

    assert Organizations.organization_settings!(actor: @system).name == "Original"
  end

  test "create-only access can initialize settings and discard an unsaved address", %{conn: conn} do
    conn = grant(conn, 6)
    {:ok, view, _} = live(conn, ~p"/admin/organization/update")

    assert has_element?(view, "#organization-form button[type=submit]")
    view |> element("button[phx-click=add_form]") |> render_click()
    view |> element("button[phx-click=remove_form]") |> render_click()
    refute has_element?(view, "input[name='form[addresses][0][line_1]']")
    view |> element("button[phx-click=add_form]") |> render_click()

    result =
      view
      |> form("#organization-form",
        form: %{
          name: "First organization",
          addresses: %{"0" => %{line_1: "First office"}}
        }
      )
      |> render_submit()

    {:ok, view, _html} = follow_redirect(result, conn, ~p"/admin/organization")

    organization = Organizations.organization_settings!(actor: @system, load: [:addresses])
    assert organization.name == "First organization"
    assert [%{line_1: "First office"}] = organization.addresses
    refute has_element?(view, "#organization-form button[type=submit]")
    refute has_element?(view, "button[phx-click=add_form]")
    refute has_element?(view, "button[phx-click=remove_form]")
    refute has_element?(view, "a[href='/admin/organization/update']")
  end

  test "settings open in View mode with saved details and addresses for readers and administrators",
       %{
         conn: conn
       } do
    Organizations.create_organization!(
      %{
        name: "Stored organization",
        registration_no: "STORED-123",
        email: "stored@example.com",
        addresses: [%{line_1: "Stored office", city: "London"}]
      },
      actor: @system
    )

    for level <- [4, 16] do
      {:ok, view, _html} = live(grant(conn, level), ~p"/admin/organization")

      assert has_element?(view, "#organization-form", "Stored organization")
      assert has_element?(view, "#organization-form", "STORED-123")
      assert has_element?(view, "#organization-form", "stored@example.com")
      assert has_element?(view, "#organization-form", "Stored office")
      assert has_element?(view, "#organization-form", "London")
      refute has_element?(view, "#organization-form[phx-change]")
      refute has_element?(view, "#organization-form[phx-submit]")
      refute has_element?(view, "#organization-form input[name='form[name]']")
      refute has_element?(view, "#organization-form input[name='form[addresses][0][line_1]']")
      refute has_element?(view, "#organization-form button[type=submit]")
      refute has_element?(view, "#organization-form button[phx-click=add_form]")
      refute has_element?(view, "#organization-form button[phx-click=remove_form]")
    end
  end

  test "Update uses create access for missing settings and update access for existing settings",
       %{
         conn: conn
       } do
    for {exists?, access} <- [
          {false, [{4, false}, {5, false}, {6, true}, {16, true}]},
          {true, [{4, false}, {5, true}, {6, false}, {16, true}]}
        ] do
      if exists? do
        Organizations.create_organization!(%{name: "Existing organization"}, actor: @system)
      end

      for {level, editable?} <- access do
        operator_conn = grant(conn, level)
        {:ok, view, _html} = live(operator_conn, ~p"/admin/organization")

        for section <- ["header", "footer"] do
          assert has_element?(
                   view,
                   "#organization-form #{section} a[href='/admin/organization/update'][data-tooltip=Update]"
                 ) == editable?

          refute has_element?(view, "#organization-form #{section} button[type=submit]")
        end

        if editable? do
          result =
            view
            |> element("#organization-form footer a[href='/admin/organization/update']")
            |> render_click()

          {:ok, edit, _html} =
            follow_redirect(result, operator_conn, ~p"/admin/organization/update")

          assert has_element?(edit, "#organization-form input[name='form[name]']")

          for section <- ["header", "footer"] do
            assert has_element?(edit, "#organization-form #{section} button[type=submit]")

            assert has_element?(
                     edit,
                     "#organization-form #{section} a[href='/admin/organization'][data-tooltip=Back]"
                   )
          end

          result =
            edit
            |> element("#organization-form footer a[href='/admin/organization']")
            |> render_click()

          {:ok, read, _html} = follow_redirect(result, operator_conn, ~p"/admin/organization")
          refute has_element?(read, "#organization-form button[type=submit]")
        end
      end
    end
  end

  test "View rejects forged initialization and edits even for a superuser", %{conn: conn} do
    conn = log_in_user(conn, create_user(roles: ["superuser"]))
    {:ok, empty, _html} = live(conn, ~p"/admin/organization")
    render_submit(empty, "save", %{"form" => %{"name" => "Forged initialization"}})
    assert Organizations.organization_settings!(actor: @system) == nil

    organization =
      Organizations.create_organization!(
        %{name: "Unchanged organization", addresses: [%{line_1: "Unchanged office"}]},
        actor: @system
      )

    {:ok, view, _html} = live(conn, ~p"/admin/organization")
    render_change(view, "validate", %{"form" => %{"name" => "Forged organization"}})
    render_click(view, "add_form")
    render_click(view, "remove_form", %{"path" => "form[addresses][0]"})

    render_submit(view, "save", %{
      "form" => %{
        "name" => "Forged organization",
        "addresses" => %{"0" => %{"line_1" => "Forged office"}}
      }
    })

    unchanged = Organizations.organization_settings!(actor: @system, load: [:addresses])
    assert unchanged.id == organization.id
    assert unchanged.name == "Unchanged organization"
    assert [%{line_1: "Unchanged office"}] = unchanged.addresses
    assert has_element?(view, "#organization-form", "Unchanged organization")
    assert has_element?(view, "#organization-form", "Unchanged office")
  end

  test "anonymous and ungranted users cannot read the settings screen", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/sign-in"}}} = live(conn, ~p"/admin/organization")
    conn = log_in_user(conn, create_user())
    assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/admin/organization")
  end
end

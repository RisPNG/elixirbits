defmodule PoppybitWeb.Dashboard.OrganizationLive.SettingsTest do
  use PoppybitWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Poppybit.AccessControl.RolePerm
  alias Poppybit.AccessControl.Sitenav
  alias Poppybit.CoreUtils.Resource.AuditLog
  alias Poppybit.Organizations.OrganizationService
  alias Poppybit.Organizations.Organization

  @system %{system: true}

  setup do
    Ash.create!(
      Sitenav,
      %{code: "ORG", name: "Organization", url: "dashboard/admin/organization", level: 1},
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
    {:ok, view, _html} = live(conn, ~p"/dashboard/admin/organization/update")

    assert has_element?(view, "#organization-form[novalidate]")
    assert has_element?(view, "#organization-form button[type='submit']")
    assert has_element?(view, "button[phx-click=add_form][data-tooltip='Add']")

    for {field, value} <- [
          {"base_currency", "MYR"},
          {"locale", "en"},
          {"timezone", "Asia/Kuala_Lumpur"}
        ] do
      assert has_element?(
               view,
               "#form_#{field}[phx-hook=PetalComboBox] select[name='form[#{field}]'][required] option[value='#{value}'][selected]"
             )

      refute has_element?(view, "#form_#{field} [data-pc-combo-clear]")
    end

    refute has_element?(view, "#form_timezone", "Automatic (browser)")

    assert has_element?(
             view,
             "#form_phone_tel_wrapper[phx-hook=TelInput] input[type=tel][data-tel-number]"
           )

    render_click(view, "add_form", %{})

    assert has_element?(
             view,
             "input#form_addresses_0_contact_tel_no[type=text][name='form[addresses][0][contact_tel_no]']"
           )

    refute has_element?(
             view,
             "#form_addresses_0_contact_tel_no_tel_wrapper, [name='form[addresses][0][contact_tel_no_country_code]']"
           )

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
          addresses: %{
            "0" => %{
              line_1: "Original office",
              city: "London",
              contact_tel_no: "office-contact@example.com"
            }
          }
        }
      )
      |> render_submit(%{
        "form" => %{
          "phone" => "+442012345678"
        }
      })

    {:ok, view, html} = follow_redirect(result, conn, ~p"/dashboard/admin/organization")
    assert html =~ "Organization settings saved."
    organization = OrganizationService.organization_settings!(actor: @system, load: [:addresses])
    assert organization.name == "Template business"
    assert organization.base_currency == "GBP"
    assert organization.locale == "en"
    assert organization.timezone == "Europe/London"
    assert organization.phone == "+442012345678"
    assert organization.registration_no == "REG-123"
    assert [address] = organization.addresses
    assert address.contact_tel_no == "office-contact@example.com"
    assert address.organization_id == organization.id
    assert is_nil(address.user_id)

    for {field, value} <- [
          {"base_currency", "GBP"},
          {"locale", "en"},
          {"timezone", "Europe/London"},
          {"phone", "+442012345678"}
        ] do
      assert has_element?(view, "span#form_#{field}", value)
    end

    assert has_element?(
             view,
             "span#form_addresses_0_contact_tel_no",
             "office-contact@example.com"
           )

    refute has_element?(
             view,
             "#organization-form [phx-hook=PetalComboBox], #organization-form [phx-hook=TelInput]"
           )

    {:ok, history} = AuditLog.history(Organization, organization.id, actor)
    original = hd(history.revisions)

    result =
      view
      |> element("#organization-form header a[href='/dashboard/admin/organization/update']")
      |> render_click()

    {:ok, view, _html} = follow_redirect(result, conn, ~p"/dashboard/admin/organization/update")

    assert has_element?(view, "#form_base_currency select option[value=GBP][selected]")
    assert has_element?(view, "#form_timezone select option[value='Europe/London'][selected]")

    assert has_element?(
             view,
             "input#form_addresses_0_contact_tel_no[type=text][name='form[addresses][0][contact_tel_no]'][value='office-contact@example.com']"
           )

    refute has_element?(
             view,
             "#form_addresses_0_contact_tel_no_tel_wrapper, [name='form[addresses][0][contact_tel_no_country_code]']"
           )

    result =
      view
      |> form("#organization-form",
        form: %{
          name: "Updated business",
          base_currency: "USD",
          timezone: "Asia/Singapore",
          addresses: %{
            "0" => %{line_1: "Updated office", contact_tel_no: "operations@example.com"}
          }
        }
      )
      |> render_submit()

    {:ok, view, _html} = follow_redirect(result, conn, ~p"/dashboard/admin/organization")

    updated = OrganizationService.organization_settings!(actor: @system, load: [:addresses])
    assert updated.id == organization.id
    assert updated.name == "Updated business"
    assert updated.base_currency == "USD"
    assert updated.locale == "en"
    assert updated.timezone == "Asia/Singapore"
    assert updated.phone == organization.phone
    assert [%{id: address_id, line_1: "Updated office"}] = updated.addresses
    assert address_id == address.id
    assert hd(updated.addresses).contact_tel_no == "operations@example.com"
    assert has_element?(view, "span#form_base_currency", "USD")
    assert has_element?(view, "span#form_timezone", "Asia/Singapore")

    view |> element("header a[data-tooltip=History]") |> render_click()
    assert_patch(view)
    view |> element("#revision-#{original.id}") |> render_click()
    assert_patch(view, "/dashboard/admin/organization?version=#{original.id}")

    for {field, value} <- [{"base_currency", "GBP"}, {"timezone", "Europe/London"}] do
      assert has_element?(
               view,
               "span#form-#{original.id}-previous_#{field}[data-audit-changed=true][data-audit-side=previous]",
               value
             )
    end

    assert has_element?(view, "span#form-#{original.id}-previous_locale", "en")
    assert has_element?(view, "span#form-#{original.id}-previous_phone", organization.phone)

    assert has_element?(
             view,
             "span#form-#{original.id}-previous_addresses_0_contact_tel_no",
             "office-contact@example.com"
           )

    view |> form("#audit-value-form", audit: %{side: "current"}) |> render_change()
    assert_patch(view)

    for {field, value} <- [{"base_currency", "USD"}, {"timezone", "Asia/Singapore"}] do
      assert has_element?(
               view,
               "span#form-#{original.id}-current_#{field}[data-audit-changed=true][data-audit-side=current]",
               value
             )
    end

    assert has_element?(
             view,
             "span#form-#{original.id}-current_addresses_0_contact_tel_no",
             "operations@example.com"
           )

    refute has_element?(view, "#organization-form button[type=submit]")
    assert OrganizationService.organization_settings!(actor: @system).base_currency == "USD"
    {:ok, current_history} = AuditLog.history(Organization, organization.id, actor)
    assert length(current_history.revisions) == length(history.revisions) + 1
  end

  test "new address numbers swap unsaved forms and renumber after removing and adding", %{
    conn: conn
  } do
    conn = grant(conn, 7)
    {:ok, view, _html} = live(conn, ~p"/dashboard/admin/organization/update")
    render_click(view, "add_form", %{})
    render_click(view, "add_form", %{})

    for {index, number} <- [{0, 1}, {1, 2}] do
      assert has_element?(
               view,
               "input[name='address_position[#{index}]'][value='#{number}'][min='1'][max='2'][step='1']:not([phx-change])"
             )
    end

    view
    |> form("#organization-form",
      form: %{
        name: "Numbered organization",
        addresses: %{
          "0" => %{line_1: "A", contact_name: "A contact"},
          "1" => %{line_1: "B", contact_name: "B contact"}
        }
      },
      address_position: %{"0" => "2"}
    )
    |> render_change(%{"_target" => ["address_position", "0"]})

    assert has_element?(view, "input[name='form[addresses][0][line_1]'][value=B]")
    assert has_element?(view, "input[name='form[addresses][0][contact_name]'][value='B contact']")
    assert has_element?(view, "input[name='form[addresses][1][line_1]'][value=A]")
    assert has_element?(view, "input[name='form[addresses][1][contact_name]'][value='A contact']")

    view
    |> element("button[phx-click=remove_form][phx-value-path='form[addresses][1]']")
    |> render_click()

    assert has_element?(view, "input[name='address_position[0]'][value='1'][max='1']")
    render_click(view, "add_form", %{})
    assert has_element?(view, "input[name='address_position[1]'][value='2'][max='2']")

    view
    |> form("#organization-form", form: %{addresses: %{"1" => %{line_1: "C"}}})
    |> render_change()

    result = view |> form("#organization-form") |> render_submit()
    {:ok, saved_view, _html} = follow_redirect(result, conn, ~p"/dashboard/admin/organization")
    refute has_element?(saved_view, "input[name^='address_position[']:not([disabled])")
    saved = OrganizationService.organization_settings!(actor: @system, load: [:addresses])
    assert Enum.map(saved.addresses, &{&1.sequence, &1.line_1}) == [{1, "B"}, {2, "C"}]
    assert hd(saved.addresses).contact_name == "B contact"
    {:ok, edit, _html} = live(conn, ~p"/dashboard/admin/organization/update")
    assert has_element?(edit, "input[name='form[addresses][0][line_1]'][value=B]")
    assert has_element?(edit, "input[name='form[addresses][1][line_1]'][value=C]")
  end

  test "a settings reader cannot submit a forged update", %{conn: conn} do
    OrganizationService.create_organization!(%{name: "Original"}, actor: @system)
    {:ok, view, _html} = live(grant(conn, 4), ~p"/dashboard/admin/organization/update")

    refute has_element?(view, "#organization-form button[type='submit']")

    assert render_submit(view, "save", %{"form" => %{"name" => "Forged"}}) =~
             "do not have permission"

    assert OrganizationService.organization_settings!(actor: @system).name == "Original"
  end

  test "create-only access can initialize settings and discard an unsaved address", %{conn: conn} do
    conn = grant(conn, 6)
    {:ok, view, _} = live(conn, ~p"/dashboard/admin/organization/update")

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

    {:ok, view, _html} = follow_redirect(result, conn, ~p"/dashboard/admin/organization")

    organization = OrganizationService.organization_settings!(actor: @system, load: [:addresses])
    assert organization.name == "First organization"
    assert [%{line_1: "First office"}] = organization.addresses
    refute has_element?(view, "#organization-form button[type=submit]")
    refute has_element?(view, "button[phx-click=add_form]")
    refute has_element?(view, "button[phx-click=remove_form]")
    refute has_element?(view, "a[href='/dashboard/admin/organization/update']")
  end

  test "settings open in View mode with saved details and addresses for readers and administrators",
       %{
         conn: conn
       } do
    OrganizationService.create_organization!(
      %{
        name: "Stored organization",
        registration_no: "STORED-123",
        email: "stored@example.com",
        addresses: [%{line_1: "Stored office", city: "London"}]
      },
      actor: @system
    )

    for level <- [4, 16] do
      {:ok, view, _html} = live(grant(conn, level), ~p"/dashboard/admin/organization")

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
        OrganizationService.create_organization!(%{name: "Existing organization"}, actor: @system)
      end

      for {level, editable?} <- access do
        operator_conn = grant(conn, level)
        {:ok, view, _html} = live(operator_conn, ~p"/dashboard/admin/organization")

        for section <- ["header", "footer"] do
          assert has_element?(
                   view,
                   "#organization-form #{section} a[href='/dashboard/admin/organization/update'][data-tooltip=Update]"
                 ) == editable?

          refute has_element?(view, "#organization-form #{section} button[type=submit]")
        end

        if editable? do
          result =
            view
            |> element("#organization-form footer a[href='/dashboard/admin/organization/update']")
            |> render_click()

          {:ok, edit, _html} =
            follow_redirect(result, operator_conn, ~p"/dashboard/admin/organization/update")

          assert has_element?(edit, "#organization-form input[name='form[name]']")

          for section <- ["header", "footer"] do
            assert has_element?(edit, "#organization-form #{section} button[type=submit]")

            assert has_element?(
                     edit,
                     "#organization-form #{section} a[href='/dashboard/admin/organization'][data-tooltip=View]"
                   )

            refute has_element?(edit, "#organization-form #{section} a[data-tooltip=Back]")

            unless exists? do
              refute has_element?(edit, "#organization-form #{section} a[data-tooltip=History]")
            end
          end

          result =
            edit
            |> element("#organization-form footer a[href='/dashboard/admin/organization']")
            |> render_click()

          {:ok, read, _html} =
            follow_redirect(result, operator_conn, ~p"/dashboard/admin/organization")

          refute has_element?(read, "#organization-form button[type=submit]")

          unless exists? do
            assert OrganizationService.organization_settings!(actor: @system) == nil
            refute has_element?(read, "#organization-form a[data-tooltip=History]")
          end
        end
      end
    end
  end

  test "View rejects forged initialization and edits even for a superuser", %{conn: conn} do
    conn = log_in_user(conn, create_user(roles: ["superuser"]))
    {:ok, empty, _html} = live(conn, ~p"/dashboard/admin/organization")
    render_submit(empty, "save", %{"form" => %{"name" => "Forged initialization"}})
    assert OrganizationService.organization_settings!(actor: @system) == nil

    organization =
      OrganizationService.create_organization!(
        %{name: "Unchanged organization", addresses: [%{line_1: "Unchanged office"}]},
        actor: @system
      )

    {:ok, view, _html} = live(conn, ~p"/dashboard/admin/organization")
    render_change(view, "validate", %{"form" => %{"name" => "Forged organization"}})
    render_click(view, "add_form")
    render_click(view, "remove_form", %{"path" => "form[addresses][0]"})

    render_submit(view, "save", %{
      "form" => %{
        "name" => "Forged organization",
        "addresses" => %{"0" => %{"line_1" => "Forged office"}}
      }
    })

    unchanged = OrganizationService.organization_settings!(actor: @system, load: [:addresses])
    assert unchanged.id == organization.id
    assert unchanged.name == "Unchanged organization"
    assert [%{line_1: "Unchanged office"}] = unchanged.addresses
    assert has_element?(view, "#organization-form", "Unchanged organization")
    assert has_element?(view, "#organization-form", "Unchanged office")
  end

  test "anonymous and ungranted users cannot read the settings screen", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/dashboard/sign-in"}}} =
             live(conn, ~p"/dashboard/admin/organization")

    conn = log_in_user(conn, create_user())

    assert {:error, {:redirect, %{to: "/dashboard"}}} =
             live(conn, ~p"/dashboard/admin/organization")
  end
end

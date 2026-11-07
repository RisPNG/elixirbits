defmodule PoppybitWeb.Admin.PageActionsTest do
  use PoppybitWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Poppybit.AccessControl.Role
  alias Poppybit.AccessControl.RolePerm
  alias Poppybit.AccessControl.Sitenav
  alias Poppybit.Accounts.User
  alias Poppybit.Organizations.OrganizationService
  alias Poppybit.Organizations.Organization

  @system %{system: true}

  setup do
    for {code, path} <- [
          {"USERS", "dashboard/admin/users"},
          {"ROLES", "dashboard/admin/roles"},
          {"ORG", "dashboard/admin/organization"}
        ] do
      Ash.create!(Sitenav, %{code: code, name: code, url: path, level: 1}, actor: @system)
    end

    :ok
  end

  defp grant(conn, levels) do
    code = "page-operator-#{System.unique_integer([:positive])}"
    user = create_user(roles: [code])

    for {page, level} <- levels do
      Ash.create!(RolePerm, %{roles_code: code, sitenav_code: page, level: level}, actor: @system)
    end

    log_in_user(conn, user)
  end

  test "collection creation links appear at both ends only with create access", %{conn: conn} do
    for {page, path, id} <- [
          {"USERS", "/dashboard/admin/users", "new-user"},
          {"ROLES", "/dashboard/admin/roles", "new-role"}
        ],
        {level, create?} <- [{4, false}, {6, true}] do
      operator_conn = grant(conn, %{page => level})
      {:ok, view, _html} = live(operator_conn, path)
      document = view |> render_async() |> Floki.parse_document!()
      destination = path <> "/create"

      assert has_element?(view, "header a##{id}[href='#{destination}']") == create?
      assert has_element?(view, "footer a##{id}-bottom[href='#{destination}']") == create?

      if create? do
        assert length(Floki.find(document, "##{id}")) == 1
        assert length(Floki.find(document, "##{id}-bottom")) == 1

        assert {:error, {:live_redirect, %{to: ^destination}}} =
                 view |> element("##{id}-bottom") |> render_click()
      end
    end
  end

  test "bottom user actions submit the shared creation and update forms", %{conn: conn} do
    conn = grant(conn, %{"USERS" => 7})
    {:ok, view, _html} = live(conn, ~p"/dashboard/admin/users/create")

    for section <- ["header", "footer"] do
      assert has_element?(view, "#user-form #{section} button[type=submit]")

      assert has_element?(
               view,
               "#user-form #{section} a[href='/dashboard/admin/users'][data-tooltip=Back]"
             )

      refute has_element?(view, "#user-form #{section} a[data-tooltip=View]")
    end

    document = view |> render() |> Floki.parse_document!()
    assert length(Floki.find(document, "#user-form button[type=submit]")) == 2

    view
    |> form("#user-form",
      form: %{
        email: "invalid-email",
        password: "created-password",
        password_confirmation: "created-password"
      }
    )
    |> render_submit()

    assert has_element?(view, "#user-form .text-error")
    assert has_element?(view, "#user-form footer button[type=submit]")

    result =
      view
      |> form("#user-form",
        form: %{
          email: "bottom-user@example.com",
          password: "created-password",
          password_confirmation: "created-password",
          display_name: "Created from footer"
        }
      )
      |> render_submit()

    user = Ash.get!(User, %{email: "bottom-user@example.com"}, actor: @system)
    assert user.display_name == "Created from footer"
    destination = ~p"/dashboard/admin/users/#{user.id}/read"
    {:ok, saved_view, _html} = follow_redirect(result, conn, destination)
    assert has_element?(saved_view, "#user-form fieldset[disabled]")

    assert has_element?(
             saved_view,
             "input[name='form[display_name]'][value='Created from footer']"
           )

    refute has_element?(saved_view, "#user-form button[type=submit]")
    {:ok, view, _html} = live(conn, ~p"/dashboard/admin/users/#{user.id}/update")

    for section <- ["header", "footer"] do
      assert has_element?(view, "#user-form #{section} button[type=submit]")

      assert has_element?(
               view,
               "#user-form #{section} a[href='/dashboard/admin/users'][data-tooltip=Back]"
             )
    end

    result =
      view
      |> form("#user-form", form: %{display_name: "Updated from footer"})
      |> render_submit()

    assert Ash.get!(User, user.id, actor: @system).display_name == "Updated from footer"
    {:ok, saved_view, _html} = follow_redirect(result, conn, destination)
    assert has_element?(saved_view, "#user-form fieldset[disabled]")

    assert has_element?(
             saved_view,
             "input[name='form[display_name]'][value='Updated from footer']"
           )

    refute has_element?(saved_view, "#user-form button[type=submit]")
  end

  test "bottom role actions submit the shared creation and update forms", %{conn: conn} do
    conn = grant(conn, %{"ROLES" => 7})
    {:ok, view, _html} = live(conn, ~p"/dashboard/admin/roles/create")

    for section <- ["header", "footer"] do
      assert has_element?(view, "#role-form #{section} button[type=submit]")

      assert has_element?(
               view,
               "#role-form #{section} a[href='/dashboard/admin/roles'][data-tooltip=Back]"
             )

      refute has_element?(view, "#role-form #{section} a[data-tooltip=View]")
    end

    result =
      view
      |> form("#role-form", form: %{code: "bottom-role", name: "Created from footer"})
      |> render_submit()

    role = Ash.get!(Role, %{code: "bottom-role"}, actor: @system)
    assert role.name == "Created from footer"
    destination = ~p"/dashboard/admin/roles/#{role.id}/read"
    {:ok, saved_view, _html} = follow_redirect(result, conn, destination)
    assert has_element?(saved_view, "#role-form fieldset[disabled]")
    assert has_element?(saved_view, "input[name='form[name]'][value='Created from footer']")
    refute has_element?(saved_view, "#role-form button[type=submit]")
    {:ok, view, _html} = live(conn, ~p"/dashboard/admin/roles/#{role.id}/update")

    for section <- ["header", "footer"] do
      assert has_element?(view, "#role-form #{section} button[type=submit]")

      assert has_element?(
               view,
               "#role-form #{section} a[href='/dashboard/admin/roles'][data-tooltip=Back]"
             )
    end

    result =
      view
      |> form("#role-form", form: %{name: "Updated from footer"})
      |> render_submit()

    assert Ash.get!(Role, role.id, actor: @system).name == "Updated from footer"
    {:ok, saved_view, _html} = follow_redirect(result, conn, destination)
    assert has_element?(saved_view, "#role-form fieldset[disabled]")
    assert has_element?(saved_view, "input[name='form[name]'][value='Updated from footer']")
    refute has_element?(saved_view, "#role-form button[type=submit]")
  end

  test "bottom organization actions create and update the same settings", %{conn: conn} do
    conn = grant(conn, %{"ORG" => 7})
    {:ok, view, _html} = live(conn, ~p"/dashboard/admin/organization/update")

    for section <- ["header", "footer"] do
      assert has_element?(view, "#organization-form #{section} button[type=submit]")

      assert has_element?(
               view,
               "#organization-form #{section} a[href='/dashboard/admin/organization'][data-tooltip=View]"
             )

      refute has_element?(view, "#organization-form #{section} a[data-tooltip=Back]")
      refute has_element?(view, "#organization-form #{section} a[data-tooltip=History]")
    end

    result =
      view
      |> form("#organization-form", form: %{name: "Created from footer"})
      |> render_submit()

    {:ok, view, html} = follow_redirect(result, conn, ~p"/dashboard/admin/organization")
    assert html =~ "Organization settings saved."
    organization = OrganizationService.organization_settings!(actor: @system)
    assert organization.name == "Created from footer"

    for section <- ["header", "footer"] do
      refute has_element?(view, "#organization-form #{section} button[type=submit]")

      assert has_element?(
               view,
               "#organization-form #{section} a[href='/dashboard/admin/organization/update'][data-tooltip=Update]"
             )
    end

    result =
      view
      |> element("#organization-form footer a[href='/dashboard/admin/organization/update']")
      |> render_click()

    {:ok, view, _html} = follow_redirect(result, conn, ~p"/dashboard/admin/organization/update")

    assert {:error, {:live_redirect, %{to: "/dashboard/admin/organization"}}} =
             view
             |> form("#organization-form", form: %{name: "Updated from footer"})
             |> render_submit()

    updated = OrganizationService.organization_settings!(actor: @system)
    assert updated.id == organization.id
    assert updated.name == "Updated from footer"
  end

  test "View actions return to saved records without saving drafts", %{conn: conn} do
    user = create_user(display_name: "Saved user")
    role = Ash.create!(Role, %{code: "view-draft-role", name: "Saved role"}, actor: @system)

    organization =
      OrganizationService.create_organization!(%{name: "Saved organization"}, actor: @system)

    for level <- [5, 13, 16] do
      operator_conn = grant(conn, %{"USERS" => level, "ROLES" => level, "ORG" => level})

      for section <- ["header", "footer"],
          {resource, record, form_id, field, collection, destination} <- [
            {User, user, "user-form", :display_name, "/dashboard/admin/users",
             "/dashboard/admin/users/#{user.id}/read"},
            {Role, role, "role-form", :name, "/dashboard/admin/roles",
             "/dashboard/admin/roles/#{role.id}/read"},
            {Organization, organization, "organization-form", :name,
             "/dashboard/admin/organization", "/dashboard/admin/organization"}
          ] do
        update_path =
          if resource == Organization,
            do: collection <> "/update",
            else: "#{collection}/#{record.id}/update"

        saved_name = Map.fetch!(record, field)
        draft = "Unsaved #{saved_name}"
        {:ok, edit, _html} = live(operator_conn, update_path)

        edit |> form("##{form_id}", form: %{field => draft}) |> render_change()
        assert has_element?(edit, "input[name='form[#{field}]'][value='#{draft}']")
        document = edit |> render() |> Floki.parse_document!()

        for position <- ["header", "footer"] do
          assert length(
                   Floki.find(
                     document,
                     "##{form_id} #{position} a[href='#{destination}'][data-tooltip=View]"
                   )
                 ) == 1

          if resource == Organization do
            refute has_element?(edit, "##{form_id} #{position} a[data-tooltip=Back]")
          else
            assert has_element?(
                     edit,
                     "##{form_id} #{position} a[data-tooltip=Back] + a[href='#{destination}'][data-tooltip=View]"
                   )

            assert has_element?(edit, "##{form_id} #{position} button[phx-click=request_delete]") ==
                     level in [13, 16]
          end
        end

        result =
          edit
          |> element("##{form_id} #{section} a[href='#{destination}'][data-tooltip=View]")
          |> render_click()

        {:ok, read, _html} = follow_redirect(result, operator_conn, destination)
        refute has_element?(read, "##{form_id}[phx-change], ##{form_id}[phx-submit]")
        refute has_element?(read, "##{form_id} button[type=submit]")

        if resource == Organization do
          assert has_element?(read, "span#form_name", saved_name)
        else
          assert has_element?(read, "##{form_id} fieldset[disabled]")
          assert has_element?(read, "input[name='form[#{field}]'][value='#{saved_name}']")
        end

        refute has_element?(read, "##{form_id}", draft)
        assert Map.fetch!(Ash.get!(resource, record.id, actor: @system), field) == saved_name
      end
    end

    protected_role = Ash.create!(Role, %{code: "superuser", name: "Superuser"}, actor: @system)
    operator_conn = grant(conn, %{"ROLES" => 16})

    {:ok, edit, _html} =
      live(operator_conn, ~p"/dashboard/admin/roles/#{protected_role.id}/update")

    for section <- ["header", "footer"] do
      assert has_element?(
               edit,
               "#role-form #{section} a[href='/dashboard/admin/roles/#{protected_role.id}/read'][data-tooltip=View]"
             )

      assert has_element?(edit, "#role-form #{section} button[type=submit]")
      refute has_element?(edit, "#role-form #{section} button[phx-click=request_delete]")
    end
  end

  test "read access hides save controls while retaining Back and View links", %{
    conn: conn
  } do
    user = create_user()
    role = Ash.create!(Role, %{code: "reader-target", name: "Read only"}, actor: @system)
    OrganizationService.create_organization!(%{name: "Read only"}, actor: @system)
    conn = grant(conn, %{"USERS" => 4, "ROLES" => 4, "ORG" => 4})

    for {path, form_id, back_path} <- [
          {~p"/dashboard/admin/users/#{user.id}/update", "user-form", "/dashboard/admin/users"},
          {~p"/dashboard/admin/roles/#{role.id}/update", "role-form", "/dashboard/admin/roles"}
        ] do
      {:ok, view, _html} = live(conn, path)

      for section <- ["header", "footer"] do
        refute has_element?(view, "##{form_id} #{section} button[type=submit]")

        assert has_element?(
                 view,
                 "##{form_id} #{section} a[href='#{back_path}'][data-tooltip=Back]"
               )

        destination = String.replace_suffix(path, "/update", "/read")

        assert has_element?(
                 view,
                 "##{form_id} #{section} a[href='#{destination}'][data-tooltip=View]"
               )
      end
    end

    {:ok, view, _html} = live(conn, ~p"/dashboard/admin/organization")
    refute has_element?(view, "#organization-form header button[type=submit]")
    refute has_element?(view, "#organization-form footer button[type=submit]")
  end
end

defmodule ElixirbitsWeb.Admin.AdminPagesTest do
  use ElixirbitsWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Elixirbits.AccessControl.Permissions
  alias Elixirbits.AccessControl.Role
  alias Elixirbits.AccessControl.RolePerm
  alias Elixirbits.AccessControl.Sitenav
  alias Elixirbits.Accounts.User

  setup do
    for {code, path} <- [{"USERS", "admin/users"}, {"ROLES", "admin/roles"}] do
      Ash.create!(Sitenav, %{code: code, name: code, url: path, level: 1}, actor: %{system: true})
    end

    :ok
  end

  defp grant(conn, levels) do
    role = "actor-#{System.unique_integer([:positive])}"
    user = create_user(roles: [role])

    for {code, level} <- levels do
      Ash.create!(RolePerm, %{roles_code: role, sitenav_code: code, level: level},
        actor: %{system: true}
      )
    end

    log_in_user(conn, user)
  end

  test "anonymous and ungranted accounts are redirected before protected views mount", %{
    conn: conn
  } do
    assert {:error, {:redirect, %{to: "/sign-in"}}} = live(conn, ~p"/admin/users")
    conn = log_in_user(conn, create_user())
    assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/admin/users")
  end

  test "a disabled public page is inaccessible to anonymous and signed-in visitors", %{conn: conn} do
    page = Ash.get!(Sitenav, %{code: "ROLES"}, actor: %{system: true})
    page = Ash.update!(page, %{roles_bypass: ["public"]}, actor: %{system: true})
    Ash.update!(page, %{}, action: :disable, actor: %{system: true})

    assert {:error, {:redirect, %{to: "/sign-in"}}} = live(conn, ~p"/admin/roles")
    conn = log_in_user(conn, create_user(roles: ["superuser"]))
    assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/admin/roles")
  end

  test "read access cannot open new forms or save forged updates", %{conn: conn} do
    target = create_user(display_name: "Original")
    conn = grant(conn, %{"USERS" => 4, "ROLES" => 4})

    assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/admin/roles/create")
    {:ok, view, _} = live(conn, ~p"/admin/users/#{target.id}/update")
    assert has_element?(view, "nav a[href='/admin/users'][aria-current=location]")
    refute has_element?(view, "#user-form button[type='submit']")
    assert has_element?(view, "#user-form fieldset[disabled] input[name='form[display_name]']")
    html = render_submit(view, "save", %{"form" => %{"display_name" => "Blocked"}})
    assert html =~ "do not have permission"
    assert Ash.get!(User, target.id, actor: %{system: true}).display_name == "Original"

    role = Ash.create!(Role, %{code: "readonly", name: "Read only"}, actor: %{system: true})
    {:ok, role_view, _} = live(conn, ~p"/admin/roles/#{role.id}/update")
    assert has_element?(role_view, "nav a[href='/admin/roles'][aria-current=location]")
    assert has_element?(role_view, "#role-form fieldset[disabled] input[name='form[name]']")
  end

  test "users with update access can save profiles but cannot forge a role-assignment event", %{
    conn: conn
  } do
    target = create_user()
    conn = grant(conn, %{"USERS" => 5, "ROLES" => 15})
    Ash.create!(Role, %{code: "superuser", name: "Superuser"}, actor: %{system: true})
    {:ok, view, _} = live(conn, ~p"/admin/users/#{target.id}/update")

    assert has_element?(view, "#user-form[novalidate]")
    refute has_element?(view, "#roles-form")
    html = render_submit(view, "assign_roles", %{"roles_form" => %{"roles" => ["superuser"]}})
    assert html =~ "do not have permission"
    assert Ash.get!(User, target.id, actor: %{system: true}).roles == []

    view |> form("#user-form", form: %{display_name: "Updated"}) |> render_submit()
    assert Ash.get!(User, target.id, actor: %{system: true}).display_name == "Updated"
  end

  test "user birthdays remain dates while timezone preferences validate and reset", %{conn: conn} do
    target = create_user(dob: ~D[1990-01-01], timezone: "America/New_York")
    conn = grant(conn, %{"USERS" => 5})
    {:ok, view, _} = live(conn, ~p"/admin/users/#{target.id}/update")

    assert has_element?(view, "input[name='form[dob]'][data-vc-mode='date'][value='1990-01-01']")
    assert has_element?(view, "input[name='form[timezone]'][value='America/New_York']")

    html =
      view
      |> form("#user-form", form: %{dob: "1990-01-02", timezone: "Unknown/Zone"})
      |> render_submit()

    assert html =~ "is not a known timezone"
    unchanged = Ash.get!(User, target.id, actor: %{system: true})
    assert unchanged.dob == ~D[1990-01-01]
    assert unchanged.timezone == "America/New_York"

    view
    |> form("#user-form", form: %{dob: "1990-01-02", timezone: "Asia/Kuala_Lumpur"})
    |> render_submit()

    updated = Ash.get!(User, target.id, actor: %{system: true})
    assert updated.dob == ~D[1990-01-02]
    assert updated.timezone == "Asia/Kuala_Lumpur"
    assert updated.confirmed_at == target.confirmed_at

    {:ok, view, _} = live(conn, ~p"/admin/users/#{target.id}/update")
    assert has_element?(view, "input[name='form[dob]'][value='1990-01-02']")
    assert has_element?(view, "input[name='form[timezone]'][placeholder='Automatic (browser)']")
    view |> form("#user-form", form: %{timezone: ""}) |> render_submit()
    automatic = Ash.get!(User, target.id, actor: %{system: true})
    assert automatic.timezone == nil
    assert automatic.dob == ~D[1990-01-02]
  end

  test "role creation saves the permission matrix through its Ash action", %{conn: conn} do
    conn = grant(conn, %{"ROLES" => 16})
    {:ok, view, _} = live(conn, ~p"/admin/roles/create")
    assert has_element?(view, "#role-form[novalidate]")
    assert has_element?(view, "#permission-level-USERS[phx-hook=LiveSelect]")

    assert has_element?(
             view,
             "label#permission-label-USERS[for=permission-level_USERS_text_input]",
             "USERS"
           )

    for {{level, label}, index} <-
          Enum.with_index([
            {0, "None"},
            {4, "Read"},
            {5, "Read + Update"},
            {6, "Read + Create"},
            {7, "Read + Create + Update"},
            {12, "Read + Delete"},
            {13, "Read + Update + Delete"},
            {14, "Read + Create + Delete"},
            {15, "Read + Create + Update + Delete"},
            {16, "Superuser Access"}
          ]) do
      render_focus(element(view, "#permission-level-USERS input[type=text]"))
      render_hook(view, "live_select_change", %{"id" => "permission-level-USERS"})
      assert has_element?(view, "#permission-level-USERS li", label)

      if level != 0 do
        render_hook(element(view, "#permission-level-USERS"), "option_click", %{
          "idx" => to_string(index)
        })
      end

      view |> form("#role-form") |> render_change()

      assert has_element?(
               view,
               "#permission-level-USERS input[type=hidden][name='page_levels[USERS]'][value='#{level}']"
             )

      assert has_element?(view, "#permission-level-USERS input[type=text][value='#{label}']")
      refute has_element?(view, "#permission-level-USERS button[phx-click=clear]")
    end

    render_focus(element(view, "#permission-level-USERS input[type=text]"))
    render_hook(view, "live_select_change", %{"id" => "permission-level-USERS"})
    render_hook(element(view, "#permission-level-USERS"), "option_click", %{"idx" => "8"})
    view |> form("#role-form") |> render_change()

    render_focus(element(view, "#permission-level-ROLES input[type=text]"))
    render_hook(view, "live_select_change", %{"id" => "permission-level-ROLES"})
    render_hook(element(view, "#permission-level-ROLES"), "option_click", %{"idx" => "5"})
    view |> form("#role-form") |> render_change()

    view |> form("#role-form", form: %{code: "viewer", name: "Viewer"}) |> render_submit()

    role = Ash.get!(Role, %{code: "viewer"}, actor: %{system: true}, load: [:role_perms])
    assert Enum.find(role.role_perms, &(&1.sitenav_code == "USERS")).level == 15
    assert Enum.find(role.role_perms, &(&1.sitenav_code == "ROLES")).level == 12
  end

  test "permission selects search, restore options, and save an explicit zero grant", %{
    conn: conn
  } do
    conn = grant(conn, %{"ROLES" => 16})
    {:ok, view, _} = live(conn, ~p"/admin/roles/create")
    assert has_element?(view, "#permission-level-USERS[data-update-min-len='0']")
    assert has_element?(view, "#permission-level-USERS input[type=text][value=None]")

    assert has_element?(
             view,
             "#permission-level-USERS input[type=hidden][name='page_levels[USERS]'][value='0']"
           )

    render_focus(element(view, "#permission-level-USERS input[type=text]"))
    render_hook(view, "live_select_change", %{"id" => "permission-level-USERS"})
    render_hook(element(view, "#permission-level-USERS"), "change", %{"text" => "superuser"})

    render_hook(view, "live_select_change", %{
      "id" => "permission-level-USERS",
      "text" => "superuser"
    })

    assert has_element?(view, "#permission-level-USERS li", "Superuser Access")
    refute has_element?(view, "#permission-level-USERS li", "Read")
    render_hook(element(view, "#permission-level-USERS"), "option_click", %{"idx" => "0"})
    view |> form("#role-form") |> render_change()

    assert has_element?(
             view,
             "#permission-level-USERS input[type=text][value='Superuser Access']"
           )

    refute has_element?(view, "#permission-level-USERS button[phx-click=clear]")

    render_focus(element(view, "#permission-level-USERS input[type=text]"))
    render_hook(element(view, "#permission-level-USERS"), "change", %{"text" => ""})
    render_hook(view, "live_select_change", %{"id" => "permission-level-USERS", "text" => ""})
    assert has_element?(view, "#permission-level-USERS li", "None")
    assert has_element?(view, "#permission-level-USERS li", "Read + Create + Update + Delete")
    render_hook(element(view, "#permission-level-USERS"), "option_click", %{"idx" => "0"})
    view |> form("#role-form") |> render_change()
    assert has_element?(view, "#permission-level-USERS input[type=text][value=None]")

    view |> form("#role-form", form: %{code: "no-access", name: "No access"}) |> render_submit()
    role = Ash.get!(Role, %{code: "no-access"}, actor: %{system: true}, load: [:role_perms])
    assert Enum.find(role.role_perms, &(&1.sitenav_code == "USERS")).level == 0
  end

  test "role creation access saves metadata without changing grants", %{conn: conn} do
    existing =
      Ash.create!(Role, %{code: "existing", name: "Existing"}, actor: %{system: true})

    conn = grant(conn, %{"ROLES" => 6})
    {:ok, index_view, _} = live(conn, ~p"/admin/roles")
    render_async(index_view)

    assert has_element?(
             index_view,
             "#new-role[href='/admin/roles/create'][data-tooltip='Add new']"
           )

    refute has_element?(index_view, "a[href='/admin/roles/#{existing.id}/update']")

    {:ok, update_view, _} = live(conn, ~p"/admin/roles/#{existing.id}/update")
    refute has_element?(update_view, "#role-form button[type=submit]")

    assert render_submit(update_view, "save", %{"form" => %{"name" => "Forged"}}) =~
             "do not have permission"

    assert Ash.get!(Role, existing.id, actor: %{system: true}).name == "Existing"

    {:ok, view, _} = live(conn, ~p"/admin/roles/create")
    assert has_element?(view, "input#permission-level-USERS[type=text][disabled][value=None]")
    refute has_element?(view, "#permission-level-USERS[phx-hook=LiveSelect]")
    view |> form("#role-form", form: %{code: "metadata", name: "Metadata"}) |> render_submit()
    role = Ash.get!(Role, %{code: "metadata"}, actor: %{system: true}, load: [:role_perms])
    assert role.role_perms == []
  end

  test "public pages accept additional role grants and retain public read when cleared", %{
    conn: conn
  } do
    Ash.create!(
      Sitenav,
      %{
        code: "PUBLIC",
        name: "Public example",
        url: "public-example",
        level: 1,
        roles_bypass: ["public"]
      },
      actor: %{system: true}
    )

    conn = grant(conn, %{"ROLES" => 16})
    {:ok, view, _} = live(conn, ~p"/admin/roles/create")
    assert has_element?(view, "#permission-hint-PUBLIC", "Public read access")

    assert has_element?(
             view,
             "[role=group][aria-labelledby=permission-label-PUBLIC][aria-describedby=permission-hint-PUBLIC] #permission-level-PUBLIC input[type=hidden][name='page_levels[PUBLIC]'][value='0']"
           )

    render_focus(element(view, "#permission-level-PUBLIC input[type=text]"))
    render_hook(view, "live_select_change", %{"id" => "permission-level-PUBLIC"})
    render_hook(element(view, "#permission-level-PUBLIC"), "option_click", %{"idx" => "3"})
    view |> form("#role-form") |> render_change()

    view
    |> form("#role-form", form: %{code: "public-creator", name: "Public creator"})
    |> render_submit()

    role = Ash.get!(Role, %{code: "public-creator"}, actor: %{system: true}, load: [:role_perms])
    assert Enum.find(role.role_perms, &(&1.sitenav_code == "PUBLIC")).level == 6
    member = create_user(roles: [role.code])
    assert Permissions.perm_level(Permissions.load(member), "/public-example") == 6

    {:ok, view, _} = live(conn, ~p"/admin/roles/#{role.id}/update")

    assert has_element?(
             view,
             "#permission-level-PUBLIC input[type=hidden][name='page_levels[PUBLIC]'][value='6']"
           )

    render_focus(element(view, "#permission-level-PUBLIC input[type=text]"))
    render_hook(view, "live_select_change", %{"id" => "permission-level-PUBLIC"})
    render_hook(element(view, "#permission-level-PUBLIC"), "option_click", %{"idx" => "0"})
    view |> form("#role-form") |> render_change()

    view |> form("#role-form") |> render_submit()
    cleared = Ash.get!(Role, role.id, actor: %{system: true}, load: [:role_perms])
    assert Enum.find(cleared.role_perms, &(&1.sitenav_code == "PUBLIC")).level == 0
    assert Permissions.perm_level(Permissions.load(member), "/public-example") == 4
    assert Permissions.perm_level(Permissions.load(nil), "/public-example") == 4
  end

  test "update-only role access allows metadata changes but does not allow creating a role", %{
    conn: conn
  } do
    role = Ash.create!(Role, %{code: "editable", name: "Original"}, actor: %{system: true})
    conn = grant(conn, %{"ROLES" => 5})
    {:ok, index_view, _} = live(conn, ~p"/admin/roles")
    render_async(index_view)
    refute has_element?(index_view, "#new-role")
    assert has_element?(index_view, "a[href='/admin/roles/#{role.id}/update']")
    assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/admin/roles/create")

    {:ok, view, _} = live(conn, ~p"/admin/roles/#{role.id}/update")
    view |> form("#role-form", form: %{name: "Updated"}) |> render_submit()
    updated = Ash.get!(Role, role.id, actor: %{system: true}, load: [:role_perms])
    assert updated.name == "Updated"
    assert updated.role_perms == []
  end

  test "ordinary CRUD authority cannot forge SU permission changes in its own role", %{conn: conn} do
    role_code = "updater-#{System.unique_integer([:positive])}"
    user = create_user(roles: [role_code])
    role = Ash.get!(Role, %{code: role_code}, actor: %{system: true})

    grant =
      Ash.create!(RolePerm, %{roles_code: role_code, sitenav_code: "ROLES", level: 15},
        actor: %{system: true}
      )

    conn = log_in_user(conn, user)
    {:ok, view, _} = live(conn, ~p"/admin/roles/#{role.id}/update")
    assert has_element?(view, "input#permission-level-ROLES[type=text][disabled]")

    render_change(view, "validate", %{
      "form" => %{"name" => "Metadata update"},
      "page_levels" => %{"ROLES" => "16"}
    })

    assert has_element?(
             view,
             "input#permission-level-ROLES[disabled][value='Read + Create + Update + Delete']"
           )

    assert has_element?(view, "input[type=hidden][name='page_levels[ROLES]'][value='15']")

    render_submit(view, "save", %{
      "form" => %{
        "name" => "Metadata update",
        "permissions" => %{"0" => %{"sitenav_code" => "ROLES", "level" => "16"}}
      }
    })

    assert Ash.get!(Role, role.id, actor: %{system: true}).name == "Metadata update"
    assert Ash.get!(RolePerm, grant.id, actor: %{system: true}).level == 15
  end

  test "permission changes reload superuser authority before changing form state", %{conn: conn} do
    role_code = "revoked-#{System.unique_integer([:positive])}"
    user = create_user(roles: [role_code])

    grant =
      Ash.create!(RolePerm, %{roles_code: role_code, sitenav_code: "ROLES", level: 16},
        actor: %{system: true}
      )

    target = Ash.create!(Role, %{code: "target", name: "Target"}, actor: %{system: true})

    target_grant =
      Ash.create!(RolePerm, %{roles_code: target.code, sitenav_code: "USERS", level: 4},
        actor: %{system: true}
      )

    {:ok, view, _} = live(log_in_user(conn, user), ~p"/admin/roles/#{target.id}/update")
    assert has_element?(view, "#permission-level-USERS[phx-hook=LiveSelect]")
    Ash.update!(grant, %{level: 15}, actor: %{system: true})

    render_change(view, "validate", %{
      "form" => %{"name" => "Target"},
      "page_levels" => %{"USERS" => "16"}
    })

    assert has_element?(view, "input#permission-level-USERS[disabled][value=Read]")
    assert has_element?(view, "input[type=hidden][name='page_levels[USERS]'][value='4']")
    assert has_element?(view, "label[for=permission-level-USERS]", "USERS")

    view |> form("#role-form", form: %{name: "Updated target"}) |> render_submit()
    assert Ash.get!(Role, target.id, actor: %{system: true}).name == "Updated target"
    assert Ash.get!(RolePerm, target_grant.id, actor: %{system: true}).level == 4
  end

  test "address creation and persisted deletion require their own capabilities", %{conn: conn} do
    for {level, can_create?, can_delete?} <- [
          {5, false, false},
          {7, true, false},
          {13, false, true},
          {15, true, true}
        ] do
      target = create_user(addresses: [%{line_1: "Existing address"}])
      actor_conn = grant(conn, %{"USERS" => level})
      {:ok, view, _} = live(actor_conn, ~p"/admin/users/#{target.id}/update")

      assert has_element?(view, "button[phx-click=add_form][data-tooltip='Add']") == can_create?

      assert has_element?(
               view,
               "button[phx-click=remove_form][phx-value-path='form[addresses][0]']"
             ) == can_delete?

      if can_create? do
        view |> element("button[phx-click=add_form]") |> render_click()

        view
        |> element("button[phx-click=remove_form][phx-value-path='form[addresses][1]']")
        |> render_click()

        refute has_element?(view, "input[name='form[addresses][1][line_1]']")
      else
        assert render_click(view, "add_form", %{"field" => "addresses"}) =~
                 "do not have permission"
      end

      if can_delete? do
        view
        |> element("button[phx-click=remove_form][phx-value-path='form[addresses][0]']")
        |> render_click()

        view |> form("#user-form") |> render_submit()
        updated = Ash.get!(User, target.id, actor: %{system: true}, load: [:addresses])
        assert updated.addresses == []
      else
        assert render_click(view, "remove_form", %{"path" => "form[addresses][0]"}) =~
                 "do not have permission"

        assert has_element?(view, "input[name='form[addresses][0][line_1]']")
      end
    end
  end

  test "disabled structural parents remove enabled child links and deny protected routes", %{
    conn: conn
  } do
    parent =
      Ash.create!(Sitenav, %{code: "ADMIN", name: "Administration", level: 1},
        actor: %{system: true}
      )

    page = Ash.get!(Sitenav, %{code: "USERS"}, actor: %{system: true})
    Ash.update!(page, %{parent: parent.code}, actor: %{system: true})
    conn = grant(conn, %{"USERS" => 4})
    Ash.update!(parent, %{}, action: :disable, actor: %{system: true})

    assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/admin/users")
    {:ok, view, _} = live(conn, ~p"/")
    refute has_element?(view, "a[href='/admin/users']")
    render_click(view, "toggle_nav")
    refute has_element?(view, "nav a[href='/admin/users']")
  end

  test "navigation and user listings reflect the permitted pages", %{conn: conn} do
    target = create_user(display_name: "A User")
    conn = grant(conn, %{"USERS" => 5})
    {:ok, view, _} = live(conn, ~p"/admin/users")
    html = render_async(view)

    assert html =~ to_string(target.email)
    assert html =~ "/admin/users/#{target.id}/update"
    refute html =~ "new-role"
    assert has_element?(view, "nav a[href='/admin/users']")
    refute has_element?(view, "nav a[href='/admin/roles']")
    render_click(view, "toggle_nav")
    refute has_element?(view, "nav a[href='/admin/users']")
    render_click(view, "toggle_nav")
    assert has_element?(view, "nav a[href='/admin/users']")
  end
end

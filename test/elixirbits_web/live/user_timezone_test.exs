defmodule ElixirbitsWeb.UserTimezoneTest do
  use ElixirbitsWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Elixirbits.AccessControl.Sitenav
  alias Elixirbits.Accounts.User
  alias Elixirbits.Organizations

  @system %{system: true}

  setup do
    home =
      Ash.create!(
        Sitenav,
        %{code: "HOME", name: "Home", url: "", level: 1, roles_bypass: ["public"]},
        actor: @system
      )

    {:ok, home: home}
  end

  test "anonymous visitors use their browser timezone but cannot save a preference", %{conn: conn} do
    conn = put_connect_params(conn, %{"user_timezone" => "America/New_York"})
    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "[data-user-timezone='America/New_York']")
    view |> element("button[phx-click='toggle_nav']") |> render_click()
    refute has_element?(view, "#user-timezone-form")

    assert render_submit(view, "change_timezone", %{"timezone" => "Europe/London"}) =~
             "Sign in to save your timezone."

    assert has_element?(view, "[data-user-timezone='America/New_York']")
  end

  test "a persisted preference wins over browser and organization timezones", %{conn: conn} do
    Organizations.create_organization!(%{name: "Workspace", timezone: "Pacific/Auckland"},
      actor: @system
    )

    user = create_user(timezone: "Europe/London")

    conn =
      conn
      |> log_in_user(user)
      |> put_connect_params(%{"user_timezone" => "America/New_York"})

    {:ok, view, _html} = live(conn, ~p"/")
    assert has_element?(view, "[data-user-timezone='Europe/London']")

    assert has_element?(
             view,
             "button[popovertarget=account-menu][aria-label='Open account menu']"
           )

    assert has_element?(view, "#account-menu[popover=auto] #user-timezone-form[novalidate]")
    view |> element("button[phx-click='toggle_nav']") |> render_click()
    assert has_element?(view, "#user-timezone-form[novalidate]")

    assert has_element?(
             view,
             "#user-timezone-select[name=timezone] option[selected][value='Europe/London']"
           )

    assert has_element?(view, "#user-timezone input[type=text][value='Europe/London']")
    assert render(view) =~ "Currently using Europe/London"

    names =
      view
      |> render()
      |> Floki.parse_document!()
      |> Floki.find("#user-timezone-form [name]")
      |> Floki.attribute("name")

    assert names == ["timezone"]

    zones =
      view
      |> render()
      |> Floki.parse_document!()
      |> Floki.find("#user-timezone-select option")
      |> Floki.attribute("value")
      |> Enum.reject(&(&1 == ""))

    assert "Europe/London" in zones

    for zone <- zones do
      changeset = Ash.Changeset.for_update(user, :update_timezone, %{timezone: zone}, actor: user)
      assert changeset.valid?, "offered timezone #{zone} must pass resource validation"
    end
  end

  test "invalid browser timezone falls back to organization settings", %{conn: conn} do
    Organizations.create_organization!(%{name: "Workspace", timezone: "Pacific/Auckland"},
      actor: @system
    )

    conn = put_connect_params(conn, %{"user_timezone" => "Unknown/Zone"})
    {:ok, view, _html} = live(conn, ~p"/")
    assert has_element?(view, "[data-user-timezone='Pacific/Auckland']")
  end

  test "missing or invalid browser timezone uses UTC when settings are absent", %{conn: conn} do
    for params <- [%{}, %{"user_timezone" => "Unknown/Zone"}, %{"user_timezone" => 42}] do
      {:ok, view, _html} = conn |> put_connect_params(params) |> live(~p"/")
      assert has_element?(view, "[data-user-timezone='Etc/UTC']")
    end
  end

  test "ordinary accounts save and clear timezone through the expanded navigation form", %{
    conn: conn,
    home: home
  } do
    Ash.destroy!(home, actor: @system)
    user = create_user(roles: [])

    conn =
      conn
      |> log_in_user(user)
      |> put_connect_params(%{"user_timezone" => "America/New_York"})

    {:ok, view, _html} = live(conn, ~p"/")
    assert has_element?(view, "[data-user-timezone='America/New_York']")
    view |> element("button[phx-click='toggle_nav']") |> render_click()
    assert has_element?(view, "#user-timezone input[type=text][value='Automatic (browser)']")
    assert has_element?(view, "#user-timezone-input[placeholder='Automatic (browser)']")
    assert has_element?(view, "#user-timezone-select[name=timezone] option[selected][value='']")
    assert has_element?(view, "#user-timezone-select option[value='Europe/London']")
    assert has_element?(view, "#user-timezone-select option[value='America/New_York']")

    view |> form("#user-timezone-form", timezone: "Europe/London") |> render_change()

    assert has_element?(
             view,
             "#user-timezone-select[name=timezone] option[selected][value='Europe/London']"
           )

    refute has_element?(view, "#user-timezone [data-pc-combo-clear]")

    result = view |> form("#user-timezone-form", timezone: "Europe/London") |> render_submit()
    assert {:error, {:live_redirect, %{to: "/"}}} = result
    assert Ash.get!(User, user.id, actor: @system).timezone == "Europe/London"
    {:ok, view, html} = follow_redirect(result, conn, ~p"/")
    assert html =~ "Timezone saved."
    assert has_element?(view, "[data-user-timezone='Europe/London']")
    view |> element("button[phx-click='toggle_nav']") |> render_click()

    assert has_element?(
             view,
             "#user-timezone-select[name=timezone] option[selected][value='Europe/London']"
           )

    assert has_element?(view, "#user-timezone-select option[value='']", "Automatic (browser)")
    view |> form("#user-timezone-form", timezone: "") |> render_change()
    assert has_element?(view, "#user-timezone-select[name=timezone] option[selected][value='']")

    result = view |> form("#user-timezone-form", timezone: "") |> render_submit()
    assert {:error, {:live_redirect, %{to: "/"}}} = result
    assert Ash.get!(User, user.id, actor: @system).timezone == nil
    {:ok, view, _html} = follow_redirect(result, conn, ~p"/")
    assert has_element?(view, "[data-user-timezone='America/New_York']")
    view |> element("button[phx-click='toggle_nav']") |> render_click()
    assert has_element?(view, "#user-timezone input[type=text][value='Automatic (browser)']")
  end

  test "invalid preferences show an error and forged fields cannot alter profiles", %{conn: conn} do
    user = create_user(display_name: "Original", timezone: "Europe/London", roles: [])
    target = create_user(timezone: "Pacific/Auckland")

    conn =
      conn
      |> log_in_user(user)
      |> put_connect_params(%{"user_timezone" => "America/New_York"})

    {:ok, view, _html} = live(conn, ~p"/")
    view |> element("button[phx-click='toggle_nav']") |> render_click()

    assert render_submit(view, "change_timezone", %{"timezone" => "Unknown/Zone"}) =~
             "Choose a valid timezone."

    assert has_element?(view, "[data-user-timezone='Europe/London']")
    assert Ash.get!(User, user.id, actor: @system).timezone == "Europe/London"

    assert {:error, {:live_redirect, %{to: "/"}}} =
             render_submit(view, "change_timezone", %{
               "timezone" => "Asia/Kuala_Lumpur",
               "id" => target.id,
               "display_name" => "Forged",
               "roles" => ["superuser"]
             })

    updated = Ash.get!(User, user.id, actor: @system)
    assert updated.timezone == "Asia/Kuala_Lumpur"
    assert updated.display_name == "Original"
    assert updated.roles == []
    assert Ash.get!(User, target.id, actor: @system).timezone == "Pacific/Auckland"
  end

  test "navigation timezone choices stay separate from a page's own comboboxes", %{conn: conn} do
    Ash.create!(Sitenav, %{code: "USERS", name: "Users", url: "admin/users", level: 1},
      actor: @system
    )

    user = create_user(roles: ["superuser"])
    {:ok, view, _html} = conn |> log_in_user(user) |> live(~p"/admin/users/#{user.id}/update")
    view |> element("button[phx-click='toggle_nav']") |> render_click()

    assert has_element?(view, "#user-timezone-select option[value='Europe/London']")
    refute has_element?(view, "#user-timezone-select option", "Home")
    assert has_element?(view, "#user-timezone-select option[value='America/New_York']")
    assert has_element?(view, "#user-timezone-select option[value='']", "Automatic (browser)")
    assert has_element?(view, "#form_sex-select option", "Female")
    refute has_element?(view, "#form_sex-select option", "Europe/London")

    view |> form("#user-timezone-form", timezone: "Europe/London") |> render_change()
    view |> form("#user-form", form: %{display_name: "Updated name"}) |> render_change()

    assert has_element?(view, "#user-timezone-select option[selected][value='Europe/London']")
    assert Ash.get!(User, user.id, actor: @system).timezone == nil
  end

  test "the global hook saves on a view without app navigation and retains its query", %{
    conn: conn
  } do
    user = create_user()

    conn =
      conn
      |> log_in_user(user)
      |> put_connect_params(%{"user_timezone" => "America/New_York"})

    path = ~p"/confirm_new_user/confirmation-token?#{%{scope: "timezone"}}"
    {:ok, view, _html} = live(conn, path)
    assert has_element?(view, "[data-user-timezone='America/New_York']")
    refute has_element?(view, "#user-timezone-form")

    result = render_submit(view, "change_timezone", %{"timezone" => "Europe/London"})
    assert {:error, {:live_redirect, %{to: ^path}}} = result
    assert Ash.get!(User, user.id, actor: @system).timezone == "Europe/London"
    {:ok, view, _html} = follow_redirect(result, conn, path)
    assert has_element?(view, "[data-user-timezone='Europe/London']")
  end

  test "the component showcase exposes the shared account preference form", %{conn: conn} do
    conn = log_in_user(conn, create_user())
    {:ok, view, _html} = live(conn, ~p"/dev_panel/layout_test")

    assert has_element?(view, "#app-navigation")
    assert has_element?(view, "button[popovertarget=account-menu]")
    assert has_element?(view, "#account-menu #user-timezone-form[phx-submit=change_timezone]")
  end
end

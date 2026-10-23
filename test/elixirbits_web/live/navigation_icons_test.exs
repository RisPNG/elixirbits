defmodule ElixirbitsWeb.NavigationIconsTest do
  use ElixirbitsWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Elixirbits.AccessControl.Sitenav

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

  test "navigation icons persist through create and update actions", %{home: home} do
    entry =
      Ash.create!(
        Sitenav,
        %{code: "REPORTS", name: "Reports", level: 1, icon: "hero-chart-bar"},
        actor: @system
      )

    assert Ash.get!(Sitenav, entry.id, actor: @system).icon == "hero-chart-bar"

    Ash.update!(home, %{icon: "hero-beaker"}, actor: @system)
    assert Ash.get!(Sitenav, home.id, actor: @system).icon == "hero-beaker"

    home = Ash.get!(Sitenav, home.id, actor: @system)
    Ash.update!(home, %{icon: "  "}, actor: @system)
    assert is_nil(Ash.get!(Sitenav, home.id, actor: @system).icon)
  end

  test "unknown icon names are rejected without changing the stored icon", %{home: home} do
    assert {:error, %Ash.Error.Invalid{}} =
             Ash.create(
               Sitenav,
               %{code: "INVALID", name: "Invalid", level: 1, icon: "hero-not-a-real-icon"},
               actor: @system
             )

    home = Ash.update!(home, %{icon: "hero-beaker"}, actor: @system)

    assert {:error, %Ash.Error.Invalid{}} =
             Ash.update(home, %{icon: "tabler-not-a-real-icon"}, actor: @system)

    assert Ash.get!(Sitenav, home.id, actor: @system).icon == "hero-beaker"
  end

  test "Heroicons naming styles persist and render on root links", %{conn: conn} do
    icons = [
      {"OUTLINE", "hero-beaker"},
      {"SOLID", "hero-beaker-solid"},
      {"MINI", "hero-beaker-mini"},
      {"MICRO", "hero-beaker-micro"}
    ]

    for {code, icon} <- icons do
      entry =
        Ash.create!(
          Sitenav,
          %{
            code: code,
            name: code,
            url: "icons/#{code}",
            level: 1,
            icon: icon,
            roles_bypass: ["public"]
          },
          actor: @system
        )

      assert Ash.get!(Sitenav, entry.id, actor: @system).icon == icon
    end

    {:ok, view, _html} = live(conn, ~p"/")

    for {code, icon} <- icons do
      assert has_element?(view, "#app-navigation a[href='/icons/#{code}'] .#{icon}")
    end
  end

  test "Tabler outline icons persist and render on root links", %{conn: conn, home: home} do
    Ash.update!(home, %{icon: "tabler-device-floppy"}, actor: @system)
    assert Ash.get!(Sitenav, home.id, actor: @system).icon == "tabler-device-floppy"

    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "#app-navigation a[href='/'] .tabler-device-floppy")
  end

  test "Tabler filled icons persist and render on root groups", %{conn: conn} do
    group =
      Ash.create!(
        Sitenav,
        %{
          code: "FAVORITES",
          name: "Favorites",
          level: 1,
          icon: "tabler-heart-filled",
          roles_bypass: ["public"]
        },
        actor: @system
      )

    assert Ash.get!(Sitenav, group.id, actor: @system).icon == "tabler-heart-filled"
    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(
             view,
             "#app-navigation button[phx-value-code='FAVORITES'] .tabler-heart-filled"
           )
  end

  test "root links and groups render their stored icons", %{conn: conn, home: home} do
    Ash.update!(home, %{icon: "hero-beaker"}, actor: @system)

    Ash.create!(
      Sitenav,
      %{
        code: "REPORTS",
        name: "Reports",
        level: 1,
        icon: "hero-chart-bar",
        roles_bypass: ["public"]
      },
      actor: @system
    )

    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "#app-navigation a[href='/'] .hero-beaker")

    assert has_element?(
             view,
             "#app-navigation button[phx-value-code='REPORTS'] .hero-chart-bar"
           )
  end

  test "missing and blank root icons use the slash icon", %{conn: conn} do
    group =
      Ash.create!(
        Sitenav,
        %{
          code: "REPORTS",
          name: "Reports",
          level: 1,
          icon: "",
          roles_bypass: ["public"]
        },
        actor: @system
      )

    assert is_nil(group.icon)
    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "#app-navigation a[href='/'] .hero-slash")

    assert has_element?(
             view,
             "#app-navigation button[phx-value-code='REPORTS'] .hero-slash"
           )
  end

  test "child entries retain their icon value without rendering it in navigation", %{conn: conn} do
    Ash.create!(
      Sitenav,
      %{
        code: "REPORTS",
        name: "Reports",
        level: 1,
        icon: "hero-chart-bar",
        roles_bypass: ["public"]
      },
      actor: @system
    )

    child =
      Ash.create!(
        Sitenav,
        %{
          code: "DETAILS",
          name: "Details",
          parent: "REPORTS",
          level: 2,
          url: "reports/details",
          icon: "hero-beaker",
          roles_bypass: ["public"]
        },
        actor: @system
      )

    {:ok, view, _html} = live(conn, ~p"/")
    render_click(view, "toggle_nav_section", %{"code" => "REPORTS"})

    assert has_element?(view, "#app-navigation a[href='/reports/details']", "Details")
    refute has_element?(view, "#app-navigation a[href='/reports/details'] .hero-beaker")
    refute has_element?(view, "#app-navigation a[href='/reports/details'] .hero-slash")
    assert Ash.get!(Sitenav, child.id, actor: @system).icon == "hero-beaker"
  end

  test "the collapsed Home link uses its stored icon", %{conn: conn, home: home} do
    Ash.update!(home, %{icon: "hero-beaker"}, actor: @system)
    {:ok, view, _html} = live(conn, ~p"/")

    render_click(view, "toggle_nav")

    assert has_element?(view, "#app-navigation a[aria-label='Home'] .hero-beaker")
    refute has_element?(view, "#app-navigation a[aria-label='Home'] .hero-home")
  end

  test "the collapsed Home link uses the slash icon when none is assigned", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    render_click(view, "toggle_nav")

    assert has_element?(view, "#app-navigation a[aria-label='Home'] .hero-slash")
  end
end

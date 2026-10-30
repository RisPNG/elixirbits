defmodule ElixirbitsWeb.FlashTest.Notices do
  use ElixirbitsWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <.flash_group flash={@flash} />
    """
  end

  @impl true
  def handle_event("notify", %{"kind" => kind, "message" => message}, socket) do
    {:noreply, put_flash(socket, String.to_existing_atom(kind), message)}
  end

  def handle_event("redirect", _params, socket) do
    {:noreply,
     socket
     |> put_flash(:info, "Earlier message")
     |> put_flash(:error, "Latest message")
     |> redirect(to: "/")}
  end
end

defmodule ElixirbitsWeb.FlashTest do
  use ElixirbitsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias ElixirbitsWeb.CoreComponents
  alias ElixirbitsWeb.Flash
  alias ElixirbitsWeb.FlashTest.Notices

  test "a new notice replaces the previous kind in either direction", %{conn: conn} do
    {:ok, view, _html} = live_isolated(conn, Notices)

    for kind <- ["info", "error", "warning", "info"] do
      render_click(view, "notify", %{"kind" => kind, "message" => "Current #{kind} notice"})

      assert has_element?(view, "#flash-#{kind}", "Current #{kind} notice")
      document = Floki.parse_document!(render(view))
      assert length(Floki.find(document, "[data-flash-key]")) == 1
      assert_push_event(view, "flash:replace", %{kind: ^kind})
    end
  end

  test "an identical notice still signals a fresh dismissal timer", %{conn: conn} do
    {:ok, view, _html} = live_isolated(conn, Notices)

    for _ <- 1..2 do
      render_click(view, "notify", %{"kind" => "info", "message" => "Saved"})
      assert has_element?(view, "#flash-info", "Saved")
      assert_push_event(view, "flash:replace", %{kind: "info"})
    end
  end

  test "redirects carry only the latest notice from one event", %{conn: conn} do
    {:ok, view, _html} = live_isolated(conn, Notices)
    render_click(view, "redirect")
    assert assert_redirect(view, "/") == %{"error" => "Latest message"}
  end

  test "authentication controller notices replace existing controller flash", %{conn: conn} do
    conn =
      conn
      |> Plug.Test.init_test_session(%{})
      |> Phoenix.Controller.fetch_flash()
      |> Phoenix.Controller.put_flash(:error, "Earlier error")
      |> ElixirbitsWeb.AuthController.success({:magic_link, :request}, nil, nil)

    assert conn.status == 302

    assert Plug.Conn.get_session(conn, "phoenix_flash") == %{
             "info" => "If your email is valid, a sign-in link has been sent."
           }
  end

  test "replacement preserves structured message options and native redirect flash state" do
    payload = %{
      title: "Heads up",
      msg: "Review the account",
      icon: "hero-bell",
      duration: 1200,
      show_spinner: true
    }

    socket = %Phoenix.LiveView.Socket{
      assigns: %{__changed__: %{}, flash: %{}},
      private: %{live_temp: %{}}
    }

    socket =
      socket
      |> Flash.put_flash(:error, "Earlier error")
      |> Flash.put_flash(:warning, payload)

    assert socket.assigns.flash == %{"warning" => payload}
    assert Phoenix.LiveView.Utils.changed_flash(socket) == %{"warning" => payload}

    html = render_component(&CoreComponents.flash_group/1, flash: socket.assigns.flash)
    document = Floki.parse_document!(html)
    assert Floki.text(Floki.find(document, "#flash-warning")) =~ "Review the account"
    assert Floki.text(Floki.find(document, "#flash-warning")) =~ "Heads up"
    assert Floki.find(document, "#flash-warning .hero-bell") != []
    assert Floki.find(document, "#flash-warning .hero-arrow-path") != []
    assert Floki.attribute(document, "#flash-warning", "data-duration") == ["1200"]
  end

  test "connection alerts are scoped to their connection condition and carry no stored flash key" do
    document =
      render_component(&CoreComponents.flash_group/1, flash: %{})
      |> Floki.parse_document!()

    for {id, condition} <- [
          {"client-error", "phx-client-error"},
          {"server-error", "phx-server-error"}
        ] do
      [encoded] = Floki.attribute(document, "##{id}", "phx-disconnected")
      assert [["exec", %{"attr" => "data-show", "to" => selector}]] = Jason.decode!(encoded)
      assert selector == ".#{condition} ##{id}"
      assert Floki.attribute(document, "##{id}", "data-flash-key") == []

      [encoded] = Floki.attribute(document, "##{id}", "data-show")
      commands = Jason.decode!(encoded)

      assert Enum.any?(commands, fn
               ["hide", %{"to" => selector}] -> selector == "[data-flash-notice]:not(##{id})"
               _ -> false
             end)
    end
  end
end

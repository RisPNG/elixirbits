defmodule ElixirbitsWeb.Flash do
  def put_flash(%Phoenix.LiveView.Socket{} = socket, kind, message) do
    socket.assigns.flash
    |> Map.keys()
    |> Enum.reduce(socket, &Phoenix.LiveView.clear_flash(&2, &1))
    |> Phoenix.LiveView.put_flash(kind, message)
    |> Phoenix.LiveView.push_event("flash:replace", %{kind: to_string(kind)})
  end

  def put_flash(%Plug.Conn{} = conn, kind, message) do
    conn
    |> Phoenix.Controller.clear_flash()
    |> Phoenix.Controller.put_flash(kind, message)
  end
end

defmodule ElixirbitsWeb.PageController do
  use ElixirbitsWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end

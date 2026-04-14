defmodule ElixirbitsWeb.AshTypescriptRpcController do
  use ElixirbitsWeb, :controller

  def run(conn, params) do
    result = AshTypescript.Rpc.run_action(:elixirbits, conn, params)
    json(conn, result)
  end

  def validate(conn, params) do
    result = AshTypescript.Rpc.validate_action(:elixirbits, conn, params)
    json(conn, result)
  end
end

defmodule PoppybitWeb.AshTypescriptRpcController do
  use PoppybitWeb, :controller

  def run(conn, params) do
    result = AshTypescript.Rpc.run_action(:poppybit, conn, params)
    json(conn, result)
  end

  def validate(conn, params) do
    result = AshTypescript.Rpc.validate_action(:poppybit, conn, params)
    json(conn, result)
  end
end

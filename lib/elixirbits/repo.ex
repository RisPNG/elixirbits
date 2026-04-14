defmodule Elixirbits.Repo do
  use Ecto.Repo,
    otp_app: :elixirbits,
    adapter: Ecto.Adapters.Postgres
end

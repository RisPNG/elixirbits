defmodule Elixirbits.Ledger do
  use Ash.Domain,
    otp_app: :elixirbits

  resources do
    resource Elixirbits.Ledger.Account
    resource Elixirbits.Ledger.Balance
    resource Elixirbits.Ledger.Transfer
  end
end

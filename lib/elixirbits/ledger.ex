defmodule Elixirbits.Ledger do
  use Ash.Domain,
    otp_app: :elixirbits,
    extensions: [AshPaperTrail.Domain]

  paper_trail do
    include_versions? true
  end

  resources do
    resource Elixirbits.Ledger.Account
    resource Elixirbits.Ledger.Balance
    resource Elixirbits.Ledger.Transfer
  end
end

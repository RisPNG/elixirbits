defmodule Elixirbits.Accounts do
  use Ash.Domain,
    otp_app: :elixirbits,
    extensions: [AshAdmin.Domain, AshPaperTrail.Domain]

  admin do
    show? true
  end

  paper_trail do
    include_versions? true
  end

  resources do
    resource Elixirbits.Accounts.Token
    resource Elixirbits.Accounts.User
    resource Elixirbits.Accounts.ApiKey
    resource Elixirbits.Address
  end
end

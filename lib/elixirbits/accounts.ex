defmodule Elixirbits.Accounts do
  use Ash.Domain, otp_app: :elixirbits, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Elixirbits.Accounts.Token
    resource Elixirbits.Accounts.User
    resource Elixirbits.Accounts.ApiKey
  end
end

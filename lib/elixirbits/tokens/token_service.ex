defmodule Elixirbits.Tokens.TokenService do
  use Ash.Domain,
    otp_app: :elixirbits,
    extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Elixirbits.Accounts.Token
  end
end

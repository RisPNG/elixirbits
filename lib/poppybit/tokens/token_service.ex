defmodule Poppybit.Tokens.TokenService do
  use Ash.Domain,
    otp_app: :poppybit,
    extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Poppybit.Accounts.Token
  end
end

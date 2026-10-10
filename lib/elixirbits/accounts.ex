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

    resource Elixirbits.Accounts.User do
      define :get_user, action: :read, get_by: :id
      define :update_user_timezone, action: :update_timezone
    end

    resource Elixirbits.Accounts.ApiKey
    resource Elixirbits.Address
  end
end

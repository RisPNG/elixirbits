defmodule Elixirbits.ApiKeys.ApiKeyService do
  use Ash.Domain,
    otp_app: :elixirbits,
    extensions: [AshPaperTrail.Domain]

  paper_trail do
    include_versions? true
  end

  resources do
    resource Elixirbits.Accounts.ApiKey
  end
end

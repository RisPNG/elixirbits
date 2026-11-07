defmodule Poppybit.ApiKeys.ApiKeyService do
  use Ash.Domain,
    otp_app: :poppybit,
    extensions: [AshPaperTrail.Domain]

  paper_trail do
    include_versions? true
  end

  resources do
    resource Poppybit.Accounts.ApiKey
  end
end

defmodule Poppybit.Ledgers.LedgerService do
  use Ash.Domain,
    otp_app: :poppybit,
    extensions: [AshPaperTrail.Domain]

  paper_trail do
    include_versions? true
  end

  resources do
    resource Poppybit.Ledger.Account
    resource Poppybit.Ledger.Balance
    resource Poppybit.Ledger.Transfer
  end
end

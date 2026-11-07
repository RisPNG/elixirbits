defmodule Poppybit.Addresses.AddressService do
  use Ash.Domain,
    otp_app: :poppybit,
    extensions: [AshPaperTrail.Domain]

  paper_trail do
    include_versions? true
  end

  resources do
    resource Poppybit.Address
  end
end

defmodule Poppybit.SearchTest.Domain do
  use Ash.Domain, otp_app: :poppybit, validate_config_inclusion?: false

  resources do
    resource Poppybit.SearchTest.Category
    resource Poppybit.SearchTest.Record
  end
end

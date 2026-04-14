defmodule Elixirbits.SearchTest.Domain do
  use Ash.Domain, otp_app: :elixirbits, validate_config_inclusion?: false

  resources do
    resource Elixirbits.SearchTest.Category
    resource Elixirbits.SearchTest.Record
  end
end

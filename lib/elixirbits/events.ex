defmodule Elixirbits.Events do
  use Ash.Domain, otp_app: :elixirbits

  resources do
    resource Elixirbits.Events.Event
  end
end

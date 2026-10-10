defmodule ElixirbitsWeb.Presence do
  use Phoenix.Presence,
    otp_app: :elixirbits,
    pubsub_server: Elixirbits.PubSub
end

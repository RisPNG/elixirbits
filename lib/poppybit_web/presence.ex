defmodule PoppybitWeb.Presence do
  use Phoenix.Presence,
    otp_app: :poppybit,
    pubsub_server: Poppybit.PubSub
end

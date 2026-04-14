defmodule Elixirbits.Secrets do
  use AshAuthentication.Secret

  def secret_for(
        [:authentication, :tokens, :signing_secret],
        Elixirbits.Accounts.User,
        _opts,
        _context
      ) do
    Application.fetch_env(:elixirbits, :token_signing_secret)
  end
end

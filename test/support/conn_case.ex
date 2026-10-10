defmodule ElixirbitsWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also import other functionality to make it easier to build common data structures and query the data layer.

  Finally, if the test case interacts with the database, we enable the SQL sandbox, so changes done to the database are reverted at the end of every test. If you are using PostgreSQL, you can even run database tests asynchronously by setting `use ElixirbitsWeb.ConnCase, async: true`, although this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # The default endpoint for testing
      @endpoint ElixirbitsWeb.Endpoint

      use ElixirbitsWeb, :verified_routes

      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import ElixirbitsWeb.ConnCase
    end
  end

  setup tags do
    Elixirbits.DataCase.setup_sandbox(tags)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  def create_user(attrs \\ []) do
    attrs = Map.new(attrs)
    system = %{system: true}
    roles = Map.get(attrs, :roles, [])

    Enum.each(roles, fn code ->
      Ash.create!(Elixirbits.AccessControl.Role, %{code: code, name: code},
        actor: system,
        action: :create,
        upsert?: true,
        upsert_identity: :unique_code,
        upsert_fields: [:name]
      )
    end)

    user =
      Ash.create!(
        Elixirbits.Accounts.User,
        %{
          email: Map.get(attrs, :email, "user-#{System.unique_integer([:positive])}@example.com"),
          password: "password1234",
          password_confirmation: "password1234"
        },
        action: :register_with_password,
        actor: system
      )

    user = Ash.update!(user, %{roles: roles}, action: :assign_roles, actor: system)
    profile = Map.drop(attrs, [:email, :roles])
    if profile == %{}, do: user, else: Ash.update!(user, profile, action: :update, actor: system)
  end

  def log_in_user(conn, user) do
    token = AshAuthentication.Jwt.token_for_user(user) |> elem(1)
    Plug.Test.init_test_session(conn, %{"user_token" => token})
  end
end

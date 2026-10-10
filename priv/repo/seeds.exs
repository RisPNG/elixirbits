alias Elixirbits.AccessControl.Role
alias Elixirbits.AccessControl.Sitenav
alias Elixirbits.Accounts.User

require Ash.Query

system = %{system: true}

Ash.create!(
  Role,
  %{code: "superuser", name: "Superuser", description: "Administers the application."},
  action: :create,
  actor: system,
  upsert?: true,
  upsert_identity: :unique_code,
  upsert_fields: [:name, :description]
)

[
  %{
    code: "HOME",
    name: "Home",
    description: "Open your application workspace.",
    level: 1,
    parent: nil,
    url: "",
    sequence: 0,
    state: :ENABLED,
    roles_bypass: ["public"],
    users_bypass: []
  },
  %{
    code: "ADMIN",
    name: "Administration",
    level: 1,
    parent: nil,
    url: nil,
    sequence: 100,
    state: :ENABLED
  },
  %{
    code: "USERS",
    name: "Users",
    description: "Manage account profiles and role assignments.",
    level: 2,
    parent: "ADMIN",
    url: "admin/users",
    sequence: 110,
    state: :ENABLED
  },
  %{
    code: "ROLES",
    name: "Roles",
    description: "Manage page permissions for each role.",
    level: 2,
    parent: "ADMIN",
    url: "admin/roles",
    sequence: 120,
    state: :ENABLED
  },
  %{
    code: "ORG",
    name: "Organisation",
    description: "Manage application details and contact information.",
    level: 2,
    parent: "ADMIN",
    url: "admin/organisation",
    sequence: 130,
    state: :ENABLED
  },
  %{
    code: "DP",
    name: "Components",
    description: "Explore the application components.",
    level: 1,
    parent: nil,
    url: nil,
    sequence: 1000,
    state: :ENABLED,
    roles_bypass: [],
    users_bypass: []
  },
  %{
    code: "LT",
    name: "Layout Test",
    description: "Showcases most, if not all, front-end components.",
    level: 2,
    parent: "DP",
    url: "dev_panel/layout_test",
    sequence: 3000,
    state: :ENABLED,
    roles_bypass: ["public"],
    users_bypass: []
  }
]
|> Enum.each(fn attrs ->
  Ash.create!(Sitenav, attrs,
    action: :create,
    actor: system,
    upsert?: true,
    upsert_identity: :unique_code,
    upsert_fields: [:name, :description, :level, :parent, :url, :sequence]
  )
end)

accounts = [
  %{email: "admin@elixirbits.dev", password: "admin", administrator?: true},
  %{email: "user@elixirbits.dev", password: "user", administrator?: false}
]

accounts =
  case System.get_env("ELIXIRBITS_ADMIN_EMAIL") do
    nil ->
      accounts

    email ->
      accounts ++
        [
          %{
            email: email,
            password: System.get_env("ELIXIRBITS_ADMIN_PASSWORD"),
            administrator?: true
          }
        ]
  end

Enum.each(accounts, fn account ->
  email = account.email

  user =
    User
    |> Ash.Query.filter(email == ^email)
    |> Ash.read_one!(actor: system)

  user =
    user ||
      Ash.create!(
        User,
        %{
          email: email,
          password: account.password,
          password_confirmation: account.password
        },
        action: :seed_with_password,
        actor: system
      )

  if account.administrator? and "superuser" not in user.roles do
    Ash.update!(user, %{roles: ["superuser" | user.roles]},
      action: :assign_roles,
      actor: system
    )
  end
end)

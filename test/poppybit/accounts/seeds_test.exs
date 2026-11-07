defmodule Poppybit.Accounts.SeedsTest do
  use PoppybitWeb.ConnCase, async: false

  import Swoosh.TestAssertions
  require Ash.Query

  alias Poppybit.AccessControl.Permissions
  alias Poppybit.AccessControl.Role
  alias Poppybit.AccessControl.RolePerm
  alias Poppybit.AccessControl.Sitenav
  alias Poppybit.Accounts.User

  @seeds_file Path.expand("../../../priv/repo/seeds.exs", __DIR__)
  @system %{system: true}
  @profile_fields [
    :username,
    :display_name,
    :display_pic_url,
    :display_pic_name,
    :first_name,
    :middle_name,
    :last_name,
    :tel_no,
    :weight_kg,
    :height_cm,
    :dob,
    :sex,
    :locale,
    :timezone
  ]

  setup do
    environment =
      Map.new(["POPPYBIT_ADMIN_EMAIL", "POPPYBIT_ADMIN_PASSWORD"], fn name ->
        {name, System.get_env(name)}
      end)

    Enum.each(environment, fn {name, _value} -> System.delete_env(name) end)

    on_exit(fn ->
      Enum.each(environment, fn
        {name, nil} -> System.delete_env(name)
        {name, value} -> System.put_env(name, value)
      end)
    end)

    :ok
  end

  test "default navigation assigns icons to its top-level entries" do
    Code.eval_file(@seeds_file)

    for {code, icon} <- [
          {"HOME", "hero-home"},
          {"ADMIN", "hero-user-group"},
          {"DP", "hero-squares-2x2"}
        ] do
      assert %{parent: nil, icon: ^icon} = Ash.get!(Sitenav, %{code: code}, actor: @system)
    end

    for code <- ["USERS", "ROLES", "ORG", "LT"] do
      assert is_nil(Ash.get!(Sitenav, %{code: code}, actor: @system).icon)
    end
  end

  test "default accounts are confirmed, have empty profiles, and sign in with their seeded passwords",
       %{conn: conn} do
    Code.eval_file(@seeds_file)

    for {email, password, roles} <- [
          {"admin@poppybit.dev", "admin", ["superuser"]},
          {"user@poppybit.dev", "user", []}
        ] do
      user = User |> Ash.Query.filter(email == ^email) |> Ash.read_one!(actor: @system)

      assert user.roles == roles
      assert %DateTime{} = user.confirmed_at
      assert is_binary(user.hashed_password)
      refute user.hashed_password == password
      assert Enum.all?(@profile_fields, &is_nil(Map.fetch!(user, &1)))
      assert Ash.load!(user, :addresses, actor: @system).addresses == []

      conn =
        post(conn, ~p"/dashboard/auth/user/password/sign_in", %{
          "user" => %{"email" => email, "password" => password}
        })

      assert redirected_to(conn) == ~p"/dashboard"
      assert get_session(conn, "user_token")
    end

    admin =
      User
      |> Ash.Query.filter(email == "admin@poppybit.dev")
      |> Ash.read_one!(actor: @system)

    user =
      User
      |> Ash.Query.filter(email == "user@poppybit.dev")
      |> Ash.read_one!(actor: @system)

    assert Permissions.can?(admin, "/dashboard/admin/users", :su)
    refute Permissions.can?(user, "/dashboard/admin/users", :read)
    assert_no_email_sent()
  end

  test "repeated seeds preserve passwords, profiles, normal roles, and disabled navigation" do
    Code.eval_file(@seeds_file)

    user =
      User
      |> Ash.Query.filter(email == "user@poppybit.dev")
      |> Ash.read_one!(actor: @system)

    Ash.create!(Role, %{code: "member", name: "Member"}, actor: @system)

    user = Ash.update!(user, %{roles: ["member"]}, action: :assign_roles, actor: @system)
    user = Ash.update!(user, %{display_name: "Saved profile"}, action: :update, actor: @system)

    user =
      Ash.update!(
        user,
        %{
          current_password: "user",
          password: "changed-password",
          password_confirmation: "changed-password"
        },
        action: :change_password,
        actor: @system
      )

    page = Ash.get!(Sitenav, %{code: "USERS"}, actor: @system)
    Ash.update!(page, %{}, action: :disable, actor: @system)

    Code.eval_file(@seeds_file)
    updated = Ash.get!(User, user.id, actor: @system)

    assert updated.hashed_password == user.hashed_password
    assert updated.confirmed_at == user.confirmed_at
    assert updated.display_name == "Saved profile"
    assert updated.roles == ["member"]
    assert updated.updated_at == user.updated_at
    assert Ash.count!(User, actor: @system) == 2
    assert Ash.get!(Sitenav, page.id, actor: @system).state == :DISABLED
    assert_no_email_sent()
  end

  test "repeated seeds move existing navigation into the dashboard without changing grants" do
    Code.eval_file(@seeds_file)

    Ash.create!(Role, %{code: "editor", name: "Editor"}, actor: @system)

    grant =
      Ash.create!(RolePerm, %{roles_code: "editor", sitenav_code: "USERS", level: 5},
        actor: @system
      )

    paths = [
      {"HOME", "", "dashboard"},
      {"USERS", "admin/users", "dashboard/admin/users"},
      {"ROLES", "admin/roles", "dashboard/admin/roles"},
      {"ORG", "admin/organization", "dashboard/admin/organization"},
      {"LT", "dev_panel/layout_test", "dashboard/dev_panel/layout_test"}
    ]

    for {code, previous_url, _url} <- paths do
      Sitenav
      |> Ash.get!(%{code: code}, actor: @system)
      |> Ash.update!(%{url: previous_url}, actor: @system)
    end

    page = Ash.get!(Sitenav, %{code: "USERS"}, actor: @system)
    Ash.update!(page, %{}, action: :disable, actor: @system)
    Code.eval_file(@seeds_file)

    for {code, _previous_url, url} <- paths do
      assert Ash.get!(Sitenav, %{code: code}, actor: @system).url == url
    end

    assert %{state: :DISABLED} = Ash.get!(Sitenav, page.id, actor: @system)

    assert %{roles_code: "editor", sitenav_code: "USERS", level: 5} =
             Ash.get!(RolePerm, grant.id, actor: @system)
  end

  test "optional environment administrators use the same confirmed provisioning action" do
    email = "provisioned@example.com"
    System.put_env("POPPYBIT_ADMIN_EMAIL", email)
    System.put_env("POPPYBIT_ADMIN_PASSWORD", "extra")

    Code.eval_file(@seeds_file)
    user = User |> Ash.Query.filter(email == ^email) |> Ash.read_one!(actor: @system)

    assert user.roles == ["superuser"]
    assert %DateTime{} = user.confirmed_at
    assert Enum.all?(@profile_fields, &is_nil(Map.fetch!(user, &1)))
    assert_no_email_sent()
  end

  test "existing environment administrators keep their password and confirmation without a seed password" do
    existing = create_user(email: "existing@example.com", display_name: "Existing profile")
    assert is_nil(existing.confirmed_at)
    System.put_env("POPPYBIT_ADMIN_EMAIL", to_string(existing.email))

    Code.eval_file(@seeds_file)
    updated = Ash.get!(User, existing.id, actor: @system)

    assert updated.roles == ["superuser"]
    assert updated.hashed_password == existing.hashed_password
    assert updated.confirmed_at == existing.confirmed_at
    assert updated.display_name == existing.display_name
  end

  test "seed provisioning requires a system actor, including during authentication interactions" do
    Code.eval_file(@seeds_file)

    admin =
      User
      |> Ash.Query.filter(email == "admin@poppybit.dev")
      |> Ash.read_one!(actor: @system)

    for actor <- [nil, admin], authentication? <- [false, true] do
      assert {:error, %Ash.Error.Forbidden{}} =
               User
               |> Ash.Changeset.for_create(
                 :seed_with_password,
                 %{
                   email: "forged-#{System.unique_integer([:positive])}@example.com",
                   password: "user",
                   password_confirmation: "user"
                 },
                 actor: actor,
                 context: %{private: %{ash_authentication?: authentication?}}
               )
               |> Ash.create(actor: actor)
    end

    assert Ash.count!(User, actor: @system) == 2
    assert_no_email_sent()
  end

  test "normal registration, password changes, and resets retain their eight-character minimum" do
    Code.eval_file(@seeds_file)

    user =
      User
      |> Ash.Query.filter(email == "user@poppybit.dev")
      |> Ash.read_one!(actor: @system)

    strategy = AshAuthentication.Info.strategy!(User, :password)
    {:ok, reset_token} = AshAuthentication.Strategy.Password.reset_token_for(strategy, user)

    changesets = [
      Ash.Changeset.for_create(
        User,
        :register_with_password,
        %{email: "new@example.com", password: "user", password_confirmation: "user"},
        actor: @system
      ),
      Ash.Changeset.for_update(
        user,
        :change_password,
        %{current_password: "user", password: "short", password_confirmation: "short"},
        actor: @system
      ),
      Ash.Changeset.for_update(
        user,
        :reset_password_with_token,
        %{reset_token: reset_token, password: "short", password_confirmation: "short"},
        actor: @system
      )
    ]

    for changeset <- changesets do
      refute changeset.valid?

      assert Enum.any?(changeset.errors, fn error ->
               Map.get(error, :field) == :password and Map.get(error, :vars)[:min] == 8
             end)
    end
  end
end

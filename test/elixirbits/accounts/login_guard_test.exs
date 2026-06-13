defmodule Elixirbits.Accounts.LoginGuardTest do
  use ExUnit.Case, async: true

  alias Elixirbits.Accounts.LoginGuard

  test "locks after five consecutive failures and doubles each cycle" do
    email = "guard-cycle-#{System.unique_integer([:positive])}@example.com"

    for _ <- 1..4 do
      assert :ok = LoginGuard.record_failure(email)
    end

    assert :ok = LoginGuard.check(email)
    assert {:locked, 300} = LoginGuard.record_failure(email)
    assert {:locked, remaining} = LoginGuard.check(email)
    assert remaining in 1..300

    for _ <- 1..4 do
      LoginGuard.record_failure(email)
    end

    assert {:locked, 600} = LoginGuard.record_failure(email)

    for _ <- 1..4 do
      LoginGuard.record_failure(email)
    end

    assert {:locked, 1200} = LoginGuard.record_failure(email)
  end

  test "successful login resets the counter and the cooldown" do
    email = "guard-reset-#{System.unique_integer([:positive])}@example.com"

    for _ <- 1..5 do
      LoginGuard.record_failure(email)
    end

    assert {:locked, _remaining} = LoginGuard.check(email)

    assert :ok = LoginGuard.record_success(email)
    assert :ok = LoginGuard.check(email)

    for _ <- 1..4 do
      assert :ok = LoginGuard.record_failure(email)
    end

    assert {:locked, 300} = LoginGuard.record_failure(email)
  end

  test "normalizes case and whitespace on the email key" do
    base = "guard-norm-#{System.unique_integer([:positive])}"

    for _ <- 1..5 do
      LoginGuard.record_failure(" #{String.upcase(base)}@Example.com ")
    end

    assert {:locked, _remaining} = LoginGuard.check("#{base}@example.com")
  end
end

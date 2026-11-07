defmodule Poppybit.Accounts.LoginGuard do
  use GenServer

  @table __MODULE__
  @failures_per_lock 5
  @base_cooldown_seconds 5 * 60
  @sweep_interval_ms :timer.minutes(30)
  @stale_after_seconds 7 * 24 * 60 * 60

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def check(email) do
    key = email |> to_string() |> String.trim() |> String.downcase()

    case :ets.lookup(@table, key) do
      [{^key, _failures, locked_until, _updated_at}] ->
        remaining = locked_until - System.system_time(:second)
        if remaining > 0, do: {:locked, remaining}, else: :ok

      [] ->
        :ok
    end
  end

  def record_failure(email) do
    key = email |> to_string() |> String.trim() |> String.downcase()
    now = System.system_time(:second)
    failures = :ets.update_counter(@table, key, {2, 1}, {key, 0, 0, now})

    if rem(failures, @failures_per_lock) == 0 do
      cooldown =
        @base_cooldown_seconds * Integer.pow(2, div(failures, @failures_per_lock) - 1)

      :ets.insert(@table, {key, failures, now + cooldown, now})
      {:locked, cooldown}
    else
      :ets.update_element(@table, key, {4, now})
      :ok
    end
  end

  def record_success(email) do
    key = email |> to_string() |> String.trim() |> String.downcase()
    :ets.delete(@table, key)
    :ok
  end

  @impl true
  def init(_opts) do
    :ets.new(@table, [
      :named_table,
      :public,
      :set,
      read_concurrency: true,
      write_concurrency: true
    ])

    Process.send_after(self(), :sweep, @sweep_interval_ms)
    {:ok, nil}
  end

  @impl true
  def handle_info(:sweep, state) do
    now = System.system_time(:second)
    stale_cutoff = now - @stale_after_seconds

    :ets.select_delete(@table, [
      {{:_, :_, :"$1", :"$2"}, [{:<, :"$1", now}, {:<, :"$2", stale_cutoff}], [true]}
    ])

    Process.send_after(self(), :sweep, @sweep_interval_ms)
    {:noreply, state}
  end
end

defmodule Poppybit.Accounts.User.Senders.SendNewUserConfirmationEmail do
  @moduledoc """
  Sends an email for a new user to confirm their email address.
  """

  use AshAuthentication.Sender
  use PoppybitWeb, :verified_routes

  import Swoosh.Email

  alias Poppybit.Mailer

  @impl true
  def send(user, token, _) do
    new()
    # TODO: Replace with your email
    |> from({"noreply", "noreply@example.com"})
    |> to(to_string(user.email))
    |> subject("Confirm your email address")
    |> html_body(body(token: token))
    |> Mailer.deliver!()
  end

  defp body(params) do
    url = url(~p"/dashboard/confirm_new_user/#{params[:token]}")

    """
    <p>Click this link to confirm your email:</p>
    <p><a href="#{url}">#{url}</a></p>
    """
  end
end

defmodule Poppybit.Accounts.User.Senders.SendPasswordResetEmail do
  @moduledoc """
  Sends a password reset email
  """

  use AshAuthentication.Sender
  use PoppybitWeb, :verified_routes

  import Swoosh.Email

  alias Poppybit.Mailer

  @impl true
  def send(user, token, _) do
    new()
    # TODO: Replace with your email
    |> from({"noreply", "noreply@example.com"})
    |> to(to_string(user.email))
    |> subject("Reset your password")
    |> html_body(body(token: token))
    |> Mailer.deliver!()
  end

  defp body(params) do
    url = url(~p"/dashboard/password-reset/#{params[:token]}")

    """
    <p>Click this link to reset your password:</p>
    <p><a href="#{url}">#{url}</a></p>
    """
  end
end

defmodule Poppybit.Accounts.User.Senders.SendMagicLinkEmail do
  @moduledoc """
  Sends a magic link email
  """

  use AshAuthentication.Sender
  use PoppybitWeb, :verified_routes

  import Swoosh.Email
  alias Poppybit.Mailer

  @impl true
  def send(user_or_email, token, _) do
    # if you get a user, its for a user that already exists.
    # if you get an email, then the user does not yet exist.

    email =
      case user_or_email do
        %{email: email} -> email
        email -> email
      end

    new()
    # TODO: Replace with your email
    |> from({"noreply", "noreply@example.com"})
    |> to(to_string(email))
    |> subject("Your login link")
    |> html_body(body(token: token, email: email))
    |> Mailer.deliver!()
  end

  defp body(params) do
    # NOTE: You may have to change this to match your magic link acceptance URL.

    """
    <p>Hello, #{params[:email]}! Click this link to sign in:</p>
    <p><a href="#{url(~p"/dashboard/magic_link/#{params[:token]}")}">#{url(~p"/dashboard/magic_link/#{params[:token]}")}</a></p>
    """
  end
end

defmodule Poppybit.Users.UserService do
  use Ash.Domain,
    otp_app: :poppybit,
    extensions: [AshAdmin.Domain, AshPaperTrail.Domain]

  admin do
    show? true
  end

  paper_trail do
    include_versions? true
  end

  resources do
    resource Poppybit.Accounts.User do
      define :get_user, action: :read, get_by: :id
      define :update_user_timezone, action: :update_timezone
    end
  end
end

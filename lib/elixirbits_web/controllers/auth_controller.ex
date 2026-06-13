defmodule ElixirbitsWeb.AuthController do
  use ElixirbitsWeb, :controller
  use AshAuthentication.Phoenix.Controller

  alias Elixirbits.Accounts.LoginGuard

  def success(conn, {:password, :reset_request}, _user, _token) do
    conn
    |> put_flash(
      :info,
      "If an account exists for that email, password reset instructions have been sent."
    )
    |> redirect(to: ~p"/sign-in")
  end

  def success(conn, {:magic_link, :request}, _user, _token) do
    conn
    |> put_flash(:info, "If your email is valid, a sign-in link has been sent.")
    |> redirect(to: ~p"/sign-in")
  end

  def success(conn, activity, user, _token) do
    return_to = get_session(conn, :return_to) || ~p"/"

    lock =
      if activity == {:password, :sign_in},
        do: LoginGuard.check(user.email),
        else: :ok

    case lock do
      {:locked, seconds} ->
        conn
        |> put_flash(
          :error,
          "Too many failed attempts. Try again in #{div(seconds + 59, 60)} minutes."
        )
        |> redirect(to: ~p"/sign-in")

      :ok ->
        LoginGuard.record_success(user.email)

        message =
          case activity do
            {:confirm_new_user, :confirm} -> "Your email address has now been confirmed"
            {:password, :reset} -> "Your password has successfully been reset"
            _ -> "You are now signed in"
          end

        conn
        |> delete_session(:return_to)
        |> store_in_session(user)
        |> put_session(:remember_me, is_map(user.__metadata__[:remember_me]))
        # If your resource has a different name, update the assign name here (i.e :current_admin)
        |> assign(:current_user, user)
        |> put_flash(:info, message)
        |> redirect(to: return_to)
    end
  end

  def failure(conn, activity, reason) do
    message =
      case {activity, reason} do
        {_,
         %AshAuthentication.Errors.AuthenticationFailed{
           caused_by: %Ash.Error.Forbidden{
             errors: [%AshAuthentication.Errors.CannotConfirmUnconfirmedUser{}]
           }
         }} ->
          """
          You have already signed in another way, but have not confirmed your account.
          You can confirm your account using the link we sent to you, or by resetting your password.
          """

        {{:password, :sign_in}, _} ->
          lock =
            case conn.params do
              %{"user" => %{"email" => email}} when is_binary(email) and email != "" ->
                LoginGuard.record_failure(email)

              _ ->
                :ok
            end

          case lock do
            {:locked, seconds} ->
              "Too many failed attempts. Try again in #{div(seconds + 59, 60)} minutes."

            :ok ->
              "Incorrect email or password"
          end

        {{:password, :reset}, _} ->
          "Password reset link is invalid or expired"

        {{:magic_link, :sign_in}, _} ->
          "Magic link is invalid or expired"

        {{:confirm_new_user, :confirm}, _} ->
          "Confirmation link is invalid or expired"

        _ ->
          "Incorrect email or password"
      end

    redirect_to =
      case activity do
        {:password, :reset} -> ~p"/reset"
        _ -> ~p"/sign-in"
      end

    conn
    |> put_flash(:error, message)
    |> redirect(to: redirect_to)
  end

  def sign_out(conn, _params) do
    return_to = get_session(conn, :return_to) || ~p"/"

    conn
    |> clear_session(:elixirbits)
    |> put_flash(:info, "You are now signed out")
    |> redirect(to: return_to)
  end
end

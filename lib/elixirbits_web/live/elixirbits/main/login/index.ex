defmodule ElixirbitsWeb.LoginLive.Index do
  use ElixirbitsWeb, :live_view

  alias AshAuthentication.Info
  alias AshAuthentication.Strategy
  alias Elixirbits.Accounts.LoginGuard
  alias Elixirbits.Accounts.User

  @impl true
  def mount(_params, _session, socket) do
    strategy = Info.strategy!(User, :password)

    form =
      User
      |> AshPhoenix.Form.for_action(strategy.sign_in_action_name,
        as: "user",
        id: "login-form",
        context: %{
          strategy: strategy,
          token_type: :sign_in,
          private: %{ash_authentication?: true, skip_remember_me_token_generation: true}
        }
      )
      |> to_form()

    {:ok,
     socket
     |> assign(:page_title, "Sign In")
     |> assign(:form, form)}
  end

  @impl true
  def handle_event("validate", %{"user" => params}, socket) do
    form =
      socket.assigns.form.source
      |> AshPhoenix.Form.validate(params, errors: false)
      |> to_form()

    {:noreply, assign(socket, :form, form)}
  end

  @impl true
  def handle_event("submit", %{"user" => params}, socket) do
    case LoginGuard.check(params["email"]) do
      {:locked, seconds} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "Too many failed attempts. Try again in #{div(seconds + 59, 60)} minutes."
         )}

      :ok ->
        case AshPhoenix.Form.submit(socket.assigns.form.source, params: params, read_one?: true) do
          {:ok, user} ->
            LoginGuard.record_success(params["email"])

            {:noreply,
             redirect(socket,
               to:
                 ~p"/auth/user/password/sign_in_with_token?#{[token: user.__metadata__.token, remember_me: params["remember_me"]]}"
             )}

          {:error, form} ->
            lock =
              if params["email"] in [nil, ""],
                do: :ok,
                else: LoginGuard.record_failure(params["email"])

            message =
              case lock do
                {:locked, seconds} ->
                  "Too many failed attempts. Try again in #{div(seconds + 59, 60)} minutes."

                :ok ->
                  "Incorrect email or password"
              end

            {:noreply,
             socket
             |> put_flash(:error, message)
             |> assign(:form, form |> AshPhoenix.Form.clear_value(:password) |> to_form())}
        end
    end
  end

  @impl true
  def handle_event("request_magic_link", _params, socket) do
    email = AshPhoenix.Form.value(socket.assigns.form.source, :email)

    if email in [nil, ""] do
      {:noreply, put_flash(socket, :error, "Enter your email first.")}
    else
      strategy = Info.strategy!(User, :magic_link)
      :ok = Strategy.action(strategy, :request, %{"email" => to_string(email)})

      {:noreply,
       put_flash(socket, :info, "If your email is valid, a sign-in link has been sent.")}
    end
  end
end

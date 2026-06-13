defmodule ElixirbitsWeb.LoginLive.ForgotPassword do
  use ElixirbitsWeb, :live_view

  alias AshAuthentication.Info
  alias Elixirbits.Accounts.User

  @impl true
  def mount(_params, _session, socket) do
    strategy = Info.strategy!(User, :password)

    form =
      User
      |> AshPhoenix.Form.for_action(strategy.resettable.request_password_reset_action_name,
        as: "user",
        id: "forgot-password-form",
        context: %{strategy: strategy, private: %{ash_authentication?: true}}
      )
      |> to_form()

    {:ok,
     socket
     |> assign(:page_title, "Forgot Password")
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
    _ = AshPhoenix.Form.submit(socket.assigns.form.source, params: params)

    {:noreply,
     socket
     |> put_flash(
       :info,
       "If an account exists for that email, password reset instructions have been sent."
     )
     |> redirect(to: ~p"/sign-in")}
  end
end

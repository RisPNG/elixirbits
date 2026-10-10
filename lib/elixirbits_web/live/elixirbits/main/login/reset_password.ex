defmodule ElixirbitsWeb.LoginLive.ResetPassword do
  use ElixirbitsWeb, :live_view

  alias AshAuthentication.Info
  alias Elixirbits.Accounts.User
  alias Elixirbits.CoreUtils.Resource

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    strategy = Info.strategy!(User, :password)

    form =
      User
      |> AshPhoenix.Form.for_action(strategy.resettable.password_reset_action_name,
        as: "user",
        id: "reset-password-form",
        transform_params: &Resource.convert_form_datetimes/3,
        post_process_errors: &Resource.local_datetime_errors/3,
        context: %{
          shared: %{user_timezone: socket.assigns.user_timezone},
          strategy: strategy,
          private: %{ash_authentication?: true}
        }
      )
      |> to_form()

    {:ok,
     socket
     |> assign(:page_title, "Reset Password")
     |> assign(:token, token)
     |> assign(:trigger_action, false)
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
    form = AshPhoenix.Form.validate(socket.assigns.form.source, params)

    {:noreply,
     socket
     |> assign(:form, to_form(form))
     |> assign(:trigger_action, form.valid?)}
  end
end

defmodule ElixirbitsWeb.LoginLive.Register do
  use ElixirbitsWeb, :live_view

  alias AshAuthentication.Info
  alias Elixirbits.Accounts.User

  @impl true
  def mount(_params, _session, socket) do
    strategy = Info.strategy!(User, :password)

    form =
      User
      |> AshPhoenix.Form.for_action(strategy.register_action_name,
        as: "user",
        id: "register-form",
        context: %{strategy: strategy, private: %{ash_authentication?: true}}
      )
      |> to_form()

    {:ok,
     socket
     |> assign(:page_title, "Register")
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

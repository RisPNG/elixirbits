defmodule ElixirbitsWeb.Admin.OrganisationLive.Settings do
  use ElixirbitsWeb, :live_view

  on_mount {ElixirbitsWeb.LiveUserAuth, {:require_page_access, "/admin/organisation"}}

  alias Elixirbits.CoreUtils.EnumTypes.AddressLabel
  alias Elixirbits.CoreUtils.Phones
  alias Elixirbits.CoreUtils.Resource
  alias Elixirbits.CoreUtils.Search
  alias Elixirbits.Organisations
  alias Elixirbits.Organisations.Organisation
  alias LiveSelect.Component

  @impl true
  def mount(_params, _session, socket) do
    organisation =
      Organisations.organisation_settings!(
        actor: socket.assigns.current_user,
        load: [:addresses]
      )

    form =
      case organisation do
        nil ->
          AshPhoenix.Form.for_create(Organisation, :create,
            actor: socket.assigns.current_user,
            context: %{shared: %{user_timezone: socket.assigns.user_timezone}},
            transform_params: &Resource.convert_form_datetimes/3,
            post_process_errors: &Resource.local_datetime_errors/3,
            forms: [auto?: true]
          )

        organisation ->
          AshPhoenix.Form.for_update(organisation, :update,
            actor: socket.assigns.current_user,
            context: %{shared: %{user_timezone: socket.assigns.user_timezone}},
            transform_params: &Resource.convert_form_datetimes/3,
            post_process_errors: &Resource.local_datetime_errors/3,
            forms: [auto?: true]
          )
      end

    {:ok,
     socket
     |> assign(:page_title, "Organisation settings")
     |> assign(:organisation, organisation)
     |> assign(
       :editable?,
       can?(
         socket.assigns.permissions,
         "/admin/organisation",
         if(organisation, do: :update, else: :create)
       )
     )
     |> assign(
       :label_options,
       Enum.map(AddressLabel.values(), &{Phoenix.Naming.humanize(&1), to_string(&1)})
     )
     |> assign(:form, to_form(form))}
  end

  @impl true
  def handle_event("validate", %{"form" => params}, socket) do
    {:noreply, assign(socket, :form, AshPhoenix.Form.validate(socket.assigns.form, params))}
  end

  def handle_event("save", %{"form" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, organisation} ->
        organisation = Ash.load!(organisation, :addresses, actor: socket.assigns.current_user)

        {:noreply,
         socket
         |> assign(:organisation, organisation)
         |> assign(:editable?, can?(socket.assigns.permissions, "/admin/organisation", :update))
         |> update(:nav, &%{&1 | organisation: organisation})
         |> assign(
           :form,
           to_form(
             AshPhoenix.Form.for_update(organisation, :update,
               actor: socket.assigns.current_user,
               context: %{shared: %{user_timezone: socket.assigns.user_timezone}},
               transform_params: &Resource.convert_form_datetimes/3,
               post_process_errors: &Resource.local_datetime_errors/3,
               forms: [auto?: true]
             )
           )
         )
         |> put_flash(:info, "Organisation settings saved.")}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  def handle_event("add_form", _params, socket) do
    {:noreply, assign(socket, :form, AshPhoenix.Form.add_form(socket.assigns.form, [:addresses]))}
  end

  def handle_event("remove_form", %{"path" => path}, socket) do
    {:noreply, assign(socket, :form, AshPhoenix.Form.remove_form(socket.assigns.form, path))}
  end

  def handle_event("live_select_change", %{"id" => id} = params, socket) do
    text = Map.get(params, "text", "")

    if String.ends_with?(id, "_country_select") do
      send_update(Component, id: id, options: Phones.filter_options(text))
    else
      options =
        AddressLabel.values()
        |> Enum.map(&{Phoenix.Naming.humanize(&1), to_string(&1)})
        |> Search.filter(text)

      send_update(Component, id: id, options: options)
    end

    {:noreply, socket}
  end
end

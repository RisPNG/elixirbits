defmodule ElixirbitsWeb.Admin.OrganizationLive.Settings do
  use ElixirbitsWeb, :live_view

  alias Elixirbits.CoreUtils.EnumTypes.AddressLabel
  alias Elixirbits.CoreUtils.Resource
  alias Elixirbits.Organizations
  alias Elixirbits.Organizations.Organization
  alias ElixirbitsWeb.Admin.AuditLogLive.History

  on_mount {ElixirbitsWeb.LiveUserAuth, {:require_page_access, "/admin/organization"}}
  on_mount {History, Organization}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(
       socket,
       :label_options,
       Enum.map(AddressLabel.values(), &{Phoenix.Naming.humanize(&1), to_string(&1)})
     )}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    organization =
      Organizations.organization_settings!(
        actor: socket.assigns.current_user,
        load: [:addresses]
      )

    {socket, organization} = History.load_revision(socket, organization, params)

    form =
      case organization do
        nil ->
          AshPhoenix.Form.for_create(Organization, :create,
            actor: socket.assigns.current_user,
            context: %{shared: %{user_timezone: socket.assigns.user_timezone}},
            transform_params: &Resource.convert_form_datetimes/3,
            post_process_errors: &Resource.local_datetime_errors/3,
            forms: [auto?: true]
          )

        organization ->
          AshPhoenix.Form.for_update(organization, :update,
            id:
              if(socket.assigns.audit.selected,
                do: "form-#{socket.assigns.audit.selected.id}-#{socket.assigns.audit.side}",
                else: "form"
              ),
            actor: socket.assigns.current_user,
            context: %{shared: %{user_timezone: socket.assigns.user_timezone}},
            transform_params: &Resource.convert_form_datetimes/3,
            post_process_errors: &Resource.local_datetime_errors/3,
            forms: [auto?: true]
          )
      end

    {:noreply,
     socket
     |> assign(:page_title, "Organization settings")
     |> assign(:form, to_form(form))}
  end

  @impl true
  def handle_event("validate", %{"form" => params}, socket) do
    {:noreply, assign(socket, :form, AshPhoenix.Form.validate(socket.assigns.form, params))}
  end

  def handle_event("save", %{"form" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, _organization} ->
        {:noreply,
         socket
         |> put_flash(:info, "Organization settings saved.")
         |> push_navigate(to: ~p"/admin/organization")}

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
end

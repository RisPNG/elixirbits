defmodule PoppybitWeb.Dashboard.OrganizationLive.Settings do
  use PoppybitWeb, :live_view

  alias Poppybit.CoreUtils.Options.AddressLabel
  alias Poppybit.CoreUtils.Resource
  alias Poppybit.Organizations.OrganizationService
  alias Poppybit.Organizations.Organization
  alias PoppybitWeb.AuditLogLive.History

  on_mount {PoppybitWeb.LiveUserAuth, {:require_page_access, "/dashboard/admin/organization"}}
  on_mount {History, Organization}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(
       socket,
       label_options:
         Enum.map(AddressLabel.values(), &{Phoenix.Naming.humanize(&1), to_string(&1)}),
       currency_options:
         Enum.map(Cldr.Currency.known_currency_codes(), &{to_string(&1), to_string(&1)}),
       locale_options:
         Enum.map(Poppybit.Cldr.known_locale_names(), &{to_string(&1), to_string(&1)}),
       timezone_options:
         Enum.reject(socket.assigns.nav.timezone_options, fn {_label, value} -> value == "" end)
     )}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    organization =
      OrganizationService.organization_settings!(
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
            forms: [
              auto?: [
                relationship_fetcher: fn parent, relationship ->
                  value =
                    (Ash.Resource.get_metadata(parent, :audit_form_relationships) || %{})
                    |> Map.get(relationship.name, Map.get(parent, relationship.name))

                  case value do
                    %Ash.NotLoaded{} ->
                      if relationship.cardinality == :many, do: [], else: nil

                    value when relationship.cardinality == :one and is_list(value) ->
                      List.first(value)

                    value ->
                      value
                  end
                end
              ]
            ]
          )
      end

    {:noreply,
     socket
     |> assign(:page_title, "Organization settings")
     |> assign(:form, to_form(form))}
  end

  @impl true
  def handle_event(
        "validate",
        %{
          "form" => params,
          "address_position" => positions,
          "_target" => ["address_position", index]
        },
        socket
      ) do
    form = AshPhoenix.Form.validate(socket.assigns.form, params)
    index = String.to_integer(index)
    addresses = form.source.forms[:addresses] || []

    with {position, ""} when position > 0 and position <= length(addresses) <-
           Integer.parse(positions[to_string(index)]),
         true <- index >= 0 and index < length(addresses) do
      order =
        0..(length(addresses) - 1)
        |> Enum.to_list()
        |> List.replace_at(index, position - 1)
        |> List.replace_at(position - 1, index)

      {:noreply, assign(socket, :form, AshPhoenix.Form.sort_forms(form, [:addresses], order))}
    else
      _ -> {:noreply, assign(socket, :form, form)}
    end
  end

  def handle_event("validate", %{"form" => params}, socket) do
    {:noreply, assign(socket, :form, AshPhoenix.Form.validate(socket.assigns.form, params))}
  end

  def handle_event("save", %{"form" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, _organization} ->
        {:noreply,
         socket
         |> put_flash(:info, "Organization settings saved.")
         |> push_navigate(to: ~p"/dashboard/admin/organization")}

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

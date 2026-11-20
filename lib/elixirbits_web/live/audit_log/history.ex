defmodule ElixirbitsWeb.AuditLogLive.History do
  use ElixirbitsWeb, :html

  import Phoenix.LiveView, only: [attach_hook: 4, push_navigate: 2, push_patch: 2]
  import ElixirbitsWeb.CoreComponents.Flash, only: [put_flash: 3]

  alias Elixirbits.AccessControl.Permissions
  alias Elixirbits.CoreUtils.Resource.AuditLog

  embed_templates "history.html"

  attr :audit, :map, required: true
  attr :entry_sections, :list, required: true
  attr :user_timezone, :string, required: true
  def history(assigns)

  defp changed_sections(%{fields: fields}, entry_sections) do
    changed_fields =
      fields
      |> Enum.filter(&(&1.status == :changed))
      |> Enum.group_by(&(&1.relationship || &1.attribute))

    for {id, label, section_fields} <- entry_sections,
        changes = Enum.flat_map(section_fields, &Map.get(changed_fields, &1, [])),
        changes != [] do
      change =
        cond do
          Enum.all?(changes, &(&1.relationship && not &1.before_present?)) -> :added
          Enum.all?(changes, &(&1.relationship && not &1.after_present?)) -> :removed
          true -> :changed
        end

      {id, label, change}
    end
  end

  def on_mount(resource, _params, _session, socket) do
    socket =
      socket
      |> assign(:audit, %{resource: resource})
      |> attach_hook(:audit_edit_picker, :handle_params, fn params, uri, socket ->
        case socket.assigns do
          %{
            live_action: :update,
            audit: %{id: id} = audit,
            form: %{source: %{data: record}}
          }
          when not is_nil(id) ->
            uri = URI.parse(uri)

            if (audit.open? or params["history"] == "true") and
                 URI.parse(audit.path).path == socket.assigns.current_path and
                 Map.drop(Plug.Conn.Query.decode(uri.query || ""), ["history", "version", "side"]) ==
                   audit.query do
              {socket, _record} = load_revision(socket, record, params, audit.options)
              {:halt, socket}
            else
              {:cont, socket}
            end

          _ ->
            {:cont, socket}
        end
      end)
      |> attach_hook(:audit_restore, :handle_event, fn
        "audit_value_change", %{"audit" => %{"side" => side}}, socket
        when side in ["previous", "current"] ->
          audit = socket.assigns.audit

          if socket.assigns.live_action == :read and audit.selected do
            query = Map.put(audit.query, "version", audit.selected.id)

            query =
              if side == "current",
                do: Map.put(query, "side", "current"),
                else: query

            uri = URI.parse(audit.path)

            {:halt,
             push_patch(socket, to: URI.to_string(%{uri | query: Plug.Conn.Query.encode(query)}))}
          else
            {:halt, socket}
          end

        "audit_value_change", _params, socket ->
          {:halt, socket}

        "request_restore", _params, socket ->
          audit = socket.assigns.audit

          if socket.assigns.live_action == :read and audit.selected do
            case AuditLog.preview(
                   audit.resource,
                   audit.id,
                   audit.selected.id,
                   socket.assigns.current_user,
                   audit.options
                 ) do
              {:ok, fields} ->
                {:halt, assign(socket, :audit, %{audit | preview: fields})}

              {:error, error} ->
                message =
                  case error do
                    :forbidden ->
                      "Full create, read, update, and delete access is required to restore."

                    %Ash.Error.Forbidden{} ->
                      "Full create, read, update, and delete access is required to restore."

                    _ ->
                      "This revision could not be prepared for restoration."
                  end

                {:halt, put_flash(socket, :error, message)}
            end
          else
            {:halt, socket}
          end

        "cancel_restore", _params, socket ->
          {:halt, assign(socket, :audit, %{socket.assigns.audit | preview: nil})}

        "confirm_restore", _params, socket ->
          audit = socket.assigns.audit

          if (socket.assigns.live_action == :read and audit.preview) && audit.selected do
            case AuditLog.restore(
                   audit.resource,
                   audit.id,
                   audit.selected.id,
                   socket.assigns.current_user,
                   audit.options
                 ) do
              {:ok, _record} ->
                {:halt,
                 socket
                 |> put_flash(:info, "Version restored.")
                 |> push_navigate(to: audit.path)}

              {:error, error} ->
                message =
                  case error do
                    :forbidden ->
                      "Full create, read, update, and delete access is required to restore."

                    %Ash.Error.Forbidden{} ->
                      "You do not have permission to restore these changes."

                    :not_found ->
                      "That revision could not be found."

                    _ ->
                      "This revision could not be restored. Its values must satisfy the current record rules."
                  end

                {:halt,
                 socket
                 |> assign(:audit, %{audit | preview: nil})
                 |> put_flash(:error, message)}
            end
          else
            {:halt, socket}
          end

        _event, _params, socket ->
          {:cont, socket}
      end)

    {:cont, socket}
  end

  def load_revision(socket, record, params, opts \\ []) do
    resource = socket.assigns.audit.resource
    current_uri = URI.parse(socket.assigns.current_url)

    query =
      (current_uri.query || "")
      |> Plug.Conn.Query.decode()
      |> Map.drop(["history", "version", "side"])

    uri = %URI{
      path: socket.assigns.current_path,
      query: if(query != %{}, do: Plug.Conn.Query.encode(query))
    }

    path = URI.to_string(uri)
    options = Keyword.put(opts, :path, socket.assigns.current_path)
    key = if record, do: Map.take(record, Ash.Resource.Info.primary_key(resource))
    action = socket.assigns.live_action
    version = if action == :read, do: params["version"]

    requested? =
      not is_nil(key) and action in [:read, :update] and
        (params["history"] == "true" or not is_nil(version))

    socket =
      if requested? do
        permissions = Permissions.load(socket.assigns.current_user)

        socket
        |> assign(:permissions, permissions)
        |> assign(:current_user, permissions.user)
        |> update(
          :nav,
          &%{&1 | user: permissions.user, items: Permissions.visible_sitenav(permissions)}
        )
      else
        socket
      end

    audit = %{
      resource: resource,
      id: key,
      available?:
        not is_nil(key) and
          Permissions.can?(socket.assigns.permissions, socket.assigns.current_path, :update),
      path: path,
      query: query,
      options: options,
      revision_path: if(action == :update, do: opts[:view_path]),
      history_path:
        URI.to_string(%{uri | query: Plug.Conn.Query.encode(Map.put(query, "history", "true"))}),
      close_path: path,
      history: nil,
      selected: nil,
      fields: [],
      side: :previous,
      open?: false,
      preview: nil
    }

    if requested? do
      case AuditLog.history(resource, key, socket.assigns.current_user, options) do
        {:ok, history} ->
          selected = if version, do: Enum.find(history.revisions, &(to_string(&1.id) == version))

          if version && is_nil(selected) do
            socket =
              socket
              |> assign(:audit, audit)
              |> put_flash(:error, "That revision could not be found.")
              |> push_patch(to: path)

            {socket, record}
          else
            side = if params["side"] == "current", do: :current, else: :previous
            query = if selected, do: Map.put(query, "version", selected.id), else: query

            query =
              if selected && side == :current,
                do: Map.put(query, "side", "current"),
                else: query

            close_path =
              if selected,
                do: URI.to_string(%{uri | query: Plug.Conn.Query.encode(query)}),
                else: path

            audit = %{
              audit
              | history: history,
                selected: selected,
                fields:
                  cond do
                    is_nil(selected) -> []
                    side == :previous -> selected.fields
                    true -> selected.current_fields
                  end,
                side: side,
                open?: params["history"] == "true",
                close_path: close_path,
                history_path:
                  URI.to_string(%{
                    uri
                    | query: Plug.Conn.Query.encode(Map.put(query, "history", "true"))
                  })
            }

            record =
              if selected,
                do: AuditLog.revision_record(history.record, selected, side, options),
                else: history.record

            {assign(socket, :audit, audit), record}
          end

        {:error, error} ->
          message =
            case error do
              :forbidden -> "You need update access to view audit history."
              %Ash.Error.Forbidden{} -> "You need update access to view audit history."
              _ -> "Audit history could not be found."
            end

          socket =
            socket
            |> assign(:audit, audit)
            |> put_flash(:error, message)
            |> push_patch(to: path)

          {socket, record}
      end
    else
      {assign(socket, :audit, audit), record}
    end
  end
end

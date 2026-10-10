defmodule ElixirbitsWeb.Admin.LayoutTestLive do
  use ElixirbitsWeb, :live_view

  alias LiveSelect.Component
  alias Elixirbits.CoreUtils.Calendar, as: CalendarUtils
  alias Elixirbits.CoreUtils.Parse

  @dependency_pages [
    %{
      id: "swagger",
      name: "Swagger UI",
      source: "OpenApiSpex",
      path: "/api/json/swaggerui",
      availability: "always",
      description: "JSON API explorer and schema browser."
    },
    %{
      id: "dashboard",
      name: "Live Dashboard",
      source: "Phoenix LiveDashboard",
      path: "/dev/dashboard",
      availability: "dev only",
      description: "Runtime metrics, request log, processes, sockets."
    },
    %{
      id: "mailbox",
      name: "Mailbox Preview",
      source: "Swoosh",
      path: "/dev/mailbox",
      availability: "dev only",
      description: "Inspect local and test emails in the browser."
    },
    %{
      id: "ash-admin",
      name: "Ash Admin",
      source: "AshAdmin",
      path: "/admin",
      availability: "dev only",
      description: "Generated admin UI for resources and actions."
    }
  ]

  @dependency_options Enum.map(@dependency_pages, fn page ->
                        {"#{page.name} (#{page.source})", page.path}
                      end)

  @role_options [
    {"Administrator", "admin"},
    {"Designer", "designer"},
    {"Viewer", "viewer"}
  ]

  @tag_options [
    {"Elixir", "elixir"},
    {"Phoenix", "phoenix"},
    {"LiveView", "liveview"}
  ]

  @impl true
  def mount(_params, _session, socket) do
    now = DateTime.utc_now()
    timezone = socket.assigns.user_timezone
    today = now |> DateTime.shift_zone!(timezone) |> DateTime.to_date()

    morning =
      case DateTime.new(today, ~T[09:00:00], timezone) do
        {:ok, local} -> local
        {:ambiguous, first, _second} -> first
        {:gap, _before, following} -> following
      end
      |> DateTime.shift_zone!("Etc/UTC")

    {:ok,
     socket
     |> allow_upload(:demo_files,
       accept: ~w(.png .jpg .txt),
       max_entries: 3,
       max_file_size: 1_000_000
     )
     |> assign(:show_modal, false)
     |> assign(:upload_form, to_form(%{}, as: :upload))
     |> assign(:upload_mode, "enabled")
     |> assign(:stored_files, ["/images/logo.svg"])
     |> assign(:uploaded_names, [])
     |> assign(:timer_start, now)
     |> assign(:timer_finish, DateTime.add(now, 60, :second))
     |> assign(:submitted_at, nil)
     |> assign(:calendar_view, :week)
     |> assign(:calendar_cursor, today)
     |> assign(:calendar_selected, nil)
     |> assign(:calendar_resources, [%{id: "room-a", label: "Room A", sublabel: "Meeting room"}])
     |> assign(:calendar_events, [
       %{
         id: "planning",
         title: "Planning",
         start: morning,
         finish: DateTime.add(morning, 90, :minute),
         color: :brand,
         resource_id: "room-a"
       },
       %{
         id: "review",
         title: "Review",
         start: DateTime.add(morning, 30, :minute),
         finish: DateTime.add(morning, 120, :minute),
         color: :info,
         resource_id: "room-a"
       }
     ])
     |> assign(:current_scope, nil)
     |> assign(:current_tab, "local")
     |> assign(:dependency_form, to_form(%{}, as: :dependency))
     |> assign(:dependency_pages, @dependency_pages)
     |> assign(:dependency_options, @dependency_options)
     |> assign(
       :local_form,
       to_form(
         %{
           "hidden_token" => "LT-LOCAL",
           "project_name" => "Layout Test",
           "email" => "builder@elixirbits.dev",
           "password" => "password123",
           "budget" => "24000",
           "launch_date" => "2026-04-23",
           "launch_time" => "09:30",
           "launch_week" => "2026-W17",
           "launch_month" => "2026-04",
           "launch_at" => "2026-04-23T09:30",
           "accent" => "#c9822b",
           "search" => "flash button",
           "website" => "https://phoenixframework.org",
           "phone" => "+60 123456789",
           "notes" => "Core components, layout flow, dependency surfaces.",
           "role" => "admin",
           "enabled" => true
         },
         as: :local
       )
     )
     |> assign(:page_title, "Layout Test")
     |> assign(:sitenav_query, Ash.Query.sort(Elixirbits.AccessControl.Sitenav, sequence: :asc))
     |> assign(:selected_dependency, nil)}
  end

  @impl true
  def handle_event("local_change", %{"local" => params}, socket) do
    {:noreply, assign(socket, :local_form, to_form(params, as: :local))}
  end

  def handle_event("local_save", %{"local" => params}, socket) do
    params = Map.put_new(params, "launch_at", "")

    case Parse.to_datetime(params["launch_at"],
           source_timezone: socket.assigns.user_timezone,
           on_invalid: :error
         ) do
      %DateTime{} = instant ->
        {:noreply,
         socket
         |> assign(:local_form, to_form(params, as: :local))
         |> assign(:submitted_at, instant)
         |> put_flash(:info, "Example form submitted.")}

      invalid ->
        message =
          case invalid do
            {:error, :ambiguous_datetime} ->
              "This local time occurs twice. Choose another time."

            {:error, :nonexistent_datetime} ->
              "This local time does not exist. Choose another time."

            _ ->
              "Enter a valid date and time."
          end

        {:noreply,
         assign(
           socket,
           :local_form,
           to_form(params, as: :local, errors: [launch_at: {message, []}])
         )}
    end
  end

  def handle_event("show_modal", _params, socket),
    do: {:noreply, assign(socket, :show_modal, true)}

  def handle_event("hide_modal", _params, socket),
    do: {:noreply, assign(socket, :show_modal, false)}

  def handle_event("toggle_upload_mode", _params, socket) do
    mode = if socket.assigns.upload_mode == "enabled", do: "text-disabled", else: "enabled"
    {:noreply, assign(socket, :upload_mode, mode)}
  end

  def handle_event("upload_change", _params, socket), do: {:noreply, socket}

  def handle_event("upload_save", _params, socket) do
    names =
      consume_uploaded_entries(socket, :demo_files, fn _meta, entry ->
        {:ok, entry.client_name}
      end)

    {:noreply, assign(socket, :uploaded_names, names)}
  end

  def handle_event("remove_upload", %{"url" => url}, socket) do
    {:noreply, update(socket, :stored_files, &List.delete(&1, url))}
  end

  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :demo_files, ref)}
  end

  def handle_event("calendar_change", %{"event" => id}, socket) do
    {:noreply, assign(socket, :calendar_selected, id)}
  end

  def handle_event("calendar_change", %{"view" => view, "date" => date}, socket) do
    {:noreply,
     assign(socket,
       calendar_view: CalendarUtils.parse_view(view),
       calendar_cursor: Date.from_iso8601!(date)
     )}
  end

  @impl true
  def handle_event("change_tab", %{"tab" => tab}, socket) do
    {:noreply,
     assign(
       socket,
       :current_tab,
       if(tab in ["local", "ecosystem"], do: tab, else: socket.assigns.current_tab)
     )}
  end

  @impl true
  def handle_event("show_flash", %{"kind" => "info"}, socket) do
    {:noreply, put_flash(socket, :info, "Layout test info flash is alive.")}
  end

  @impl true
  def handle_event("show_flash", %{"kind" => "error"}, socket) do
    {:noreply, put_flash(socket, :error, "Layout test error flash is alive.")}
  end

  @impl true
  def handle_event("show_flash", %{"kind" => "warning"}, socket) do
    {:noreply, put_flash(socket, :warning, "Layout test warning flash is alive.")}
  end

  @impl true
  def handle_event("show_flash", _params, socket), do: {:noreply, socket}

  @impl true
  def handle_event("dependency_change", params, socket) do
    dependency_params = Map.get(params, "dependency", %{})

    {:noreply,
     socket
     |> assign(:dependency_form, to_form(dependency_params, as: :dependency))
     |> assign(
       :selected_dependency,
       case Map.get(dependency_params, "component_search") do
         nil ->
           nil

         "" ->
           nil

         path ->
           Enum.find(@dependency_pages, &(&1.path == path))
       end
     )}
  end

  @impl true
  def handle_event("live_select_change", %{"id" => id} = params, socket) do
    raw_text = Map.get(params, "text", "")
    text = String.downcase(raw_text)

    options =
      cond do
        id == "layout-test-local-role" ->
          Enum.filter(@role_options, fn {label, _} ->
            String.contains?(String.downcase(label), text)
          end)

        id == "layout-test-local-tags" ->
          Enum.filter(@tag_options, fn {label, _} ->
            String.contains?(String.downcase(label), text)
          end)

        String.ends_with?(id, "_country_select") ->
          Elixirbits.CoreUtils.Phones.filter_options(raw_text)

        true ->
          if text == "" do
            @dependency_options
          else
            @dependency_pages
            |> Enum.filter(fn page ->
              String.contains?(String.downcase(page.name), text) or
                String.contains?(String.downcase(page.source), text) or
                String.contains?(String.downcase(page.path), text)
            end)
            |> Enum.map(fn page -> {"#{page.name} (#{page.source})", page.path} end)
          end
      end

    send_update(Component, id: id, options: options)

    {:noreply, socket}
  end
end

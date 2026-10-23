defmodule ElixirbitsWeb.Admin.LayoutTestLive do
  use ElixirbitsWeb, :live_view

  alias LiveSelect.Component
  alias Elixirbits.CoreUtils.Calendar, as: CalendarUtils
  alias Elixirbits.CoreUtils.Color
  alias Elixirbits.CoreUtils.Parse

  @dependency_pages [
    %{
      id: "scalar",
      name: "Scalar",
      source: "scalar_api_plug",
      path: "/api/json/scalar",
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

  @input_render_modes ~w(enabled disabled like-enabled like-disabled hidden hidden-enabled hidden-disabled text text-enabled text-disabled)

  @input_fields ~w(project_name email password budget launch_date launch_time launch_week launch_month launch_at accent search website phone role notes enabled switch upload contact_method hidden_token)

  @upload_options [accept: ~w(.png .jpg .jpeg .gif .webp .pdf .txt), max_file_size: 1_000_000]

  @showcase_defaults %{
    "header" => %{
      "variant" => "default",
      "subtitle" => true,
      "actions" => true,
      "disabled" => false,
      "tooltip" => false,
      "navigation" => false
    },
    "flash" => %{
      "kind" => "info",
      "title" => false,
      "icon" => false,
      "spinner" => false,
      "duration" => "default"
    },
    "theme" => %{"inset" => true},
    "uploads" => %{
      "labels" => true,
      "disabled" => false,
      "required" => false,
      "tooltip" => false,
      "stored" => true,
      "selection" => "single",
      "preview_as" => "thumbnail",
      "preview" => true,
      "editor" => "false",
      "errors" => false
    },
    "actions" => %{
      "selected" => "create",
      "disabled" => false,
      "custom_icon" => false,
      "tooltip" => true,
      "count" => "2"
    },
    "calendar" => %{
      "events" => true,
      "variant" => "solid",
      "color" => "brand",
      "timer" => "elapsed"
    },
    "table" => %{"empty" => false, "actions" => true, "clickable" => false, "status" => true},
    "list" => %{"titles" => true, "count" => "4"},
    "icons" => %{"name" => "hero-sparkles", "size" => "5", "color" => "content", "label" => true},
    "dialog" => %{"title" => true, "actions" => true},
    "cinder" => %{
      "layout" => "table",
      "filters" => true,
      "search" => true,
      "sort" => true,
      "pagination" => true,
      "page_size" => "6",
      "columns" => "3"
    },
    "live_select" => %{
      "mode" => "single",
      "render_as" => "enabled",
      "prompt" => true,
      "keep_options" => true,
      "disabled" => false
    },
    "ui_kit" => %{
      "alert" => "info",
      "badge" => "brand",
      "progress" => "72",
      "step" => "2",
      "menu" => true
    },
    "pages" => %{"selected" => "scalar"}
  }

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

    record_entries = [
      %{
        "id" => "1",
        "code" => "DESIGN",
        "name" => "Design review",
        "quantity" => "2",
        "notes" => "Check the shared form components.",
        "status" => "Draft"
      },
      %{
        "id" => "2",
        "code" => "BUILD",
        "name" => "Build the showcase",
        "quantity" => "1",
        "notes" => "Try adding and removing entries.",
        "status" => "Draft"
      },
      %{
        "id" => "3",
        "code" => "CHECK",
        "name" => "Check the interactions",
        "quantity" => "3",
        "notes" => "Save changes, then use Back to discard later edits.",
        "status" => "Draft"
      },
      %{
        "id" => "4",
        "code" => "RELEASE",
        "name" => "Prepare the release",
        "quantity" => "1",
        "notes" => "Send or archive the selected entry.",
        "status" => "Draft"
      }
    ]

    {:ok,
     socket
     |> allow_upload(:demo_files, Keyword.put(@upload_options, :max_entries, 1))
     |> assign(:show_modal, false)
     |> assign(:upload_form, to_form(%{}, as: :upload))
     |> assign(:upload_mode, "enabled")
     |> assign(:stored_files, ["/images/logo.svg"])
     |> assign(:preview_names, %{})
     |> assign(:uploaded_names, [])
     |> assign(:timer_start, now)
     |> assign(:timer_finish, DateTime.add(now, 60, :second))
     |> assign(:submitted_at, nil)
     |> assign(:record_entries, record_entries)
     |> assign(:record_saved_entries, record_entries)
     |> assign(:record_form, to_form(%{}, as: :records))
     |> assign(:record_selected, "1")
     |> assign(:record_next_id, 5)
     |> assign(:record_mode, "enabled")
     |> assign(:record_columns, 2)
     |> assign(:record_message, "Edit the sample entries and try each action.")
     |> assign(:calendar_view, :month)
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
           "enabled" => true,
           "switch" => true,
           "contact_method" => "email",
           "upload" => nil
         },
         as: :local
       )
     )
     |> assign(:input_render_modes, @input_render_modes)
     |> assign(:input_populated_values, %{})
     |> assign(:input_config, %{
       "render_as" => "enabled",
       "variant" => "default",
       "select_mode" => "single"
     })
     |> assign(:showcase, @showcase_defaults)
     |> assign(:cinder_preview_state, %{})
     |> assign(:selected_dependencies, [])
     |> assign(:table_selection, nil)
     |> assign(:input_states, %{
       "empty" => false,
       "unlabeled" => false,
       "placeholder" => false,
       "required" => false,
       "errors" => false,
       "disabled" => false,
       "readonly" => false,
       "tooltip" => false,
       "constraints" => false,
       "datalist" => false,
       "multiple" => false,
       "capture" => false,
       "custom_class" => false,
       "custom_error_class" => false,
       "prompt" => false,
       "textarea_size" => false
     })
     |> assign(:page_title, "Layout Test")
     |> assign(:showcase_query, Ash.Query.sort(__MODULE__.CinderEntry, sequence: :asc))}
  end

  @impl true
  def handle_event("local_change", params, socket) do
    previous =
      Map.reject(socket.assigns.local_form.params, fn {field, _value} ->
        String.starts_with?(field, "_unused_")
      end)

    params =
      Enum.reduce(Map.get(params, "local", %{}), previous, fn {field, value}, values ->
        if String.ends_with?(field, "_empty_selection") and
             not String.starts_with?(field, "_unused_") do
          Map.put(values, String.replace_suffix(field, "_empty_selection", ""), [])
        else
          Map.put(values, field, value)
        end
      end)

    errors =
      case Ash.Type.cast_input(Color, params["accent"]) do
        {:ok, _color} -> []
        {:error, message} -> [accent: {message, []}]
      end

    {:noreply, assign(socket, :local_form, to_form(params, as: :local, errors: errors))}
  end

  def handle_event("local_save", params, socket) do
    previous =
      Map.reject(socket.assigns.local_form.params, fn {field, _value} ->
        String.starts_with?(field, "_unused_")
      end)

    params =
      params
      |> Map.get("local", %{})
      |> Map.put_new("launch_at", "")
      |> Map.reject(fn {field, _value} -> String.starts_with?(field, "_unused_") end)
      |> Enum.reduce(previous, fn {field, value}, values ->
        if String.ends_with?(field, "_empty_selection") and
             not String.starts_with?(field, "_unused_") do
          Map.put(values, String.replace_suffix(field, "_empty_selection", ""), [])
        else
          Map.put(values, field, value)
        end
      end)

    errors =
      case Ash.Type.cast_input(Color, params["accent"]) do
        {:ok, _color} -> []
        {:error, message} -> [accent: {message, []}]
      end

    instant =
      Parse.to_datetime(params["launch_at"],
        source_timezone: socket.assigns.user_timezone,
        on_invalid: :error
      )

    errors =
      case instant do
        %DateTime{} ->
          errors

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

          Keyword.put(errors, :launch_at, {message, []})
      end

    case errors do
      [] ->
        {:noreply,
         socket
         |> assign(:local_form, to_form(params, as: :local))
         |> assign(:submitted_at, instant)
         |> put_flash(:info, "Example form submitted.")}

      errors ->
        {:noreply,
         assign(
           socket,
           :local_form,
           to_form(params, as: :local, errors: errors)
         )}
    end
  end

  def handle_event("toggle_input_state", %{"state" => state}, socket) do
    socket = update(socket, :input_states, &Map.update!(&1, state, fn enabled -> not enabled end))

    socket =
      if state == "empty" do
        fields = @input_fields

        {populated, values} =
          if socket.assigns.input_states["empty"] do
            {Map.take(socket.assigns.local_form.params, fields), Map.new(fields, &{&1, nil})}
          else
            {socket.assigns.input_populated_values, socket.assigns.input_populated_values}
          end

        socket
        |> assign(:input_populated_values, populated)
        |> assign(
          :local_form,
          to_form(Map.merge(socket.assigns.local_form.params, values), as: :local)
        )
      else
        socket
      end

    {:noreply, socket}
  end

  def handle_event("set_input_config", %{"option" => option, "choice" => value}, socket) do
    socket =
      if option == "checked",
        do: socket,
        else: update(socket, :input_config, &Map.replace!(&1, option, value))

    socket =
      case option do
        "select_mode" ->
          params = socket.assigns.local_form.params

          role =
            if value == "single",
              do: List.first(List.wrap(params["role"])),
              else: List.wrap(params["role"])

          populated = socket.assigns.input_populated_values

          socket
          |> assign(:local_form, to_form(Map.put(params, "role", role), as: :local))
          |> assign(
            :input_populated_values,
            if(Map.has_key?(populated, "role"),
              do:
                Map.put(
                  populated,
                  "role",
                  if(value == "single",
                    do: List.first(List.wrap(populated["role"])),
                    else: List.wrap(populated["role"])
                  )
                ),
              else: populated
            )
          )

        "checked" ->
          checked = value == "true"

          socket =
            if socket.assigns.input_states["empty"] do
              update(
                socket,
                :input_populated_values,
                &Map.merge(&1, %{"enabled" => checked, "switch" => checked})
              )
            else
              socket
            end

          assign(
            socket,
            :local_form,
            to_form(
              Map.merge(socket.assigns.local_form.params, %{
                "enabled" => checked,
                "switch" => checked
              }),
              as: :local
            )
          )

        _ ->
          socket
      end

    {:noreply, socket}
  end

  def handle_event(
        "set_showcase_option",
        %{"section" => section, "option" => option, "choice" => value},
        socket
      ) do
    {:noreply, configure_showcase_preview(socket, section, %{option => value})}
  end

  def handle_event("showcase_change", %{"section" => section, "showcase" => options}, socket) do
    {:noreply, configure_showcase_preview(socket, section, options)}
  end

  def handle_event("toggle_showcase_option", %{"section" => section, "option" => option}, socket) do
    {:noreply,
     configure_showcase_preview(socket, section, %{
       option => not socket.assigns.showcase[section][option]
     })}
  end

  def handle_event("inspect_table_row", %{"section" => section}, socket) do
    {:noreply, assign(socket, :table_selection, section)}
  end

  def handle_event("reset_timer", _params, socket) do
    now = DateTime.utc_now()
    {:noreply, assign(socket, timer_start: now, timer_finish: DateTime.add(now, 60, :second))}
  end

  def handle_event("preview_flash", _params, socket) do
    options = socket.assigns.showcase["flash"]
    kind = String.to_existing_atom(options["kind"])

    payload = %{
      msg: "Layout test #{options["kind"]} flash is alive.",
      title: if(options["title"], do: "Example notification"),
      icon: if(options["icon"], do: "hero-bell"),
      show_spinner: options["spinner"],
      duration: if(options["duration"] != "default", do: String.to_integer(options["duration"]))
    }

    {:noreply, put_flash(socket, kind, payload)}
  end

  def handle_event("show_modal", _params, socket),
    do: {:noreply, assign(socket, :show_modal, true)}

  def handle_event("hide_modal", _params, socket),
    do: {:noreply, assign(socket, :show_modal, false)}

  def handle_event("record_change", %{"records" => params}, socket) do
    entries =
      Enum.map(socket.assigns.record_entries, fn entry ->
        changes = params |> Map.get(entry["id"], %{}) |> Map.take(~w(code name quantity notes))
        Map.merge(entry, changes)
      end)

    {:noreply, assign(socket, :record_entries, entries)}
  end

  def handle_event("record_action", %{"action" => action} = params, socket) do
    socket =
      if params["records"] do
        entries =
          Enum.map(socket.assigns.record_entries, fn entry ->
            changes =
              params["records"]
              |> Map.get(entry["id"], %{})
              |> Map.take(~w(code name quantity notes))

            Map.merge(entry, changes)
          end)

        assign(socket, :record_entries, entries)
      else
        socket
      end

    selected = Map.get(params, "id", socket.assigns.record_selected)

    case action do
      "create" ->
        id = to_string(socket.assigns.record_next_id)

        entry = %{
          "id" => id,
          "code" => "NEW-#{id}",
          "name" => "New entry",
          "quantity" => "1",
          "notes" => "",
          "status" => "Draft"
        }

        {:noreply,
         socket
         |> update(:record_entries, &(&1 ++ [entry]))
         |> assign(
           record_selected: id,
           record_next_id: socket.assigns.record_next_id + 1,
           record_mode: "enabled",
           record_message: "Added entry ##{id}."
         )}

      "read" ->
        {:noreply,
         assign(socket,
           record_selected: selected,
           record_mode: "text-disabled",
           record_message: "Viewing entry ##{selected}."
         )}

      "update" ->
        {:noreply,
         assign(socket,
           record_selected: selected,
           record_mode: "enabled",
           record_message: "Editing entry ##{selected}."
         )}

      "save" ->
        {:noreply,
         assign(socket,
           record_saved_entries: socket.assigns.record_entries,
           record_message: "Saved the sample entries for this session."
         )}

      action when action in ["send", "archive"] ->
        status = if action == "send", do: "Sent", else: "Archived"

        entries =
          Enum.map(socket.assigns.record_entries, fn entry ->
            if entry["id"] == selected, do: Map.put(entry, "status", status), else: entry
          end)

        {:noreply,
         assign(socket,
           record_entries: entries,
           record_selected: selected,
           record_message: "#{status} entry ##{selected}."
         )}

      "delete" ->
        entries = Enum.reject(socket.assigns.record_entries, &(&1["id"] == selected))
        next = List.first(entries)

        {:noreply,
         assign(socket,
           record_entries: entries,
           record_selected: next && next["id"],
           record_message: "Deleted entry ##{selected}."
         )}

      "back" ->
        entries = socket.assigns.record_saved_entries
        first = List.first(entries)

        {:noreply,
         assign(socket,
           record_entries: entries,
           record_selected: first && first["id"],
           record_mode: "text-disabled",
           record_message: "Returned to the last saved entries."
         )}
    end
  end

  def handle_event("upload_change", _params, socket), do: {:noreply, socket}

  def handle_event("upload_save", params, socket) do
    replacements = Map.get(params, "demo_files_replacements", %{})
    file_order = Map.new(Enum.with_index(Map.get(params, "demo_files_order", [])))

    files =
      consume_uploaded_entries(socket, :demo_files, fn %{path: path}, entry ->
        url =
          "data:#{MIME.from_path(entry.client_name)};base64,#{Base.encode64(File.read!(path))}"

        {:ok,
         {url, entry.client_name, Map.get(replacements, entry.ref),
          Map.get(file_order, entry.ref, map_size(file_order))}}
      end)
      |> Enum.sort_by(fn {_url, _name, _previous, index} -> index end)

    stored_files =
      if socket.assigns.showcase["uploads"]["selection"] == "single" and files != [] do
        Enum.map(files, fn {url, _name, _previous, _index} -> url end)
      else
        Enum.reduce(files, socket.assigns.stored_files, fn {url, _name, previous, _index},
                                                           stored ->
          case Enum.find_index(stored, &(&1 == previous)) do
            nil -> stored ++ [url]
            index -> List.replace_at(stored, index, url)
          end
        end)
        |> Enum.uniq()
      end

    {:noreply,
     socket
     |> assign(:stored_files, stored_files)
     |> assign(
       :preview_names,
       socket.assigns.preview_names
       |> Map.merge(Map.new(files, fn {url, name, _previous, _index} -> {url, name} end))
       |> Map.take(stored_files)
     )
     |> assign(:uploaded_names, Enum.map(files, fn {_url, name, _previous, _index} -> name end))}
  end

  def handle_event("remove_upload", %{"url" => url}, socket) do
    {:noreply,
     socket
     |> update(:stored_files, &List.delete(&1, url))
     |> update(:preview_names, &Map.delete(&1, url))}
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

  def handle_event("show_flash", %{"kind" => kind}, socket) when kind in ~w(info error warning) do
    {:noreply,
     put_flash(socket, String.to_existing_atom(kind), "Layout test #{kind} flash is alive.")}
  end

  @impl true
  def handle_event("dependency_change", params, socket) do
    dependency_params = Map.get(params, "dependency", %{})

    value =
      if Map.has_key?(dependency_params, "component_search_empty_selection"),
        do: [],
        else: dependency_params["component_search"]

    paths = List.wrap(value)

    {:noreply,
     socket
     |> assign(
       :dependency_form,
       to_form(Map.put(dependency_params, "component_search", value), as: :dependency)
     )
     |> assign(
       :selected_dependencies,
       Enum.filter(@dependency_pages, &(&1.path in paths))
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

  defp configure_showcase_preview(socket, section, options) do
    options =
      cond do
        section == "uploads" ->
          options =
            if socket.assigns.uploads.demo_files.entries != [],
              do: Map.delete(options, "selection"),
              else: options

          if Map.get(options, "selection", socket.assigns.showcase["uploads"]["selection"]) ==
               "multiple" or
               Map.get(options, "preview", socket.assigns.showcase["uploads"]["preview"]) not in [
                 true,
                 "true"
               ],
             do: Map.put(options, "editor", "false"),
             else: options

        section == "ui_kit" and Map.has_key?(options, "progress") ->
          progress =
            case Integer.parse(options["progress"]) do
              {value, ""} -> value |> max(0) |> min(100) |> Integer.to_string()
              _ -> socket.assigns.showcase["ui_kit"]["progress"]
            end

          Map.put(options, "progress", progress)

        true ->
          options
      end

    socket =
      case section do
        "cinder" ->
          if Enum.any?(~w(layout page_size), fn option ->
               Map.has_key?(options, option) and
                 options[option] != socket.assigns.showcase["cinder"][option]
             end) do
            assign(socket, :cinder_preview_state, %{})
          else
            socket
          end

        "uploads" ->
          socket =
            assign(
              socket,
              :upload_mode,
              Map.get(options, "render_as", socket.assigns.upload_mode)
            )

          if options["selection"] &&
               options["selection"] != socket.assigns.showcase["uploads"]["selection"] do
            socket
            |> disallow_upload(:demo_files)
            |> allow_upload(
              :demo_files,
              Keyword.put(
                @upload_options,
                :max_entries,
                if(options["selection"] == "single", do: 1, else: 3)
              )
            )
          else
            socket
          end

        "actions" ->
          assign(socket,
            record_mode: Map.get(options, "render_as", socket.assigns.record_mode),
            record_columns:
              String.to_integer(
                Map.get(options, "columns", to_string(socket.assigns.record_columns))
              )
          )

        "live_select" ->
          if options["mode"] do
            params = socket.assigns.dependency_form.params

            value =
              if options["mode"] == "single",
                do: List.first(List.wrap(params["component_search"])),
                else: List.wrap(params["component_search"])

            socket
            |> assign(
              :dependency_form,
              to_form(Map.put(params, "component_search", value), as: :dependency)
            )
            |> assign(
              :selected_dependencies,
              Enum.filter(@dependency_pages, &(&1.path in List.wrap(value)))
            )
          else
            socket
          end

        _ ->
          socket
      end

    update(socket, :showcase, fn sections ->
      Map.update!(sections, section, fn current ->
        options
        |> Map.take(Map.keys(current))
        |> Enum.reduce(current, fn {option, value}, configured ->
          Map.put(
            configured,
            option,
            if(is_boolean(current[option]), do: value in [true, "true"], else: value)
          )
        end)
      end)
    end)
  end

  @impl true
  def handle_info({:cinder_preview_state_change, _id, state}, socket) do
    {:noreply,
     assign(
       socket,
       :cinder_preview_state,
       Map.new(state, fn {key, value} -> {to_string(key), value} end)
     )}
  end
end

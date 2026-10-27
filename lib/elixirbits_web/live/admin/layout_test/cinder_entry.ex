defmodule ElixirbitsWeb.Admin.LayoutTestLive.CinderEntry do
  use Ash.Resource, data_layer: :embedded

  actions do
    defaults []

    read :read do
      primary? true

      pagination do
        offset? true
        countable true
        required? false
      end

      manual fn query, _data_layer_query, _context ->
        sections = [
          "Core inputs",
          "Live uploads",
          "Record actions",
          "Calendar",
          "Timers",
          "Cinder collection",
          "Cinder table",
          "Cinder grid",
          "Combobox",
          "Buttons",
          "Tables",
          "Dialogs"
        ]

        entries =
          Enum.map(1..120, fn sequence ->
            number = sequence |> Integer.to_string() |> String.pad_leading(3, "0")
            suffix = sequence |> Integer.to_string(16) |> String.pad_leading(12, "0")
            section = Enum.at(sections, rem(sequence - 1, length(sections)))

            struct!(query.resource,
              id: "01a0f4c2-c400-7000-8000-#{suffix}",
              code: "EX#{number}",
              name: "#{section} example #{number}",
              description: "Sample #{section} record for pagination, filtering, and sorting.",
              level: rem(sequence - 1, 3) + 1,
              url: "/dev_panel/layout_test?example=#{number}",
              sequence: sequence,
              state: if(rem(sequence, 4) == 0, do: :DISABLED, else: :ENABLED),
              inserted_at: ~U[2026-10-01 00:00:00Z],
              updated_at: ~U[2026-10-01 00:00:00Z]
            )
          end)

        with {:ok, matches} <-
               query |> Ash.Query.unset([:limit, :offset, :page]) |> Ash.Query.apply_to(entries),
             {:ok, page} <- Ash.Query.apply_to(query, entries) do
          {:ok, page, %{full_count: length(matches)}}
        end
      end
    end
  end

  attributes do
    uuid_v7_primary_key :id
    attribute :code, :string, allow_nil?: false, public?: true
    attribute :name, :string, allow_nil?: false, public?: true
    attribute :description, :string, public?: true
    attribute :level, :integer, public?: true
    attribute :url, :string, public?: true
    attribute :sequence, :integer, public?: true
    attribute :state, Elixirbits.CoreUtils.EnumTypes.SitenavState, public?: true
    timestamps()
  end
end

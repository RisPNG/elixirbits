defmodule Elixirbits.CoreUtils.Resource do
  @moduledoc false

  alias Ash.Page.Keyset
  alias Ash.Page.Offset
  alias Elixirbits.CoreUtils.Parse

  @text_types [:string, :ci_string]

  def detect_schema_field?(resource, field) do
    case Ash.Resource.Info.field(resource, field) do
      nil -> nil
      field_info -> normalize_type(field_info.type)
    end
  end

  def convert_value_to_field(resource, field, value, user_timezone \\ "Etc/UTC") do
    field_info =
      case Ash.Resource.Info.field(resource, field) do
        nil ->
          raise "Field #{inspect(field)} not found on resource #{inspect(resource)}"

        field_info ->
          field_info
      end

    convert_type_value(field_info.type, field_info.constraints, value, user_timezone)
  end

  def convert_form_datetimes(%AshPhoenix.Form{} = form, params, _stage) do
    timezone = get_in(form.opts, [:context, :shared, :user_timezone]) || "Etc/UTC"
    action = Ash.Resource.Info.action(form.resource, form.action)

    (action.arguments ++ Ash.Resource.Info.attributes(form.resource))
    |> Enum.uniq_by(& &1.name)
    |> Enum.reduce(params, fn field, params ->
      storage_type = Ash.Type.storage_type(field.type, field.constraints)

      if storage_type in [
           :utc_datetime,
           :utc_datetime_usec,
           {:array, :utc_datetime},
           {:array, :utc_datetime_usec}
         ] do
        Enum.reduce([field.name, to_string(field.name)], params, fn key, params ->
          case Map.fetch(params, key) do
            {:ok, value} ->
              Map.put(
                params,
                key,
                convert_type_value(field.type, field.constraints, value, timezone,
                  on_invalid: :error
                )
              )

            :error ->
              params
          end
        end)
      else
        params
      end
    end)
  end

  def local_datetime_errors(%AshPhoenix.Form{} = form, _path, {field, _message, _vars} = error) do
    timezone = get_in(form.opts, [:context, :shared, :user_timezone]) || "Etc/UTC"

    case AshPhoenix.Form.value(form, field) do
      {:error, :ambiguous_datetime} ->
        {field,
         "occurs twice in %{timezone}, so include a UTC offset to choose the intended time",
         [timezone: timezone]}

      {:error, :nonexistent_datetime} ->
        {field, "does not exist in %{timezone}", [timezone: timezone]}

      {:error, :invalid_datetime} ->
        {field, "must be a valid date and time", []}

      _ ->
        error
    end
  end

  def ensure_loaded_associations(data, preloads \\ true)

  def ensure_loaded_associations(nil, _preloads), do: nil

  def ensure_loaded_associations(%Offset{results: results} = page, preloads) do
    %{page | results: ensure_loaded_associations(results, preloads)}
  end

  def ensure_loaded_associations(%Keyset{results: results} = page, preloads) do
    %{page | results: ensure_loaded_associations(results, preloads)}
  end

  def ensure_loaded_associations([], _preloads), do: []

  def ensure_loaded_associations([record | _] = records, preloads) do
    loads = normalize_relationship_loads(record.__struct__, preloads)

    if loads == [] do
      records
    else
      Ash.load!(records, loads, domain: Ash.Resource.Info.domain(record.__struct__))
    end
  end

  def ensure_loaded_associations(%resource{} = record, preloads) do
    loads = normalize_relationship_loads(resource, preloads)

    if loads == [] do
      record
    else
      Ash.load!(record, loads, domain: Ash.Resource.Info.domain(resource))
    end
  end

  def next_sequence(source_or_form, field_or_opts \\ [], opts \\ [])

  def next_sequence(form, field, opts) when is_atom(field) do
    forms =
      case form do
        %{source: %{forms: forms}} -> forms
        %{forms: forms} -> forms
      end

    forms |> Map.get(field, []) |> next_sequence(opts)
  end

  def next_sequence(source, opts, []) when is_list(opts) do
    field = Keyword.get(opts, :field, :sequence)
    increment = Keyword.get(opts, :increment, 1)

    sequences =
      source
      |> List.wrap()
      |> Enum.map(fn value ->
        sequence =
          case value do
            value when is_binary(value) or is_number(value) -> value
            %AshPhoenix.Form{} = form -> AshPhoenix.Form.value(form, field)
            %Phoenix.HTML.Form{} = form -> AshPhoenix.Form.value(form, field)
            %{} = record -> Map.get(record, field) || Map.get(record, to_string(field))
            nil -> nil
          end

        Parse.to_integer(sequence, 0)
      end)

    sequence =
      case sequences do
        [] -> Keyword.get(opts, :start, increment)
        sequences -> Enum.max(sequences) + increment
      end

    if Keyword.has_key?(opts, :prefix) or Keyword.has_key?(opts, :suffix) or
         Keyword.has_key?(opts, :padding) do
      number =
        Integer.to_string(sequence) |> String.pad_leading(Keyword.get(opts, :padding, 0), "0")

      prefix = opts |> Keyword.get(:prefix) |> List.wrap()
      suffix = opts |> Keyword.get(:suffix) |> List.wrap()

      (prefix ++ [number] ++ suffix)
      |> Enum.reject(&(&1 in [nil, ""]))
      |> Enum.map(&to_string/1)
      |> Enum.join(Keyword.get(opts, :separator, "-"))
    else
      sequence
    end
  end

  def normalize_relationship_loads(resource, true) do
    Enum.map(Ash.Resource.Info.relationships(resource), & &1.name)
  end

  def normalize_relationship_loads(resource, preload) when is_list(preload) do
    preload
    |> Enum.reduce([], fn load, loads ->
      case normalize_relationship_load(resource, load) do
        nil -> loads
        normalized -> [normalized | loads]
      end
    end)
    |> Enum.reverse()
  end

  def normalize_relationship_loads(resource, preload) when preload not in [false, nil] do
    case normalize_relationship_load(resource, preload) do
      nil -> []
      normalized -> [normalized]
    end
  end

  def normalize_relationship_loads(_resource, preload) when preload in [false, nil], do: []

  defp convert_type_value(type, constraints, value, user_timezone, opts \\ [])

  defp convert_type_value(_type, _constraints, value, _user_timezone, _opts)
       when value in ["", nil] do
    nil
  end

  defp convert_type_value({:array, type}, constraints, value, user_timezone, opts)
       when is_list(value) do
    value
    |> Enum.reject(&(&1 in ["", nil, [], -1, "-1"]))
    |> Enum.map(fn item ->
      convert_type_value(type, item_constraints(constraints), item, user_timezone, opts)
    end)
  end

  defp convert_type_value({:array, type}, constraints, value, user_timezone, opts) do
    [convert_type_value(type, item_constraints(constraints), value, user_timezone, opts)]
  end

  defp convert_type_value(type, constraints, value, user_timezone, opts) do
    normalized_type = normalize_type(type)
    storage_type = Ash.Type.storage_type(Ash.Type.get_type(type), constraints || [])

    cond do
      storage_type in [:utc_datetime, :utc_datetime_usec] ->
        case value do
          {:error, _reason} = error ->
            if Keyword.get(opts, :on_invalid) == :error, do: error, else: nil

          value ->
            Parse.to_datetime(value,
              source_timezone: user_timezone,
              target_timezone: "Etc/UTC",
              precision: if(storage_type == :utc_datetime_usec, do: :microsecond, else: :second),
              on_invalid: Keyword.get(opts, :on_invalid)
            )
        end

      storage_type in [:naive_datetime, :naive_datetime_usec] ->
        Parse.to_naive_datetime(value,
          precision: if(storage_type == :naive_datetime_usec, do: :microsecond, else: :second)
        )

      normalized_type == :date and match?(%Date{}, value) ->
        value

      normalized_type == :date and is_binary(value) ->
        case Date.from_iso8601(value) do
          {:ok, date} -> date
          _ -> nil
        end

      normalized_type == :time and match?(%Time{}, value) ->
        value

      normalized_type == :time and is_binary(value) ->
        case Time.from_iso8601(value) do
          {:ok, time} -> time
          _ -> nil
        end

      normalized_type in @text_types ->
        case Ash.Type.cast_input(type, value, constraints || []) do
          {:ok, casted} -> casted
          _ -> if(is_nil(value), do: nil, else: to_string(value))
        end

      normalized_type == :binary ->
        value

      normalized_type == :map ->
        value

      true ->
        case Ash.Type.cast_input(type, value, constraints || []) do
          {:ok, casted} ->
            casted

          _ when normalized_type in [:boolean, :integer, :float, :decimal, :date, :time] ->
            nil

          _ ->
            value
        end
    end
  end

  def normalize_relationship_load(resource, {relationship, nested}) do
    case Ash.Resource.Info.relationship(resource, relationship) do
      nil ->
        nil

      relationship_info ->
        normalized_nested = normalize_relationship_loads(relationship_info.destination, nested)

        if normalized_nested == [] do
          relationship_info.name
        else
          {relationship_info.name, normalized_nested}
        end
    end
  end

  def normalize_relationship_load(resource, relationship) do
    case Ash.Resource.Info.relationship(resource, relationship) do
      nil -> nil
      relationship_info -> relationship_info.name
    end
  end

  defp item_constraints(constraints) do
    Keyword.get(constraints || [], :items, [])
  end

  def normalize_type({:array, type}), do: {:array, normalize_type(type)}

  def normalize_type(type) do
    case Enum.find(Ash.Type.short_names(), &(elem(&1, 1) == type)) do
      {short_name, _module} -> short_name
      nil -> type
    end
  end
end

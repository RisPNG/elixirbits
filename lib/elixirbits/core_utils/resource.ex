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

  defp normalize_relationship_loads(resource, true) do
    Enum.map(Ash.Resource.Info.relationships(resource), & &1.name)
  end

  defp normalize_relationship_loads(_resource, preload) when preload in [false, nil, []], do: []

  defp normalize_relationship_loads(resource, preload) when is_list(preload) do
    preload
    |> Enum.reduce([], fn load, loads ->
      case normalize_relationship_load(resource, load) do
        nil -> loads
        normalized -> [normalized | loads]
      end
    end)
    |> Enum.reverse()
  end

  defp normalize_relationship_loads(resource, preload) do
    case normalize_relationship_load(resource, preload) do
      nil -> []
      normalized -> [normalized]
    end
  end

  defp convert_type_value(_type, _constraints, value, _user_timezone) when value in ["", nil] do
    nil
  end

  defp convert_type_value({:array, type}, constraints, value, user_timezone)
       when is_list(value) do
    value
    |> Enum.reject(&(&1 in ["", nil, [], -1, "-1"]))
    |> Enum.map(fn item ->
      convert_type_value(type, item_constraints(constraints), item, user_timezone)
    end)
  end

  defp convert_type_value({:array, type}, constraints, value, user_timezone) do
    [convert_type_value(type, item_constraints(constraints), value, user_timezone)]
  end

  defp convert_type_value(type, constraints, value, user_timezone) do
    normalized_type = normalize_type(type)

    cond do
      normalized_type in [:utc_datetime, :utc_datetime_usec] ->
        case Parse.to_datetime(
               value,
               source_timezone: user_timezone,
               target_timezone: "Etc/UTC"
             ) do
          %DateTime{} = datetime -> normalize_datetime_precision(datetime, normalized_type)
          nil -> nil
        end

      normalized_type in [:naive_datetime, :naive_datetime_usec] ->
        Parse.to_naive_datetime(value)

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
        case cast_with_ash(type, constraints, value) do
          {:ok, casted} -> casted
          _ -> if(is_nil(value), do: nil, else: to_string(value))
        end

      normalized_type == :binary ->
        value

      normalized_type == :map ->
        value

      true ->
        case cast_with_ash(type, constraints, value) do
          {:ok, casted} ->
            casted

          _ when normalized_type in [:boolean, :integer, :float, :decimal, :date, :time] ->
            nil

          _ ->
            value
        end
    end
  end

  defp cast_with_ash(type, constraints, value) do
    Ash.Type.cast_input(type, value, constraints || [])
  end

  defp normalize_datetime_precision(%DateTime{} = value, :utc_datetime_usec), do: value

  defp normalize_datetime_precision(%DateTime{} = value, _type) do
    %{value | microsecond: {0, 0}}
  end

  defp normalize_relationship_load(resource, {relationship, nested}) do
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

  defp normalize_relationship_load(resource, relationship) do
    case Ash.Resource.Info.relationship(resource, relationship) do
      nil -> nil
      relationship_info -> relationship_info.name
    end
  end

  defp item_constraints(constraints) do
    Keyword.get(constraints || [], :items, [])
  end

  defp normalize_type({:array, type}), do: {:array, normalize_type(type)}

  defp normalize_type(type) do
    case Enum.find(Ash.Type.short_names(), &(elem(&1, 1) == type)) do
      {short_name, _module} -> short_name
      nil -> type
    end
  end
end

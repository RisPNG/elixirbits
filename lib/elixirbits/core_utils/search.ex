defmodule Elixirbits.CoreUtils.Search do
  @moduledoc false

  require Ash.Expr
  require Ash.Query

  alias Elixirbits.CoreUtils.Resource

  @sensitive_fields [
    :hashed_password,
    :password,
    :current_password,
    :password_confirmation
  ]

  @exact_types [
    :integer,
    :float,
    :decimal,
    :date,
    :time,
    :utc_datetime,
    :utc_datetime_usec,
    :naive_datetime,
    :naive_datetime_usec,
    :boolean,
    :uuid,
    :uuid_v7,
    :atom
  ]

  @list_keywords ~w(range not_range after after_equal before before_equal
                    and or exact exact_and exact_or exact_not not not_empty empty)

  @temporal_keywords ~w(after after_equal before before_equal)

  @fields_ops [:_fields_diff, :_fields_sum]

  @fields_comparators ~w(after after_equal before before_equal equal range)

  @type search_opts :: [
          resource: module(),
          args: map(),
          pagination: %{optional(:page) => pos_integer(), optional(:per_page) => pos_integer()},
          use_or: boolean(),
          drop_args: [atom()],
          order_by:
            atom()
            | {atom(), :asc | :desc}
            | [atom() | {atom(), :asc | :desc}],
          order_method: :asc | :desc,
          load: boolean() | list(),
          distinct: boolean(),
          user_timezone: String.t(),
          actor: term(),
          tenant: term(),
          action: atom() | nil,
          authorize?: boolean()
        ]

  @type search_result :: %{
          entries: [Ash.Resource.record()],
          page_number: pos_integer(),
          page_size: non_neg_integer(),
          total_entries: non_neg_integer(),
          total_pages: pos_integer()
        }

  @spec search(search_opts()) :: search_result()
  def search(opts) do
    resource = Keyword.fetch!(opts, :resource)
    args = Keyword.get(opts, :args, %{})
    pagination = Keyword.get(opts, :pagination, %{})
    use_or = Keyword.get(opts, :use_or, false)
    drop_args = Keyword.get(opts, :drop_args, [])
    order_by = Keyword.get(opts, :order_by, :id)
    order_method = Keyword.get(opts, :order_method, :asc)
    load = Keyword.get(opts, :load, [])
    distinct = Keyword.get(opts, :distinct, false)
    user_timezone = Keyword.get(opts, :user_timezone, "Etc/UTC")
    action = Keyword.get(opts, :action)

    read_opts =
      [
        actor: Keyword.get(opts, :actor),
        tenant: Keyword.get(opts, :tenant),
        authorize?: Keyword.get(opts, :authorize?)
      ]
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)

    ctx = %{resource: resource, user_timezone: user_timezone, use_or: use_or}

    cleaned_args =
      args
      |> Map.drop(@sensitive_fields ++ drop_args)
      |> parse_association_keys()

    {or_filters, remaining} = Map.pop(cleaned_args, :_or)
    {multi_or_filters, remaining} = Map.pop(remaining, :_multi_or)

    base_query =
      if action do
        Ash.Query.for_read(resource, action)
      else
        Ash.Query.new(resource)
      end

    base_query
    |> apply_main_filters(remaining, ctx)
    |> apply_or_group(or_filters, ctx)
    |> apply_multi_or_groups(multi_or_filters, ctx)
    |> apply_sort(order_by, order_method)
    |> apply_distinct(distinct, resource)
    |> execute(pagination, load, read_opts)
  end

  @spec construct_date_map(
          from_date :: String.t() | nil,
          to_date :: String.t() | nil,
          key :: atom() | String.t()
        ) :: %{optional(atom()) => [String.t()]}
  def construct_date_map(from_date, to_date, key) when is_binary(key) do
    construct_date_map(from_date, to_date, String.to_existing_atom(key))
  end

  def construct_date_map(from_date, to_date, key) when is_atom(key) do
    cond do
      from_date not in ["", nil] and to_date not in ["", nil] ->
        %{key => [from_date, to_date, "range"]}

      from_date not in ["", nil] ->
        %{key => [from_date, "after_equal"]}

      to_date not in ["", nil] ->
        %{key => [to_date, "before_equal"]}

      true ->
        %{key => []}
    end
  end

  defp parse_association_keys(args) do
    Enum.into(args, %{}, fn {key, value} ->
      key_str = to_string(key)

      if String.contains?(key_str, "@") do
        [field, assoc] = String.split(key_str, "@", parts: 2)
        {{String.to_existing_atom(field), String.to_existing_atom(assoc)}, value}
      else
        {key, value}
      end
    end)
  end

  defp apply_main_filters(query, filters, ctx) do
    exprs =
      filters
      |> Enum.map(&build_filter_expr(&1, ctx))
      |> Enum.reject(&is_nil/1)

    combined = combine_exprs(exprs, if(ctx.use_or, do: :or, else: :and))
    if combined, do: Ash.Query.filter(query, ^combined), else: query
  end

  defp apply_or_group(query, nil, _ctx), do: query

  defp apply_or_group(query, or_filters, ctx) do
    parsed = or_filters |> parse_association_keys() |> drop_blank_filters()

    exprs =
      parsed
      |> Enum.map(&build_filter_expr(&1, ctx))
      |> Enum.reject(&is_nil/1)

    combined = combine_exprs(exprs, :or)
    if combined, do: Ash.Query.filter(query, ^combined), else: query
  end

  defp apply_multi_or_groups(query, nil, _ctx), do: query
  defp apply_multi_or_groups(query, [], _ctx), do: query

  defp apply_multi_or_groups(query, groups, ctx) do
    group_exprs =
      groups
      |> Enum.map(fn group ->
        parsed = group |> parse_association_keys() |> drop_blank_filters()

        parsed
        |> Enum.map(&build_filter_expr(&1, ctx))
        |> Enum.reject(&is_nil/1)
        |> combine_exprs(:and)
      end)
      |> Enum.reject(&is_nil/1)

    combined = combine_exprs(group_exprs, :or)
    if combined, do: Ash.Query.filter(query, ^combined), else: query
  end

  defp drop_blank_filters(filters) when is_map(filters) do
    filters
    |> Enum.reject(fn {_k, v} -> non_value?(v) end)
    |> Map.new()
  end

  defp combine_exprs([], _op), do: nil
  defp combine_exprs([single], _op), do: single

  defp combine_exprs([head | tail], :and) do
    Enum.reduce(tail, head, fn e, acc -> Ash.Expr.expr(^acc and ^e) end)
  end

  defp combine_exprs([head | tail], :or) do
    Enum.reduce(tail, head, fn e, acc -> Ash.Expr.expr(^acc or ^e) end)
  end

  defp build_filter_expr({field, value}, ctx) when field in @fields_ops and is_list(value) do
    build_fields_op_expr(field, value, ctx)
  end

  defp build_filter_expr({{field, rel}, value}, ctx) do
    if non_value?(value), do: nil, else: build_field_expr(field, rel, value, ctx)
  end

  defp build_filter_expr({field, value}, ctx) do
    if non_value?(value), do: nil, else: build_field_expr(field, nil, value, ctx)
  end

  defp build_field_expr(field, rel, value, ctx) do
    target = target_resource(ctx.resource, rel)

    cond do
      is_list(value) and array_type?(target, field) ->
        build_array_list_expr(field, rel, value, ctx)

      is_list(value) ->
        build_scalar_list_expr(field, rel, value, target, ctx)

      array_type?(target, field) ->
        build_array_single_expr(field, rel, value, ctx)

      true ->
        build_single_scalar_expr(field, rel, value, target, ctx)
    end
  end

  defp build_single_scalar_expr(field, rel, value, resource, ctx) do
    r = field_ref(rel, field)

    if exact_type?(resource, field) do
      converted = Resource.convert_value_to_field(resource, field, value, ctx.user_timezone)
      Ash.Expr.expr(^r == ^converted)
    else
      Ash.Expr.expr(contains(^r, ^to_string(value)))
    end
  end

  defp build_array_single_expr(field, rel, value, ctx) do
    r = field_ref(rel, field)
    arr = List.wrap(value)

    if ctx.use_or do
      Ash.Expr.expr(fragment("? && ?", ^r, ^arr))
    else
      Ash.Expr.expr(fragment("? @> ?", ^r, ^arr))
    end
  end

  defp build_array_list_expr(field, rel, value, ctx) do
    {keyword, values} = extract_list_keyword(value)
    arr_values = Enum.reject(values, &non_value?/1)

    if arr_values == [] do
      nil
    else
      r = field_ref(rel, field)

      if keyword == "or" or ctx.use_or do
        Ash.Expr.expr(fragment("? && ?", ^r, ^arr_values))
      else
        Ash.Expr.expr(fragment("? @> ?", ^r, ^arr_values))
      end
    end
  end

  defp build_scalar_list_expr(field, rel, value, resource, ctx) do
    {keyword, values} = extract_list_keyword(value)
    filtered = Enum.reject(values, &non_value?/1)

    cond do
      keyword in ["empty", "not_empty"] ->
        build_emptiness_expr(keyword, field, rel, resource)

      filtered == [] ->
        nil

      true ->
        apply_list_keyword(keyword, field, rel, values, resource, ctx)
    end
  end

  defp extract_list_keyword(value) do
    last = List.last(value)

    if is_binary(last) and last in @list_keywords do
      {last, Enum.drop(value, -1)}
    else
      {nil, value}
    end
  end

  defp apply_list_keyword("range", field, rel, values, resource, ctx),
    do: build_range_expr(field, rel, values, resource, ctx, false)

  defp apply_list_keyword("not_range", field, rel, values, resource, ctx),
    do: build_range_expr(field, rel, values, resource, ctx, true)

  defp apply_list_keyword(keyword, field, rel, values, resource, ctx)
       when keyword in @temporal_keywords,
       do: build_temporal_expr(keyword, field, rel, values, resource, ctx)

  defp apply_list_keyword("exact", field, rel, values, resource, ctx),
    do: build_exact_single_expr(field, rel, values, resource, ctx)

  defp apply_list_keyword(keyword, field, rel, values, resource, ctx)
       when keyword in ["exact_or", "or"] do
    match_type = match_type_for(keyword, resource, field)
    build_multi_match(:or, match_type, field, rel, values, resource, ctx)
  end

  defp apply_list_keyword(keyword, field, rel, values, resource, ctx)
       when keyword in ["exact_and", "and", nil] do
    match_type = match_type_for(keyword, resource, field)
    build_multi_match(:and, match_type, field, rel, values, resource, ctx)
  end

  defp apply_list_keyword("exact_not", field, rel, values, resource, ctx),
    do: build_not_match(:exact, field, rel, values, resource, ctx)

  defp apply_list_keyword("not", field, rel, values, resource, ctx) do
    match_type = if exact_type?(resource, field), do: :exact, else: :ilike
    build_not_match(match_type, field, rel, values, resource, ctx)
  end

  defp match_type_for("exact_" <> _, _resource, _field), do: :exact

  defp match_type_for(_, resource, field) do
    if exact_type?(resource, field), do: :exact, else: :ilike
  end

  defp build_range_expr(field, rel, values, resource, ctx, negate?) do
    case values do
      [v1, v2] ->
        r = field_ref(rel, field)
        low = Resource.convert_value_to_field(resource, field, v1, ctx.user_timezone)
        high = handle_datetime_range_end(resource, field, v2, ctx.user_timezone)

        if negate? do
          Ash.Expr.expr(^r < ^low or ^r > ^high)
        else
          Ash.Expr.expr(^r >= ^low and ^r <= ^high)
        end

      _ ->
        nil
    end
  end

  defp build_temporal_expr(keyword, field, rel, values, resource, ctx) do
    case values do
      [v] ->
        r = field_ref(rel, field)

        converted =
          if keyword in ["before", "before_equal"] do
            handle_datetime_range_end(resource, field, v, ctx.user_timezone)
          else
            Resource.convert_value_to_field(resource, field, v, ctx.user_timezone)
          end

        case keyword do
          "after" -> Ash.Expr.expr(^r > ^converted)
          "after_equal" -> Ash.Expr.expr(^r >= ^converted)
          "before" -> Ash.Expr.expr(^r < ^converted)
          "before_equal" -> Ash.Expr.expr(^r <= ^converted)
        end

      _ ->
        nil
    end
  end

  defp build_exact_single_expr(field, rel, values, resource, ctx) do
    case values do
      [nil] ->
        r = field_ref(rel, field)
        Ash.Expr.expr(is_nil(^r))

      [v] ->
        r = field_ref(rel, field)
        converted = Resource.convert_value_to_field(resource, field, v, ctx.user_timezone)
        Ash.Expr.expr(^r == ^converted)

      _ ->
        nil
    end
  end

  defp build_multi_match(combinator, match_type, field, rel, values, resource, ctx) do
    r = field_ref(rel, field)

    conditions =
      values
      |> Enum.reject(&is_nil/1)
      |> Enum.map(fn v ->
        case match_type do
          :exact ->
            converted = Resource.convert_value_to_field(resource, field, v, ctx.user_timezone)
            Ash.Expr.expr(^r == ^converted)

          :ilike ->
            Ash.Expr.expr(contains(^r, ^to_string(v)))
        end
      end)

    combine_exprs(conditions, combinator)
  end

  defp build_not_match(:exact, field, rel, values, resource, ctx) do
    r = field_ref(rel, field)

    converted =
      Enum.map(values, &Resource.convert_value_to_field(resource, field, &1, ctx.user_timezone))

    has_nil? = Enum.any?(converted, &is_nil/1)
    non_nils = converted |> Enum.reject(&is_nil/1) |> Enum.uniq()

    cond do
      has_nil? and non_nils == [] ->
        Ash.Expr.expr(not is_nil(^r))

      has_nil? ->
        Ash.Expr.expr(not is_nil(^r) and ^r not in ^non_nils)

      non_nils != [] ->
        Ash.Expr.expr(^r not in ^non_nils)

      true ->
        nil
    end
  end

  defp build_not_match(:ilike, field, rel, values, _resource, _ctx) do
    r = field_ref(rel, field)

    {conds, has_nil?} =
      Enum.reduce(values, {[], false}, fn
        nil, {acc, _} -> {acc, true}
        v, {acc, nil_flag} -> {[Ash.Expr.expr(not contains(^r, ^to_string(v))) | acc], nil_flag}
      end)

    base = combine_exprs(Enum.reverse(conds), :and)

    cond do
      base && has_nil? -> Ash.Expr.expr(^base and not is_nil(^r))
      base -> base
      has_nil? -> Ash.Expr.expr(not is_nil(^r))
      true -> nil
    end
  end

  defp build_emptiness_expr("empty", field, rel, resource) do
    r = field_ref(rel, field)

    if array_type?(resource, field) do
      Ash.Expr.expr(is_nil(^r) or fragment("cardinality(?) = 0", ^r))
    else
      if exact_type?(resource, field) do
        Ash.Expr.expr(is_nil(^r))
      else
        Ash.Expr.expr(is_nil(^r) or ^r == "")
      end
    end
  end

  defp build_emptiness_expr("not_empty", field, rel, resource) do
    r = field_ref(rel, field)

    if array_type?(resource, field) do
      Ash.Expr.expr(not is_nil(^r) and fragment("cardinality(?) > 0", ^r))
    else
      if exact_type?(resource, field) do
        Ash.Expr.expr(not is_nil(^r))
      else
        Ash.Expr.expr(not is_nil(^r) and ^r != "")
      end
    end
  end

  defp build_fields_op_expr(op, value, ctx) do
    last = List.last(value)
    has_comp? = is_binary(last) and last in @fields_comparators

    {comparator, raw_vals} =
      if has_comp?, do: {last, Enum.drop(value, -1)}, else: {"equal", value}

    {field_atoms, thresholds} = Enum.split_while(raw_vals, &is_atom/1)

    valid? =
      case op do
        :_fields_diff -> length(field_atoms) >= 2
        :_fields_sum -> field_atoms != []
      end

    if not valid? do
      nil
    else
      first_field = hd(field_atoms)
      convert = &Resource.convert_value_to_field(ctx.resource, first_field, &1, ctx.user_timezone)

      fields_expr =
        case op do
          :_fields_diff ->
            [a, b | _] = field_atoms
            ra = field_ref(nil, a)
            rb = field_ref(nil, b)
            Ash.Expr.expr(^ra - ^rb)

          :_fields_sum ->
            field_atoms
            |> Enum.map(&field_ref(nil, &1))
            |> Enum.reduce(fn r, acc -> Ash.Expr.expr(^acc + ^r) end)
        end

      build_fields_comparison(fields_expr, comparator, thresholds, convert)
    end
  end

  defp build_fields_comparison(expr, "range", thresholds, convert) when length(thresholds) >= 2 do
    low = convert.(Enum.at(thresholds, 0))
    high = convert.(Enum.at(thresholds, 1))
    Ash.Expr.expr(^expr >= ^low and ^expr <= ^high)
  end

  defp build_fields_comparison(expr, comparator, thresholds, convert) do
    th = convert.(List.first(thresholds) || 0)

    case comparator do
      "after" -> Ash.Expr.expr(^expr > ^th)
      "after_equal" -> Ash.Expr.expr(^expr >= ^th)
      "before" -> Ash.Expr.expr(^expr < ^th)
      "before_equal" -> Ash.Expr.expr(^expr <= ^th)
      _ -> Ash.Expr.expr(^expr == ^th)
    end
  end

  defp apply_sort(query, order_by, order_method) do
    segments =
      order_by
      |> normalize_order_by(order_method)
      |> Enum.map_join(",", &sort_segment/1)

    if segments == "", do: query, else: Ash.Query.sort_input(query, segments)
  end

  defp normalize_order_by(field, default) when is_atom(field), do: [{field, default}]

  defp normalize_order_by({field, method}, _default)
       when is_atom(field) and method in [:asc, :desc],
       do: [{field, method}]

  defp normalize_order_by(list, default) when is_list(list) do
    Enum.map(list, fn
      field when is_atom(field) -> {field, default}
      {field, method} when is_atom(field) and method in [:asc, :desc] -> {field, method}
      _ -> {:id, default}
    end)
  end

  defp normalize_order_by(_, default), do: [{:id, default}]

  defp sort_segment({field, method}) do
    prefix = if method == :desc, do: "-", else: ""
    str = to_string(field)

    path =
      if String.contains?(str, "@") do
        [f, r] = String.split(str, "@", parts: 2)
        "#{r}.#{f}"
      else
        str
      end

    prefix <> path
  end

  defp apply_distinct(query, false, _resource), do: query

  defp apply_distinct(query, true, resource) do
    Ash.Query.distinct(query, Ash.Resource.Info.primary_key(resource))
  end

  defp execute(query, %{page: page, per_page: per_page}, load, read_opts)
       when is_integer(page) and is_integer(per_page) do
    total = Ash.count!(query, read_opts)

    entries =
      query
      |> Ash.Query.limit(per_page)
      |> Ash.Query.offset((page - 1) * per_page)
      |> Ash.read!(read_opts)
      |> Resource.ensure_loaded_associations(load)

    %{
      entries: entries,
      page_number: page,
      page_size: per_page,
      total_entries: total,
      total_pages: max(ceil(total / per_page), 1)
    }
  end

  defp execute(query, _pagination, load, read_opts) do
    entries =
      query
      |> Ash.read!(read_opts)
      |> Resource.ensure_loaded_associations(load)

    total = length(entries)

    %{
      entries: entries,
      page_number: 1,
      page_size: total,
      total_entries: total,
      total_pages: 1
    }
  end

  defp field_ref(nil, field), do: Ash.Expr.ref(field)
  defp field_ref(rel, field) when is_atom(rel), do: Ash.Expr.ref([rel], field)

  defp target_resource(base, nil), do: base

  defp target_resource(base, rel) do
    case Ash.Resource.Info.relationship(base, rel) do
      nil ->
        raise ArgumentError,
              "Relationship #{inspect(rel)} not found on #{inspect(base)}"

      r ->
        r.destination
    end
  end

  defp non_value?(nil), do: true
  defp non_value?(""), do: true
  defp non_value?([]), do: true
  defp non_value?(-1), do: true
  defp non_value?("-1"), do: true
  defp non_value?(list) when is_list(list), do: Enum.all?(list, &non_value?/1)
  defp non_value?(_), do: false

  defp exact_type?(resource, field) do
    case Resource.detect_schema_field?(resource, field) do
      type when type in @exact_types ->
        true

      type when is_atom(type) and not is_nil(type) ->
        Code.ensure_loaded?(type) and function_exported?(type, :values, 0)

      _ ->
        false
    end
  end

  defp array_type?(resource, field) do
    match?({:array, _}, Resource.detect_schema_field?(resource, field))
  end

  defp handle_datetime_range_end(resource, field, value, tz) do
    converted = Resource.convert_value_to_field(resource, field, value, tz)

    case {Resource.detect_schema_field?(resource, field), converted} do
      {:utc_datetime_usec, %DateTime{} = dt} ->
        %{dt | second: 59, microsecond: {999_999, 6}}

      {:utc_datetime, %DateTime{} = dt} ->
        %{dt | second: 59, microsecond: {0, 0}}

      {:naive_datetime_usec, %NaiveDateTime{} = ndt} ->
        %{ndt | second: 59, microsecond: {999_999, 6}}

      {:naive_datetime, %NaiveDateTime{} = ndt} ->
        %{ndt | second: 59, microsecond: {0, 0}}

      _ ->
        converted
    end
  end
end

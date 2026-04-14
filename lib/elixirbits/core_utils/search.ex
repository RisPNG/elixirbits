defmodule Elixirbits.CoreUtils.Search do
  alias Ash.Filter
  alias Ash.Page.Keyset
  alias Ash.Page.Offset
  alias Ash.Query
  alias Ash.Query.BooleanExpression
  alias Ash.Query.Not
  alias Ash.Query.Operator.Basic.Minus
  alias Ash.Query.Operator.Basic.Plus
  alias Ash.Query.Operator.Eq
  alias Ash.Query.Operator.GreaterThan
  alias Ash.Query.Operator.GreaterThanOrEqual
  alias Ash.Query.Operator.LessThan
  alias Ash.Query.Operator.LessThanOrEqual
  alias Ash.Query.Ref
  alias Elixirbits.CoreUtils.Resource

  @sensitive_fields [
    "hashed_password",
    "password",
    "current_password",
    "password_confirmation"
  ]

  @list_keywords ~w(
    range
    not_range
    after
    after_equal
    before
    before_equal
    and
    or
    exact
    exact_and
    exact_or
    exact_not
    not
    not_empty
    empty
  )

  @temporal_keywords ~w(after after_equal before before_equal)
  @comparison_keywords ~w(after after_equal before before_equal equal range)
  @text_types [:string, :ci_string]

  def search(opts) do
    resource = Keyword.fetch!(opts, :module)
    args = opts |> Keyword.get(:args, %{}) |> normalize_map()
    pagination = opts |> Keyword.get(:pagination, %{}) |> normalize_map()
    drop_args = Keyword.get(opts, :drop_args, [])
    user_timezone = Keyword.get(opts, :user_timezone, "Etc/UTC")
    use_or = Keyword.get(opts, :use_or, false)
    preload = Keyword.get(opts, :preload, Keyword.get(opts, :load, []))
    order_by = Keyword.get(opts, :order_by, primary_sort_field(resource))
    order_method = Keyword.get(opts, :order_method, :asc)
    distinct = Keyword.get(opts, :distinct, false)
    action = Keyword.get(opts, :action, primary_read_action_name(resource))

    query =
      resource
      |> Query.for_read(
        action,
        %{},
        actor: Keyword.get(opts, :actor),
        authorize?: Keyword.get(opts, :authorize?, true),
        tenant: Keyword.get(opts, :tenant),
        domain: Keyword.get(opts, :domain),
        context: Keyword.get(opts, :context, %{})
      )
      |> apply_regular_filters(clean_args(args, drop_args), user_timezone, use_or)
      |> apply_or_filters(args, user_timezone)
      |> apply_multi_or_filters(args, user_timezone)
      |> apply_sort(resource, order_by, order_method)
      |> apply_distinct(resource, distinct)
      |> apply_load(resource, preload)

    execute_query(query, pagination)
  end

  def construct_date_map(from_date, to_date, key) when is_binary(key) or is_atom(key) do
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

  def construct_date_list(from_date, to_date) do
    cond do
      from_date not in ["", nil] and to_date not in ["", nil] ->
        [from_date, to_date, "range"]

      from_date not in ["", nil] ->
        [from_date, "after_equal"]

      to_date not in ["", nil] ->
        [to_date, "before_equal"]

      true ->
        []
    end
  end

  defp clean_args(args, drop_args) do
    drop_fields =
      @sensitive_fields ++ Enum.map(List.wrap(drop_args), &to_string/1)

    Map.reject(args, fn {key, _value} ->
      to_string(key) in drop_fields
    end)
  end

  defp apply_regular_filters(query, args, user_timezone, use_or) do
    {or_filters, remaining_args} = take_named_key(args, "_or")
    {multi_or_filters, remaining_args} = take_named_key(remaining_args, "_multi_or")

    query =
      case combine_filter_expressions(
             query.resource,
             remaining_args,
             user_timezone,
             if(use_or, do: :or, else: :and)
           ) do
        nil ->
          query

        expression ->
          Query.do_filter(query, %Filter{resource: query.resource, expression: expression})
      end

    query
    |> put_named_context("_or", or_filters)
    |> put_named_context("_multi_or", multi_or_filters)
  end

  defp apply_or_filters(query, args, user_timezone) do
    search_utils_context = Map.get(query.context, :search_utils, %{})

    case take_named_key(args, "_or") do
      {nil, _remaining} ->
        case search_utils_context["_or"] do
          nil ->
            query

          filters ->
            apply_expression_filter(
              query,
              combine_filter_expressions(query.resource, filters, user_timezone, :or)
            )
        end

      {filters, _remaining} ->
        apply_expression_filter(
          query,
          combine_filter_expressions(query.resource, filters, user_timezone, :or)
        )
    end
  end

  defp apply_multi_or_filters(query, args, user_timezone) do
    search_utils_context = Map.get(query.context, :search_utils, %{})

    groups =
      case take_named_key(args, "_multi_or") do
        {nil, _remaining} -> search_utils_context["_multi_or"]
        {value, _remaining} -> value
      end

    expressions =
      groups
      |> List.wrap()
      |> Enum.map(&combine_filter_expressions(query.resource, &1, user_timezone, :and))
      |> Enum.reject(&is_nil/1)

    apply_expression_filter(query, combine_expressions(expressions, :or))
  end

  defp apply_sort(query, resource, order_by, order_method) do
    Query.sort(query, normalize_order_by(resource, order_by, order_method))
  end

  defp apply_distinct(query, _resource, false), do: query

  defp apply_distinct(query, resource, true) do
    Query.distinct(query, Ash.Resource.Info.primary_key(resource))
  end

  defp apply_load(query, resource, preload) do
    loads = normalize_relationship_loads(resource, preload)

    if loads == [] do
      query
    else
      Query.load(query, loads)
    end
  end

  defp execute_query(query, pagination) when is_map(pagination) do
    raw_page = Map.get(pagination, :page, Map.get(pagination, "page"))
    raw_per_page = Map.get(pagination, :per_page, Map.get(pagination, "per_page"))

    page =
      case raw_page do
        value when is_integer(value) ->
          value

        value when is_binary(value) ->
          case Integer.parse(value) do
            {parsed, ""} -> parsed
            _ -> nil
          end

        _ ->
          nil
      end

    per_page =
      case raw_per_page do
        value when is_integer(value) ->
          value

        value when is_binary(value) ->
          case Integer.parse(value) do
            {parsed, ""} -> parsed
            _ -> nil
          end

        _ ->
          nil
      end

    if is_integer(page) and is_integer(per_page) and page > 0 and per_page > 0 do
      query
      |> Query.page(limit: per_page, offset: (page - 1) * per_page, count: true)
      |> Ash.read!()
      |> to_result_map()
    else
      entries = Ash.read!(query)

      %{
        entries: entries,
        page_number: 1,
        page_size: length(entries),
        total_entries: length(entries),
        total_pages: 1
      }
    end
  end

  defp execute_query(query, _pagination) do
    entries = Ash.read!(query)

    %{
      entries: entries,
      page_number: 1,
      page_size: length(entries),
      total_entries: length(entries),
      total_pages: 1
    }
  end

  defp to_result_map(%Offset{} = page) do
    total_pages =
      case {page.count, page.limit} do
        {count, limit} when is_integer(count) and is_integer(limit) and limit > 0 ->
          max(div(count + limit - 1, limit), 1)

        _ ->
          1
      end

    %{
      entries: page.results,
      page_number:
        case page.limit do
          limit when is_integer(limit) and limit > 0 -> div(page.offset, limit) + 1
          _ -> 1
        end,
      page_size: page.limit,
      total_entries: page.count,
      total_pages: total_pages
    }
  end

  defp to_result_map(%Keyset{} = page) do
    total_pages =
      case {page.count, page.limit} do
        {count, limit} when is_integer(count) and is_integer(limit) and limit > 0 ->
          max(div(count + limit - 1, limit), 1)

        _ ->
          1
      end

    %{
      entries: page.results,
      page_number: 1,
      page_size: page.limit,
      total_entries: page.count,
      total_pages: total_pages
    }
  end

  defp apply_expression_filter(query, nil), do: query

  defp apply_expression_filter(query, expression) do
    Query.do_filter(query, %Filter{resource: query.resource, expression: expression})
  end

  defp combine_filter_expressions(resource, filters, user_timezone, combinator) do
    filters
    |> normalize_map()
    |> Enum.reduce([], fn {key, value}, expressions ->
      case build_filter_expression(resource, key, value, user_timezone) do
        nil -> expressions
        expression -> [expression | expressions]
      end
    end)
    |> Enum.reverse()
    |> combine_expressions(combinator)
  end

  defp build_filter_expression(resource, key, value, user_timezone) do
    case to_string(key) do
      "_fields_diff" -> build_field_operation_expression(resource, :diff, value, user_timezone)
      "_fields_sum" -> build_field_operation_expression(resource, :sum, value, user_timezone)
      _ -> build_field_value_expression(resource, parse_field_key(key), value, user_timezone)
    end
  end

  defp build_field_value_expression(_resource, _parsed_key, value, _user_timezone)
       when value in [nil, "", [], -1, "-1"] do
    nil
  end

  defp build_field_value_expression(resource, %{path: path, field: field}, value, user_timezone) do
    path = normalize_relationship_path!(resource, path)
    field_info = field_info!(resource, path, field)
    field = field_info.name

    cond do
      is_list(value) ->
        build_list_expression(resource, path, field, field_info, value, user_timezone)

      array_type?(field_info.type) ->
        build_array_match_expression(
          resource,
          path,
          field,
          field_info,
          [value],
          user_timezone,
          :and
        )

      text_type?(field_info.type) ->
        build_ilike_expression(resource, path, field, value)

      true ->
        build_exact_expression(
          resource,
          path,
          field,
          convert_path_value_to_field(resource, path, field, value, user_timezone)
        )
    end
  end

  defp build_list_expression(resource, path, field, field_info, value, user_timezone) do
    {keyword, raw_values} = extract_list_keyword(value)
    filtered_values = Enum.reject(raw_values, &non_value?/1)

    cond do
      filtered_values == [] and keyword not in ["empty", "not_empty"] ->
        nil

      array_type?(field_info.type) ->
        build_array_expression(
          resource,
          path,
          field,
          field_info,
          keyword,
          raw_values,
          user_timezone
        )

      keyword == "range" ->
        build_range_expression(resource, path, field, raw_values, user_timezone)

      keyword == "not_range" ->
        build_range_expression(resource, path, field, raw_values, user_timezone)
        |> negate_expression()

      keyword in @temporal_keywords ->
        build_temporal_expression(resource, path, field, keyword, raw_values, user_timezone)

      keyword == "empty" ->
        build_empty_expression(resource, path, field, field_info.type)

      keyword == "not_empty" ->
        resource
        |> build_empty_expression(path, field, field_info.type)
        |> negate_expression()

      keyword == "exact" ->
        build_exact_keyword_expression(resource, path, field, raw_values, user_timezone)

      keyword == "exact_or" ->
        build_match_expression(resource, path, field, raw_values, user_timezone, :exact, :or)

      keyword == "exact_and" ->
        build_match_expression(resource, path, field, raw_values, user_timezone, :exact, :and)

      keyword == "exact_not" ->
        build_not_expression(resource, path, field, raw_values, user_timezone, :exact)

      keyword == "or" ->
        build_match_expression(
          resource,
          path,
          field,
          raw_values,
          user_timezone,
          field_match_mode(field_info.type),
          :or
        )

      keyword == "and" or is_nil(keyword) ->
        build_match_expression(
          resource,
          path,
          field,
          raw_values,
          user_timezone,
          field_match_mode(field_info.type),
          :and
        )

      keyword == "not" ->
        build_not_expression(
          resource,
          path,
          field,
          raw_values,
          user_timezone,
          field_match_mode(field_info.type)
        )

      true ->
        nil
    end
  end

  defp build_array_expression(resource, path, field, field_info, keyword, values, user_timezone) do
    combinator =
      if keyword == "or" do
        :or
      else
        :and
      end

    build_array_match_expression(
      resource,
      path,
      field,
      field_info,
      values,
      user_timezone,
      combinator
    )
  end

  defp build_array_match_expression(
         resource,
         path,
         field,
         _field_info,
         values,
         user_timezone,
         combinator
       ) do
    values
    |> Enum.reject(&non_value?/1)
    |> Enum.map(fn value ->
      inner_value =
        resource
        |> convert_path_value_to_field(path, field, value, user_timezone)
        |> List.first()

      parse_statement_expression(resource, wrap_path(path, field, has: inner_value))
    end)
    |> combine_expressions(combinator)
  end

  defp build_range_expression(resource, path, field, raw_values, user_timezone) do
    case Enum.reject(raw_values, &non_value?/1) do
      [lower, upper] ->
        lower_expression =
          parse_statement_expression(
            resource,
            wrap_path(
              path,
              field,
              gte: convert_path_value_to_field(resource, path, field, lower, user_timezone)
            )
          )

        upper_expression =
          parse_statement_expression(
            resource,
            wrap_path(
              path,
              field,
              lte: range_end_value(resource, path, field, upper, user_timezone)
            )
          )

        combine_expressions([lower_expression, upper_expression], :and)

      _ ->
        nil
    end
  end

  defp build_temporal_expression(resource, path, field, keyword, raw_values, user_timezone) do
    case Enum.reject(raw_values, &non_value?/1) do
      [value] ->
        operator =
          case keyword do
            "after" -> :gt
            "after_equal" -> :gte
            "before" -> :lt
            "before_equal" -> :lte
          end

        converted_value =
          if keyword in ["before", "before_equal"] do
            range_end_value(resource, path, field, value, user_timezone)
          else
            convert_path_value_to_field(resource, path, field, value, user_timezone)
          end

        parse_statement_expression(
          resource,
          wrap_path(path, field, [{operator, converted_value}])
        )

      _ ->
        nil
    end
  end

  defp build_match_expression(resource, path, field, raw_values, user_timezone, mode, combinator) do
    raw_values
    |> Enum.reduce([], fn value, expressions ->
      case build_value_expression_for_mode(resource, path, field, value, user_timezone, mode) do
        nil -> expressions
        expression -> [expression | expressions]
      end
    end)
    |> Enum.reverse()
    |> combine_expressions(combinator)
  end

  defp build_not_expression(resource, path, field, raw_values, user_timezone, mode) do
    resource
    |> build_match_expression(path, field, raw_values, user_timezone, mode, :or)
    |> negate_expression()
  end

  defp build_value_expression_for_mode(_resource, _path, _field, value, _user_timezone, _mode)
       when value in ["", -1, "-1"] do
    nil
  end

  defp build_value_expression_for_mode(resource, path, field, nil, _user_timezone, _mode) do
    build_exact_expression(resource, path, field, nil)
  end

  defp build_value_expression_for_mode(resource, path, field, value, user_timezone, :exact) do
    build_exact_expression(
      resource,
      path,
      field,
      convert_path_value_to_field(resource, path, field, value, user_timezone)
    )
  end

  defp build_value_expression_for_mode(resource, path, field, value, _user_timezone, :fuzzy) do
    build_ilike_expression(resource, path, field, value)
  end

  defp build_ilike_expression(resource, path, field, value) do
    parse_statement_expression(resource, wrap_path(path, field, ilike: "%#{value}%"))
  end

  defp build_exact_expression(resource, path, field, value) do
    parse_statement_expression(resource, wrap_path(path, field, value))
  end

  defp build_exact_keyword_expression(resource, path, field, raw_values, user_timezone) do
    case raw_values do
      [value] ->
        build_exact_expression(
          resource,
          path,
          field,
          convert_path_value_to_field(resource, path, field, value, user_timezone)
        )

      _ ->
        nil
    end
  end

  defp build_empty_expression(resource, path, field, type) do
    expressions =
      if text_type?(type) do
        [
          build_exact_expression(resource, path, field, nil),
          build_exact_expression(resource, path, field, "")
        ]
      else
        [build_exact_expression(resource, path, field, nil)]
      end

    combine_expressions(expressions, :or)
  end

  defp build_field_operation_expression(resource, operation, value, user_timezone)
       when is_list(value) do
    {comparison, raw_values} =
      case List.last(value) do
        keyword when is_binary(keyword) and keyword in @comparison_keywords ->
          {keyword, Enum.drop(value, -1)}

        _ ->
          {"equal", value}
      end

    {raw_fields, thresholds} =
      Enum.split_while(raw_values, fn item ->
        is_atom(item) or
          (is_binary(item) and not is_nil(Resource.detect_schema_field?(resource, item)))
      end)

    fields =
      Enum.map(raw_fields, fn field ->
        field_info!(resource, [], field).name
      end)

    cond do
      operation == :diff and length(fields) < 2 ->
        nil

      operation == :sum and fields == [] ->
        nil

      true ->
        arithmetic_expression = build_arithmetic_expression(resource, operation, fields)

        if is_nil(arithmetic_expression) do
          nil
        else
          build_arithmetic_comparison_expression(
            resource,
            fields,
            arithmetic_expression,
            comparison,
            thresholds,
            user_timezone
          )
        end
    end
  end

  defp build_field_operation_expression(_resource, _operation, _value, _user_timezone), do: nil

  defp build_arithmetic_expression(resource, :diff, [left, right | _rest]) do
    {:ok, expression} =
      Minus.new(
        %Ref{attribute: left, relationship_path: [], resource: resource},
        %Ref{attribute: right, relationship_path: [], resource: resource}
      )

    expression
  end

  defp build_arithmetic_expression(resource, :sum, [field | fields]) do
    Enum.reduce(
      fields,
      %Ref{attribute: field, relationship_path: [], resource: resource},
      fn next_field, expression ->
        {:ok, new_expression} =
          Plus.new(
            expression,
            %Ref{attribute: next_field, relationship_path: [], resource: resource}
          )

        new_expression
      end
    )
  end

  defp build_arithmetic_comparison_expression(
         resource,
         [field | _rest],
         expression,
         comparison,
         thresholds,
         user_timezone
       ) do
    case {comparison, Enum.reject(thresholds, &non_value?/1)} do
      {"range", [lower, upper]} ->
        lower_expression =
          new_operator_expression(
            GreaterThanOrEqual,
            expression,
            convert_path_value_to_field(resource, [], field, lower, user_timezone)
          )

        upper_expression =
          new_operator_expression(
            LessThanOrEqual,
            expression,
            range_end_value(resource, [], field, upper, user_timezone)
          )

        combine_expressions([lower_expression, upper_expression], :and)

      {"after", [value]} ->
        new_operator_expression(
          GreaterThan,
          expression,
          convert_path_value_to_field(resource, [], field, value, user_timezone)
        )

      {"after_equal", [value]} ->
        new_operator_expression(
          GreaterThanOrEqual,
          expression,
          convert_path_value_to_field(resource, [], field, value, user_timezone)
        )

      {"before", [value]} ->
        new_operator_expression(
          LessThan,
          expression,
          convert_path_value_to_field(resource, [], field, value, user_timezone)
        )

      {"before_equal", [value]} ->
        new_operator_expression(
          LessThanOrEqual,
          expression,
          convert_path_value_to_field(resource, [], field, value, user_timezone)
        )

      {"equal", [value]} ->
        new_operator_expression(
          Eq,
          expression,
          convert_path_value_to_field(resource, [], field, value, user_timezone)
        )

      _ ->
        nil
    end
  end

  defp combine_expressions([], _combinator), do: nil
  defp combine_expressions([expression], _combinator), do: expression

  defp combine_expressions([expression | expressions], combinator) do
    Enum.reduce(expressions, expression, fn next_expression, combined ->
      BooleanExpression.optimized_new(combinator, combined, next_expression)
    end)
  end

  defp negate_expression(nil), do: nil
  defp negate_expression(expression), do: Not.new(expression)

  defp new_operator_expression(module, left, right) do
    {:ok, expression} = module.new(left, right)
    expression
  end

  defp wrap_path(path, field, predicate) do
    statement = [{to_string(field), predicate}]

    Enum.reduce(Enum.reverse(path), statement, fn segment, acc ->
      [{segment, acc}]
    end)
  end

  defp parse_statement_expression(resource, statement) do
    resource
    |> Filter.parse!(statement)
    |> Map.fetch!(:expression)
  end

  defp parse_field_key(key) do
    key_string = to_string(key)

    if String.contains?(key_string, "@") do
      [field, path] = String.split(key_string, "@", parts: 2)
      %{field: field, path: String.split(path, ".", trim: true)}
    else
      %{field: key_string, path: []}
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

  defp normalize_relationship_path!(resource, path) do
    normalize_relationship_path(resource, path, [])
  end

  defp normalize_relationship_path(_resource, [], normalized_path),
    do: Enum.reverse(normalized_path)

  defp normalize_relationship_path(resource, [relationship | rest], normalized_path) do
    relationship_info = relationship_info!(resource, relationship)

    normalize_relationship_path(
      relationship_info.destination,
      rest,
      [relationship_info.name | normalized_path]
    )
  end

  defp field_info!(resource, path, field) do
    target_resource = related_resource!(resource, path)

    case Ash.Resource.Info.field(target_resource, field) do
      nil ->
        raise "Field #{inspect(field)} not found on resource #{inspect(target_resource)}"

      field_info ->
        field_info
    end
  end

  defp related_resource!(resource, []), do: resource

  defp related_resource!(resource, [relationship | rest]) do
    resource
    |> relationship_info!(relationship)
    |> Map.fetch!(:destination)
    |> related_resource!(rest)
  end

  defp relationship_info!(resource, relationship) do
    case Ash.Resource.Info.relationship(resource, relationship) do
      nil ->
        raise "Relationship #{inspect(relationship)} not found on resource #{inspect(resource)}"

      relationship_info ->
        relationship_info
    end
  end

  defp convert_path_value_to_field(resource, path, field, value, user_timezone) do
    target_resource = related_resource!(resource, path)
    Resource.convert_value_to_field(target_resource, field, value, user_timezone)
  end

  defp range_end_value(resource, path, field, value, user_timezone) do
    field_info = field_info!(resource, path, field)

    converted_value = convert_path_value_to_field(resource, path, field, value, user_timezone)
    normalized_type = normalize_type(field_info.type)

    cond do
      normalized_type in [:utc_datetime, :utc_datetime_usec] and date_only?(value) and
          not is_nil(converted_value) ->
        converted_value
        |> DateTime.add(86_399, :second)
        |> normalize_datetime_precision(normalized_type)

      normalized_type in [:naive_datetime, :naive_datetime_usec] and date_only?(value) and
          not is_nil(converted_value) ->
        NaiveDateTime.add(converted_value, 86_399, :second)

      true ->
        converted_value
    end
  end

  defp normalize_datetime_precision(%DateTime{} = value, :utc_datetime_usec), do: value

  defp normalize_datetime_precision(%DateTime{} = value, _type) do
    %{value | microsecond: {0, 0}}
  end

  defp normalize_type({:array, type}), do: {:array, normalize_type(type)}

  defp normalize_type(type) do
    case Enum.find(Ash.Type.short_names(), &(elem(&1, 1) == type)) do
      {short_name, _module} -> short_name
      nil -> type
    end
  end

  defp date_only?(%Date{}), do: true
  defp date_only?(value) when is_binary(value), do: date_only_string?(value)
  defp date_only?(_value), do: false

  defp date_only_string?(value) do
    String.match?(value, ~r/^\d{4}-\d{2}-\d{2}$/)
  end

  defp normalize_order_by(resource, order_by, default_method) do
    case order_by do
      field when is_atom(field) or is_binary(field) ->
        [normalize_order_entry(resource, field, default_method)]

      {field, method} when (is_atom(field) or is_binary(field)) and method in [:asc, :desc] ->
        [normalize_order_entry(resource, field, method)]

      fields when is_list(fields) ->
        Enum.map(fields, fn
          field when is_atom(field) or is_binary(field) ->
            normalize_order_entry(resource, field, default_method)

          {field, method} when (is_atom(field) or is_binary(field)) and method in [:asc, :desc] ->
            normalize_order_entry(resource, field, method)

          _ ->
            normalize_order_entry(resource, primary_sort_field(resource), default_method)
        end)

      _ ->
        [normalize_order_entry(resource, primary_sort_field(resource), default_method)]
    end
  end

  defp normalize_order_entry(resource, field, method) do
    translated =
      field
      |> to_string()
      |> String.replace("@", ".")

    case Ash.Sort.parse_sort(resource, {translated, method}, nil, false) do
      {:ok, _sort} ->
        {translated, method}

      _ ->
        {primary_sort_field(resource), method}
    end
  end

  defp take_named_key(map, key_name) do
    case Enum.find(Map.keys(map), &(to_string(&1) == key_name)) do
      nil -> {nil, map}
      key -> Map.pop(map, key)
    end
  end

  defp put_named_context(query, _key, nil), do: query

  defp put_named_context(query, key, value) do
    search_utils_context = Map.get(query.context, :search_utils, %{})
    Query.set_context(query, %{search_utils: Map.put(search_utils_context, key, value)})
  end

  defp normalize_map(value) when is_map(value), do: value
  defp normalize_map(value) when is_list(value), do: Enum.into(value, %{})
  defp normalize_map(_value), do: %{}

  defp non_value?(value) do
    case value do
      nil -> true
      "" -> true
      [] -> true
      -1 -> true
      "-1" -> true
      list when is_list(list) -> Enum.all?(list, &non_value?/1)
      _ -> false
    end
  end

  defp extract_list_keyword(value) do
    case List.last(value) do
      keyword when is_binary(keyword) and keyword in @list_keywords ->
        {keyword, Enum.drop(value, -1)}

      _ ->
        {nil, value}
    end
  end

  defp array_type?({:array, _type}), do: true
  defp array_type?(_type), do: false

  defp text_type?(type), do: normalize_type(type) in @text_types

  defp field_match_mode(type) do
    if text_type?(type), do: :fuzzy, else: :exact
  end

  defp primary_read_action_name(resource) do
    case Ash.Resource.Info.primary_action(resource, :read) do
      nil -> raise "No primary read action found for #{inspect(resource)}"
      action -> action.name
    end
  end

  defp primary_sort_field(resource) do
    resource
    |> Ash.Resource.Info.primary_key()
    |> List.first()
    |> Kernel.||(:id)
  end
end

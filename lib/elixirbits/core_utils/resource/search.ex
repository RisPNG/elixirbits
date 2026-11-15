defmodule Elixirbits.CoreUtils.Resource.Search do
  def filter(options, text, opts \\ []) do
    if text in ["", nil] or String.trim(to_string(text)) == "" do
      options
    else
      exact = Keyword.get(opts, :exact, false)
      case_sensitive = Keyword.get(opts, :case_sensitive, false)

      needle =
        text
        |> to_string()
        |> then(fn value -> if case_sensitive, do: value, else: String.downcase(value) end)
        |> then(fn value -> if exact, do: value, else: String.replace(value, ~r/\s+/, "") end)

      Enum.filter(options, fn {label, _value} ->
        haystack =
          label
          |> to_string()
          |> then(fn value -> if case_sensitive, do: value, else: String.downcase(value) end)
          |> then(fn value -> if exact, do: value, else: String.replace(value, ~r/\s+/, "") end)

        if exact, do: haystack == needle, else: String.contains?(haystack, needle)
      end)
    end
  end

  # Date filters

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
end

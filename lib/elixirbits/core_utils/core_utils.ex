defmodule Elixirbits.CoreUtils do
  @moduledoc false

  def extract_square_bracket_from_string(id, at) do
    ~r/\[([^\]]*)\]/
    |> Regex.scan(id, capture: :all_but_first)
    |> Enum.at(at)
    |> case do
      [value] when value not in ["", nil] -> value
      _ -> nil
    end
  end
end

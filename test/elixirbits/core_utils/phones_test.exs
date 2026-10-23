defmodule Elixirbits.CoreUtils.PhonesTest do
  use ExUnit.Case, async: true

  alias Elixirbits.CoreUtils.Phones

  test "browser dial codes cover the same countries as the selector" do
    dial_codes = Jason.decode!(Phones.dial_codes_json())
    options = Phones.options()

    assert map_size(dial_codes) == length(options)

    for option <- options do
      assert dial_codes[option.value] == option.selected_label
    end

    assert dial_codes["MY"] == "+60"
    assert dial_codes["CA"] == dial_codes["US"]
    assert Phones.filter_options("") == options
    assert Phones.filter_options("  ") == options
  end

  test "country options separate their searchable label from the selected dial code" do
    malaysia = Enum.find(Phones.options(), &(&1.value == "MY"))

    assert malaysia == %{
             label: "+60 Malaysia (MY)",
             selected_label: "+60",
             value: "MY"
           }
  end

  test "country names and dial codes find the same compact selection metadata" do
    for query <- ["Malaysia", "+60", "MY"] do
      assert %{selected_label: "+60", label: "+60 Malaysia (MY)"} =
               Enum.find(Phones.filter_options(query), &(&1.value == "MY"))
    end
  end

  test "countries sharing a dial code keep distinct option labels and values" do
    options = Phones.filter_options("+1")
    canada = Enum.find(options, &(&1.value == "CA"))
    united_states = Enum.find(options, &(&1.value == "US"))

    assert canada.selected_label == united_states.selected_label
    assert canada.label != united_states.label
    assert canada.value != united_states.value
  end
end

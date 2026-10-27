defmodule Elixirbits.CoreUtils.PhonesTest do
  use ExUnit.Case, async: true

  alias Elixirbits.CoreUtils.Phones

  test "browser dial codes cover the same countries as the selector" do
    dial_codes = Jason.decode!(Phones.dial_codes_json())
    options = Phones.options()

    assert map_size(dial_codes) == length(options)

    for {_label, iso, metadata} <- options do
      assert dial_codes[iso] == metadata[:dial_code]
    end

    assert dial_codes["MY"] == "+60"
    assert dial_codes["CA"] == dial_codes["US"]
    assert Phones.filter_options("") == options
    assert Phones.filter_options("  ") == options
  end

  test "country options separate their searchable label from the selected dial code" do
    malaysia = Enum.find(Phones.options(), &(elem(&1, 1) == "MY"))

    assert malaysia == {"+60 Malaysia (MY)", "MY", dial_code: "+60"}
  end

  test "country names and dial codes find the same compact selection metadata" do
    for query <- ["Malaysia", "+60", "MY"] do
      assert {"+60 Malaysia (MY)", "MY", dial_code: "+60"} =
               Enum.find(Phones.filter_options(query), &(elem(&1, 1) == "MY"))
    end
  end

  test "countries sharing a dial code keep distinct option labels and values" do
    options = Phones.filter_options("+1")
    {canada_label, canada_iso, canada_metadata} = Enum.find(options, &(elem(&1, 1) == "CA"))
    {us_label, us_iso, us_metadata} = Enum.find(options, &(elem(&1, 1) == "US"))

    assert canada_metadata[:dial_code] == us_metadata[:dial_code]
    assert canada_label != us_label
    assert canada_iso != us_iso
  end
end

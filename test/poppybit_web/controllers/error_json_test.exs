defmodule PoppybitWeb.ErrorJSONTest do
  use PoppybitWeb.ConnCase, async: true

  test "renders 404" do
    assert PoppybitWeb.ErrorJSON.render("404.json", %{}) == %{errors: %{detail: "Not Found"}}
  end

  test "renders 500" do
    assert PoppybitWeb.ErrorJSON.render("500.json", %{}) ==
             %{errors: %{detail: "Internal Server Error"}}
  end
end

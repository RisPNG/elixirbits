defmodule ElixirbitsWeb.CoreComponentsTest do
  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest

  alias ElixirbitsWeb.CoreComponents

  describe "input render_as" do
    test "enabled renders a real input by default" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.input type="text" name="city" value="Ipoh" label="City" />
        """)

      assert html =~ "<input"
      assert html =~ ~s(name="city")
      assert html =~ ~s(value="Ipoh")
    end

    test "disabled renders a lookalike span without an input" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.input
          type="text"
          id="city"
          name="city"
          value="Ipoh"
          label="City"
          render_as="disabled"
        />
        """)

      refute html =~ "<input"
      assert html =~ ~s(id="city")
      assert html =~ "Ipoh"
      assert html =~ "bg-base-200"
      assert html =~ "cursor-not-allowed"
      assert html =~ "input-floating-label-on-disabled"
    end

    test "like-enabled renders a lookalike span with the enabled visual" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.input type="text" name="city" value="Ipoh" label="City" render_as="like-enabled" />
        """)

      refute html =~ "<input"
      assert html =~ "Ipoh"
      assert html =~ "bg-base-100"
      refute html =~ "cursor-not-allowed"
      refute html =~ "input-floating-label-on-disabled"
    end

    test "like-disabled renders a lookalike span plus the real input hidden" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.input
          type="text"
          id="city"
          name="city"
          value="Ipoh"
          label="City"
          render_as="like-disabled"
        />
        """)

      assert html =~ ~s(<div class="hidden">)
      assert html =~ "<input"
      assert html =~ ~s(name="city")
      assert html =~ ~s(value="Ipoh")
      assert html =~ "cursor-not-allowed"
      assert length(String.split(html, ~s(id="city"))) == 2
    end

    test "hidden renders the real input inside a hidden wrapper" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.input type="text" name="city" value="Ipoh" label="City" render_as="hidden" />
        """)

      assert html =~ ~s(<div class="hidden">)
      assert html =~ "<input"
      assert html =~ ~s(name="city")
      assert html =~ ~s(value="Ipoh")
      refute html =~ "input-floating-label-on-disabled"
    end

    test "hidden-disabled renders nothing" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.input
          type="text"
          name="city"
          value="Ipoh"
          label="City"
          render_as="hidden-disabled"
        />
        """)

      assert String.trim(html) == ""
    end

    test "select span shows the option label instead of the raw value" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.input
          type="select"
          name="state"
          value="prk"
          label="State"
          options={[{"Perak", "prk"}, {"Penang", "png"}]}
          render_as="disabled"
        />
        """)

      refute html =~ "<input"
      assert html =~ "Perak"
      refute html =~ ">prk<"
    end

    test "empty span keeps the floating label centered instead of floated" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.input type="text" name="city" value="" label="City" render_as="disabled" />
        """)

      refute html =~ "input-floating-control"
      refute html =~ "input-floating-label-on-disabled"
      assert html =~ "input-floating-label"
    end

    test "checkbox span renders the box visual without a checkbox input" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.input
          type="checkbox"
          name="active"
          value={true}
          label="Active"
          render_as="disabled"
        />
        """)

      refute html =~ "<input"
      assert html =~ "bg-neutral"
      assert html =~ "cursor-not-allowed"
    end

    test "switch span renders the toggle visual without a checkbox input" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.input
          type="switch"
          name="active"
          value={true}
          label="Active"
          render_as="like-enabled"
        />
        """)

      refute html =~ "<input"
      assert html =~ "rounded-full"
      assert html =~ "before:translate-x-5"
    end
  end

  describe "input phx-debounce" do
    test "text inputs default to blur" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.input type="text" name="city" value="" label="City" />
        """)

      assert html =~ ~s(phx-debounce="blur")
    end

    test "textarea defaults to blur" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.input type="textarea" name="remark" value="" label="Remark" />
        """)

      assert html =~ ~s(phx-debounce="blur")
    end

    test "caller can override the default" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.input type="text" name="city" value="" label="City" phx-debounce="500" />
        """)

      assert html =~ ~s(phx-debounce="500")
      refute html =~ ~s(phx-debounce="blur")
    end

    test "checkbox stays undebounced so toggles fire immediately" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.input type="checkbox" name="active" value={true} label="Active" />
        """)

      refute html =~ "phx-debounce"
    end
  end

  describe "input autocomplete" do
    test "defaults to off" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.input type="text" name="city" value="" label="City" />
        """)

      assert html =~ ~s(autocomplete="off")
    end

    test "caller can override the default" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.input type="text" name="city" value="" label="City" autocomplete="on" />
        """)

      assert html =~ ~s(autocomplete="on")
      refute html =~ ~s(autocomplete="off")
    end
  end
end

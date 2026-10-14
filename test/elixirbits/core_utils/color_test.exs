defmodule Elixirbits.CoreUtils.ColorTest do
  use ExUnit.Case, async: true

  alias Elixirbits.CoreUtils.Color

  test "selected formats and alpha survive casting, storage, and loading without conversion" do
    for value <- [
          "#c82",
          "#c828",
          "#C9822B",
          "#c9822b80",
          "rgb(201 130 43 / 50%)",
          "rgba(201, 130, 43, 0.5)",
          "rgb(1e2 2e1 5e0 / 5e-1)",
          "rgb(80%, 50%, 20%, 50%)",
          "rgb(78.8235294118% 50.9803921569% 16.862745098% / 0.123456789)",
          "hsl(33.0379746835deg 64.7540983607% 47.8431372549% / .5)",
          "hsla(33, 65%, 48%, 0.5)",
          "hsl(100grad 50% 50%)",
          "hsl(1.5rad 50% 50%)",
          "oklab(0.658012345678 0.058 -0.12 / 0.5)",
          "oklab(.65 -.05 +.01 / .5)",
          "oklch(65.8012345678% 0.142 65 / 0.5)",
          "lab(50% 40 -30 / 50%)",
          "lch(50% 40 30deg / .375)",
          "lch(50 20 .5turn)",
          "  OKLCH(65% 0.14 65DEG / 0.5)  ",
          "  COLOR(SRGB .2 +.3 4e-1 / 37.5%)  ",
          "color(xyz .2 .3 .4)",
          "color(xyz-d50 .2 .3 .4 / .375)",
          "color(xyz-d65 .2 .3 .4 / .375)",
          "device-cmyk(0 0.3 0.7 0.2 / 0.375)",
          "device-cmyk(0% 30% 70% 20% / 37.5%)",
          "#1e999999"
        ] do
      assert {:ok, ^value} = Ash.Type.cast_input(Color, value)
      assert {:ok, ^value} = Ash.Type.dump_to_native(Color, value)
      assert {:ok, ^value} = Ash.Type.cast_stored(Color, value)
    end
  end

  test "the available formats all support native conversion and serialization" do
    assert Color.options() == [
             {"HEX", "hex"},
             {"RGB", "rgb"},
             {"HSL", "hsl"},
             {"Lab", "lab"},
             {"LCH", "lch"},
             {"OKLab", "oklab"},
             {"OKLCH", "oklch"},
             {"XYZ D50", "xyz-d50"},
             {"XYZ D65", "xyz-d65"},
             {"CMYK", "cmyk"}
           ]

    assert {:ok, %{color: source, rgba: original}} =
             Color.inspect_color("oklch(65.123456789% 0.1 65.123456789 / 0.123456789)")

    for {_label, format} <- Color.options() do
      assert {:ok, %{value: value, format: ^format, color: ^source}} =
               Color.convert_color(source, format)

      assert {:ok, %{value: ^value, format: ^format, rgba: recovered}} =
               Color.inspect_color(value)

      assert_in_delta recovered.r, original.r, 0.6
      assert_in_delta recovered.g, original.g, 0.6
      assert_in_delta recovered.b, original.b, 0.6
      assert_in_delta recovered.a, original.a, 0.002
    end
  end

  test "format selection retains the precise original color rather than converting rounded output" do
    assert {:ok, %{color: source}} =
             Color.inspect_color("oklch(65.123456789% 0.123456789 65.123456789 / 0.123456789)")

    assert {:ok, %{value: hex, color: ^source}} = Color.convert_color(source, "hex")
    assert {:ok, %{value: rgb, color: ^source}} = Color.convert_color(source, "rgb")
    assert {:ok, %{value: hex_again, color: ^source}} = Color.convert_color(source, "hex")
    assert hex == hex_again
    assert rgb =~ "/ 0.1235)"
    assert source.alpha == 0.123456789
    assert source.c == 0.123456789
    assert source.h == 65.123456789
  end

  test "aliases detect canonical formats while preserving the entered text" do
    for {value, format} <- [
          {"rgba(201, 130, 43, .375)", "rgb"},
          {"hsla(33, 65%, 48%, .375)", "hsl"},
          {"COLOR(  SRGB .2 .3 .4 / .375)", "rgb"},
          {"color(xyz .2 .3 .4 / .375)", "xyz-d65"}
        ] do
      assert {:ok, %{value: ^value, format: ^format}} = Color.inspect_color(value)
    end

    assert {:ok, %{rgba: rgba}} = Color.inspect_color("color(srgb 1 0 0 / .375)")
    assert_in_delta rgba.r, 255, 0.001
    assert_in_delta rgba.g, 0, 0.001
    assert_in_delta rgba.b, 0, 0.001
    assert rgba.a == 0.375
  end

  test "Lab and LCH serialization adapts to the CSS D50 reference white" do
    assert {:ok, %{color: red}} = Color.inspect_color("#ff0000")
    assert {:ok, %{value: lab}} = Color.convert_color(red, "lab")
    assert {:ok, %{color: %Elixir.Color.Lab{} = parsed_lab}} = Color.inspect_color(lab)
    assert parsed_lab.illuminant == :D50
    assert_in_delta parsed_lab.l, 54.29, 0.08
    assert_in_delta parsed_lab.a, 80.81, 0.08
    assert_in_delta parsed_lab.b, 69.89, 0.08

    assert {:ok, %{value: lch}} = Color.convert_color(red, "lch")
    assert {:ok, %{color: %Elixir.Color.LCHab{} = parsed_lch}} = Color.inspect_color(lch)
    assert parsed_lch.illuminant == :D50
    assert_in_delta parsed_lch.l, 54.29, 0.08
    assert_in_delta parsed_lch.c, 106.84, 0.1
    assert_in_delta parsed_lch.h, 40.85, 0.1
  end

  test "XYZ serialization adapts channels and identifies each reference white" do
    assert {:ok, %{color: red}} = Color.inspect_color("#ff0000")
    assert {:ok, %{value: d50}} = Color.convert_color(red, "xyz-d50")
    assert {:ok, %{color: d50_color, format: "xyz-d50"}} = Color.inspect_color(d50)
    assert d50_color.illuminant == :D50
    assert_in_delta d50_color.x, 0.4361, 0.0002
    assert_in_delta d50_color.y, 0.2225, 0.0002
    assert_in_delta d50_color.z, 0.0139, 0.0002

    assert {:ok, %{value: d65}} = Color.convert_color(red, "xyz-d65")
    assert {:ok, %{color: d65_color, format: "xyz-d65"}} = Color.inspect_color(d65)
    assert d65_color.illuminant == :D65
    assert_in_delta d65_color.x, 0.4125, 0.0002
    assert_in_delta d65_color.y, 0.2127, 0.0002
    assert_in_delta d65_color.z, 0.0193, 0.0002
  end

  test "out-of-gamut previews use bounded sRGB without modifying stored values" do
    value = "oklch(70% 0.4 30 / 0.123456789)"

    assert {:ok, %{value: ^value, color: source, rgba: rgba, swatch: swatch}} =
             Color.inspect_color(value)

    assert source.c == 0.4
    assert source.alpha == 0.123456789
    assert rgba.a == 0.123456789
    assert {:ok, %{format: "rgb"}} = Color.inspect_color(swatch)

    for channel <- [rgba.r, rgba.g, rgba.b] do
      assert channel >= 0
      assert channel <= 255
    end

    for format <- ["hex", "rgb", "hsl", "cmyk"] do
      assert {:ok, %{value: converted, color: ^source}} = Color.convert_color(source, format)
      assert {:ok, _color} = Color.inspect_color(converted)
    end
  end

  test "hue units wrap correctly across repeated and negative rotations" do
    for value <- ["hsl(720 100% 50%)", "hsl(-720deg 100% 50%)", "hsl(2turn 100% 50%)"] do
      assert {:ok, %{rgba: rgba}} = Color.inspect_color(value)
      assert_in_delta rgba.r, 255, 0.001
      assert_in_delta rgba.g, 0, 0.001
      assert_in_delta rgba.b, 0, 0.001
    end
  end

  test "bounded CSS spaces clamp channels without changing the entered text" do
    for {value, expected, channels} <- [
          {"rgb(300 0 0)", "rgb(255 0 0)", [255, 0, 0]},
          {"rgb(-10 0 0)", "rgb(0 0 0)", [0, 0, 0]},
          {"hsl(0 200% 50%)", "rgb(255 0 0)", [255, 0, 0]},
          {"hsl(0 -100% 50%)", "rgb(128 128 128)", [127.5, 127.5, 127.5]},
          {"hsl(0 50% 200%)", "rgb(255 255 255)", [255, 255, 255]},
          {"hsl(0 50% -100%)", "rgb(0 0 0)", [0, 0, 0]},
          {"device-cmyk(0 200% 200% 0)", "rgb(255 0 0)", [255, 0, 0]},
          {"device-cmyk(0 -100% -100% 0)", "rgb(255 255 255)", [255, 255, 255]},
          {"device-cmyk(0 0 0 200%)", "rgb(0 0 0)", [0, 0, 0]}
        ] do
      assert {:ok, %{value: ^value, rgba: rgba, swatch: ^expected, color: source}} =
               Color.inspect_color(value)

      for {actual, expected} <- Enum.zip([rgba.r, rgba.g, rgba.b], channels) do
        assert_in_delta actual, expected, 0.001
      end

      assert {:ok, ^value} = Ash.Type.cast_input(Color, value)
      assert {:ok, %{value: ^expected, color: ^source}} = Color.convert_color(source, "rgb")
    end
  end

  test "CSS alpha limits affect previews while source precision and text remain unchanged" do
    for {value, alpha, expected} <- [
          {"rgb(201 130 43 / 150%)", 1.5, 1.0},
          {"oklch(65% 0.14 65 / -.5)", -0.5, 0.0}
        ] do
      assert {:ok, %{value: ^value, color: source, rgba: rgba}} = Color.inspect_color(value)
      assert source.alpha == alpha
      assert rgba.a == expected
    end

    assert {:ok, %{color: source}} = Color.inspect_color("lab(70% 150 150)")
    assert source.l == 70
    assert source.a == 150
    assert source.b == 150

    assert {:ok, %{value: "lab(70% 150 150)", color: ^source}} =
             Color.convert_color(source, "lab")
  end

  test "the storage type generates a PostgreSQL text column" do
    assert Ash.Type.storage_type(Color) == :string
    assert AshPostgres.MigrationGenerator.get_migration_type(Color, []) == :text
  end

  test "optional color attributes accept nil and blank form input" do
    for value <- [nil, "", "  "] do
      assert Color.inspect_color(value) == {:ok, nil}
      assert Ash.Type.cast_input(Color, value) == {:ok, nil}
      assert Ash.Type.dump_to_native(Color, value) == {:ok, nil}
      assert Ash.Type.cast_stored(Color, value) == {:ok, nil}
    end
  end

  test "malformed values are rejected at the type boundary" do
    for value <- [
          "#12",
          "#12345",
          "#123456789",
          "#gggggg",
          "rgb(255 0)",
          "rgb(255,,0,0)",
          "rgb(255, 0 0)",
          "rgb(100%, 0, 0)",
          "rgb(255deg 0 0)",
          "rgb(255 0 0 .5)",
          "rgba(255, 0, 0, invalid)",
          "rgb(255 0 0 / .5 / .5)",
          "hsl(30% 50% 50%)",
          "hsl(30, 50% 50%)",
          "hsl(30, 50, 50)",
          "hsl(30 50 50)",
          "oklab(0.6 0.1)",
          "oklab(0.6, 0.1, 0.1)",
          "oklab(0.6 0.1turn 0.1)",
          "oklch(0.6 0.1 30%)",
          "lab(50% 40deg 30)",
          "lch(50% 40% 30%)",
          "color(xyz-d50 1 0)",
          "color(xyz-d50 1 0 0 1)",
          "color(xyz-d50 1, 0, 0)",
          "color(xyz-d50 1 0 0 / .5 / .5)",
          "color(xyz-d50 1 0 0 .5)",
          "color(xyz-d50 1 0 0 / 50deg)",
          "color(unknown .1 .2 .3)",
          "color(xyz-d50 .1 .2 .3",
          "device-cmyk(0 1 1)",
          "device-cmyk(0 1 1 0, red)",
          "rgb(NaN 0 0)",
          "rgb(Infinity 0 0)",
          "rgb(1e999 0 0)",
          "rgba(1, 2, 3, 1e999)",
          "hsl(1e999deg 50% 50%)",
          "lab(50 1e999 30)",
          "lab(1e300 40 30)",
          "oklch(0.6 0.1 30 / -1e999)",
          "color(xyz-d50 1e999 0 0)",
          "device-cmyk(0 1 1 0 / 1e999%)",
          "oklch(0.6 0.1 30",
          "#c9822b; color: red",
          123,
          %{},
          :red
        ] do
      assert Color.inspect_color(value) == {:error, "must be a supported color value"}
      assert Ash.Type.cast_input(Color, value) == {:error, "must be a supported color value"}
      assert Ash.Type.dump_to_native(Color, value) == {:error, "must be a supported color value"}
    end
  end

  test "unsupported spaces and contextual or computed CSS cannot become stored values" do
    for value <- [
          "red",
          "transparent",
          "currentColor",
          "var(--color-primary)",
          "hwb(30 20% 40%)",
          "oklab(65% 10% -10%)",
          "oklch(0.6 10% 30)",
          "lab(50 20% -10%)",
          "color(srgb 20% 30% 40%)",
          "color(xyz 20% 30% 40%)",
          "color(display-p3 1 0 0)",
          "color(a98-rgb 1 0 0)",
          "color(rec2020 1 0 0)",
          "color(prophoto-rgb 1 0 0)",
          "color(srgb-linear 1 0 0)",
          "color(--hsv 30 .4 .5)",
          "color(--oklch .6 .1 30)",
          "color(xyz none 0 0)",
          "color(from red xyz r g b)",
          "color(xyz calc(30 + 1) .4 .5)",
          "color-mix(in oklch, red, blue)",
          "rgb(from red r g b)",
          "rgb(calc(255 / 2) 0 0)",
          "oklch(0.7 none 30)"
        ] do
      assert Ash.Type.cast_input(Color, value) == {:error, "must be a supported color value"}
    end
  end

  test "conversion rejects unsupported target formats" do
    assert {:ok, %{color: source}} = Color.inspect_color("#c9822b")

    for format <- ["rgba", "hsla", "hwb", "display-p3", "unknown", nil] do
      assert Color.convert_color(source, format) == {:error, "must be a supported color value"}
    end

    assert Color.convert_color(nil, "hex") == {:error, "must be a supported color value"}
  end
end

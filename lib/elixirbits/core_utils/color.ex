defmodule Elixirbits.CoreUtils.Color do
  @moduledoc false

  use Ash.Type

  @options [
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
  @targets %{
    "hex" => Color.SRGB,
    "rgb" => Color.SRGB,
    "hsl" => Color.HSL,
    "lab" => Color.Lab,
    "lch" => Color.LCHab,
    "oklab" => Color.Oklab,
    "oklch" => Color.Oklch,
    "xyz-d50" => Color.XYZ,
    "xyz-d65" => Color.XYZ,
    "cmyk" => Color.CMYK
  }
  @formats Map.keys(@targets)
  @number "[+-]?(?:[0-9]+(?:\\.[0-9]+)?|\\.[0-9]+)(?:e[+-]?[0-9]+)?"
  @channel "#{@number}%?"
  @hue "#{@number}(?:deg|grad|rad|turn)?"
  @syntax ~r/\A(?:
    \#(?:[0-9a-f]{3}|[0-9a-f]{4}|[0-9a-f]{6}|[0-9a-f]{8})
    | rgba?\(\s*#{@channel}\s+#{@channel}\s+#{@channel}(?:\s*\/\s*#{@channel})?\s*\)
    | rgba?\(\s*(?:#{@number}\s*,\s*#{@number}\s*,\s*#{@number}|#{@number}%\s*,\s*#{@number}%\s*,\s*#{@number}%)(?:\s*,\s*#{@channel})?\s*\)
    | hsla?\(\s*#{@hue}\s+#{@number}%\s+#{@number}%(?:\s*\/\s*#{@channel})?\s*\)
    | hsla?\(\s*#{@hue}\s*,\s*#{@number}%\s*,\s*#{@number}%(?:\s*,\s*#{@channel})?\s*\)
    | (?:oklab|lab)\(\s*#{@channel}\s+#{@number}\s+#{@number}(?:\s*\/\s*#{@channel})?\s*\)
    | (?:oklch|lch)\(\s*#{@channel}\s+#{@number}\s+#{@hue}(?:\s*\/\s*#{@channel})?\s*\)
    | color\(\s*(?:srgb|xyz|xyz-d50|xyz-d65)\s+#{@number}\s+#{@number}\s+#{@number}(?:\s*\/\s*#{@channel})?\s*\)
    | device-cmyk\(\s*#{@channel}\s+#{@channel}\s+#{@channel}\s+#{@channel}(?:\s*\/\s*#{@channel})?\s*\)
  )\z/x
  @numbers ~r/#{@number}/
  @error "must be a supported color value"

  def options, do: @options

  def inspect_color(value) when is_binary(value) do
    input =
      value
      |> String.trim()
      |> String.downcase()
      |> String.replace(~r/(?<![\d.])([+-]?)\.(?=\d)/, "\\g{1}0.")

    if input == "" do
      {:ok, nil}
    else
      with true <- Regex.match?(@syntax, input),
           true <-
             String.starts_with?(input, "#") ||
               Enum.all?(Regex.scan(@numbers, input), fn [number] ->
                 match?({_number, ""}, Float.parse(number))
               end),
           {:ok, color} <- Color.CSS.parse(input),
           {:ok, color} <-
             (case color do
                %Color.SRGB{r: r, g: g, b: b}
                when r >= 0 and r <= 1 and g >= 0 and g <= 1 and b >= 0 and b <= 1 ->
                  {:ok, color}

                %Color.SRGB{} ->
                  Color.Gamut.to_gamut(color, :SRGB, method: :clip)

                %Color.HSL{h: hue} ->
                  {:ok,
                   %{
                     color
                     | h: hue - Float.floor(hue),
                       s: color.s |> max(0.0) |> min(1.0),
                       l: color.l |> max(0.0) |> min(1.0)
                   }}

                %Color.CMYK{} ->
                  {:ok,
                   %{
                     color
                     | c: color.c |> max(0.0) |> min(1.0),
                       m: color.m |> max(0.0) |> min(1.0),
                       y: color.y |> max(0.0) |> min(1.0),
                       k: color.k |> max(0.0) |> min(1.0)
                   }}

                color ->
                  {:ok, color}
              end),
           {:ok, preview} <- color_preview(color) do
        format =
          if String.starts_with?(input, "#") do
            "hex"
          else
            case color do
              %Color.XYZ{illuminant: :D50} ->
                "xyz-d50"

              %Color.XYZ{} ->
                "xyz-d65"

              color ->
                Enum.find_value(@options, fn {_label, format} ->
                  if format != "hex" && Map.fetch!(@targets, format) == color.__struct__,
                    do: format
                end)
            end
          end

        {:ok,
         preview
         |> Map.delete(:srgb)
         |> Map.merge(%{value: value, format: format, color: color})}
      else
        _ -> {:error, @error}
      end
    end
  rescue
    ArithmeticError -> {:error, @error}
  end

  def inspect_color(nil), do: {:ok, nil}
  def inspect_color(_value), do: {:error, @error}

  def convert_color(%_{} = color, target_format) when target_format in @formats do
    with {:ok, preview} <- color_preview(color),
         {:ok, converted} <-
           (case target_format do
              format when format in ["hex", "rgb"] ->
                {:ok, preview.srgb}

              format when format in ["hsl", "cmyk"] ->
                Color.convert(preview.srgb, Map.fetch!(@targets, format))

              format when format in ["lab", "lch", "xyz-d50", "xyz-d65"] ->
                illuminant = if format == "xyz-d65", do: :D65, else: :D50

                with {:ok, xyz} <- Color.convert(color, Color.XYZ),
                     {:ok, xyz} <- Color.XYZ.adapt(xyz, illuminant) do
                  Color.convert(xyz, Map.fetch!(@targets, format))
                end

              format ->
                Color.convert(color, Map.fetch!(@targets, format))
            end) do
      value = Color.CSS.to_css(converted, as: if(target_format == "hex", do: :hex, else: :rgb))

      {:ok,
       preview
       |> Map.delete(:srgb)
       |> Map.merge(%{value: value, format: target_format, color: color})}
    else
      _ -> {:error, @error}
    end
  end

  def convert_color(_color, _target_format), do: {:error, @error}

  defp color_preview(color) do
    with {:ok, srgb} <-
           (case color do
              %Color.SRGB{} -> {:ok, color}
              %Color.HSL{} -> Color.HSL.to_srgb(color)
              %Color.CMYK{} -> Color.CMYK.to_srgb(color)
              color -> Color.Gamut.to_gamut(color, :SRGB, method: :oklch)
            end) do
      srgb = %{
        srgb
        | r: srgb.r |> max(0.0) |> min(1.0),
          g: srgb.g |> max(0.0) |> min(1.0),
          b: srgb.b |> max(0.0) |> min(1.0),
          alpha: (srgb.alpha || 1.0) |> max(0.0) |> min(1.0)
      }

      {:ok,
       %{
         swatch: Color.CSS.to_css(srgb),
         rgba: %{r: srgb.r * 255, g: srgb.g * 255, b: srgb.b * 255, a: srgb.alpha},
         srgb: srgb
       }}
    end
  end

  @impl true
  def storage_type(_constraints), do: :string

  @impl true
  def matches_type?(value, _constraints), do: is_binary(value)

  @impl true
  def cast_input(value, _constraints) when is_binary(value) do
    case inspect_color(value) do
      {:ok, nil} -> {:ok, nil}
      {:ok, color} -> {:ok, color.value}
      {:error, _} = error -> error
    end
  end

  def cast_input(nil, _constraints), do: {:ok, nil}
  def cast_input(_value, _constraints), do: {:error, @error}

  @impl true
  def cast_stored(value, constraints), do: cast_input(value, constraints)

  @impl true
  def dump_to_native(value, constraints), do: cast_input(value, constraints)
end

defmodule Elixirbits.CoreUtils.Phones do
  @moduledoc """
  ISO 3166-1 alpha-2 country codes paired with E.164 dialing codes.
  Used by the `<.input type="tel">` component to render a searchable
  country-code selector alongside a phone-number text input.
  """

  @raw [
    {"AF", "+93"},
    {"AL", "+355"},
    {"DZ", "+213"},
    {"AS", "+1684"},
    {"AD", "+376"},
    {"AO", "+244"},
    {"AI", "+1264"},
    {"AQ", "+672"},
    {"AG", "+1268"},
    {"AR", "+54"},
    {"AM", "+374"},
    {"AW", "+297"},
    {"AU", "+61"},
    {"AT", "+43"},
    {"AZ", "+994"},
    {"BS", "+1242"},
    {"BH", "+973"},
    {"BD", "+880"},
    {"BB", "+1246"},
    {"BY", "+375"},
    {"BE", "+32"},
    {"BZ", "+501"},
    {"BJ", "+229"},
    {"BM", "+1441"},
    {"BT", "+975"},
    {"BO", "+591"},
    {"BA", "+387"},
    {"BW", "+267"},
    {"BR", "+55"},
    {"IO", "+246"},
    {"VG", "+1284"},
    {"BN", "+673"},
    {"BG", "+359"},
    {"BF", "+226"},
    {"BI", "+257"},
    {"KH", "+855"},
    {"CM", "+237"},
    {"CA", "+1"},
    {"CV", "+238"},
    {"KY", "+1345"},
    {"CF", "+236"},
    {"TD", "+235"},
    {"CL", "+56"},
    {"CN", "+86"},
    {"CX", "+61"},
    {"CC", "+61"},
    {"CO", "+57"},
    {"KM", "+269"},
    {"CK", "+682"},
    {"CR", "+506"},
    {"HR", "+385"},
    {"CU", "+53"},
    {"CW", "+599"},
    {"CY", "+357"},
    {"CZ", "+420"},
    {"CD", "+243"},
    {"DK", "+45"},
    {"DJ", "+253"},
    {"DM", "+1767"},
    {"DO", "+1809"},
    {"TL", "+670"},
    {"EC", "+593"},
    {"EG", "+20"},
    {"SV", "+503"},
    {"GQ", "+240"},
    {"ER", "+291"},
    {"EE", "+372"},
    {"SZ", "+268"},
    {"ET", "+251"},
    {"FK", "+500"},
    {"FO", "+298"},
    {"FJ", "+679"},
    {"FI", "+358"},
    {"FR", "+33"},
    {"PF", "+689"},
    {"GA", "+241"},
    {"GM", "+220"},
    {"GE", "+995"},
    {"DE", "+49"},
    {"GH", "+233"},
    {"GI", "+350"},
    {"GR", "+30"},
    {"GL", "+299"},
    {"GD", "+1473"},
    {"GU", "+1671"},
    {"GT", "+502"},
    {"GG", "+44"},
    {"GN", "+224"},
    {"GW", "+245"},
    {"GY", "+592"},
    {"HT", "+509"},
    {"HN", "+504"},
    {"HK", "+852"},
    {"HU", "+36"},
    {"IS", "+354"},
    {"IN", "+91"},
    {"ID", "+62"},
    {"IR", "+98"},
    {"IQ", "+964"},
    {"IE", "+353"},
    {"IM", "+44"},
    {"IL", "+972"},
    {"IT", "+39"},
    {"CI", "+225"},
    {"JM", "+1876"},
    {"JP", "+81"},
    {"JE", "+44"},
    {"JO", "+962"},
    {"KZ", "+7"},
    {"KE", "+254"},
    {"KI", "+686"},
    {"XK", "+383"},
    {"KW", "+965"},
    {"KG", "+996"},
    {"LA", "+856"},
    {"LV", "+371"},
    {"LB", "+961"},
    {"LS", "+266"},
    {"LR", "+231"},
    {"LY", "+218"},
    {"LI", "+423"},
    {"LT", "+370"},
    {"LU", "+352"},
    {"MO", "+853"},
    {"MG", "+261"},
    {"MW", "+265"},
    {"MY", "+60"},
    {"MV", "+960"},
    {"ML", "+223"},
    {"MT", "+356"},
    {"MH", "+692"},
    {"MR", "+222"},
    {"MU", "+230"},
    {"YT", "+262"},
    {"MX", "+52"},
    {"FM", "+691"},
    {"MD", "+373"},
    {"MC", "+377"},
    {"MN", "+976"},
    {"ME", "+382"},
    {"MS", "+1664"},
    {"MA", "+212"},
    {"MZ", "+258"},
    {"MM", "+95"},
    {"NA", "+264"},
    {"NR", "+674"},
    {"NP", "+977"},
    {"NL", "+31"},
    {"NC", "+687"},
    {"NZ", "+64"},
    {"NI", "+505"},
    {"NE", "+227"},
    {"NG", "+234"},
    {"NU", "+683"},
    {"NF", "+672"},
    {"KP", "+850"},
    {"MK", "+389"},
    {"MP", "+1670"},
    {"NO", "+47"},
    {"OM", "+968"},
    {"PK", "+92"},
    {"PW", "+680"},
    {"PS", "+970"},
    {"PA", "+507"},
    {"PG", "+675"},
    {"PY", "+595"},
    {"PE", "+51"},
    {"PH", "+63"},
    {"PN", "+64"},
    {"PL", "+48"},
    {"PT", "+351"},
    {"PR", "+1787"},
    {"QA", "+974"},
    {"CG", "+242"},
    {"RE", "+262"},
    {"RO", "+40"},
    {"RU", "+7"},
    {"RW", "+250"},
    {"BL", "+590"},
    {"SH", "+290"},
    {"KN", "+1869"},
    {"LC", "+1758"},
    {"MF", "+590"},
    {"PM", "+508"},
    {"VC", "+1784"},
    {"WS", "+685"},
    {"SM", "+378"},
    {"ST", "+239"},
    {"SA", "+966"},
    {"SN", "+221"},
    {"RS", "+381"},
    {"SC", "+248"},
    {"SL", "+232"},
    {"SG", "+65"},
    {"SX", "+1721"},
    {"SK", "+421"},
    {"SI", "+386"},
    {"SB", "+677"},
    {"SO", "+252"},
    {"ZA", "+27"},
    {"KR", "+82"},
    {"SS", "+211"},
    {"ES", "+34"},
    {"LK", "+94"},
    {"SD", "+249"},
    {"SR", "+597"},
    {"SJ", "+47"},
    {"SE", "+46"},
    {"CH", "+41"},
    {"SY", "+963"},
    {"TW", "+886"},
    {"TJ", "+992"},
    {"TZ", "+255"},
    {"TH", "+66"},
    {"TG", "+228"},
    {"TK", "+690"},
    {"TO", "+676"},
    {"TT", "+1868"},
    {"TN", "+216"},
    {"TR", "+90"},
    {"TM", "+993"},
    {"TC", "+1649"},
    {"TV", "+688"},
    {"VI", "+1340"},
    {"UG", "+256"},
    {"UA", "+380"},
    {"AE", "+971"},
    {"GB", "+44"},
    {"US", "+1"},
    {"UY", "+598"},
    {"UZ", "+998"},
    {"VU", "+678"},
    {"VA", "+39"},
    {"VE", "+58"},
    {"VN", "+84"},
    {"WF", "+681"},
    {"EH", "+212"},
    {"YE", "+967"},
    {"ZM", "+260"},
    {"ZW", "+263"}
  ]

  @countries Enum.map(@raw, fn {iso, dial} ->
               name =
                 case Cldr.Territory.from_territory_code(String.to_atom(iso), Elixirbits.Cldr) do
                   {:ok, n} -> n
                   _ -> iso
                 end

               %{iso: iso, name: name, dial_code: dial}
             end)
             |> Enum.sort_by(& &1.name)

  @doc "Returns all countries sorted by name."
  def list_countries, do: @countries

  @doc """
  Returns LiveSelect-shaped options. Each option is `{label, iso}` where
  the label is `"+60 Malaysia (MY)"`.
  """
  def options do
    Enum.map(@countries, fn c -> {label_for(c), c.iso} end)
  end

  @doc """
  Filters options by `text`, matching against ISO code, country name, or
  dial code. Empty text returns the full list.
  """
  def filter_options(text) when is_binary(text) do
    needle = text |> String.trim() |> String.downcase() |> String.trim_leading("+")

    if needle == "" do
      options()
    else
      @countries
      |> Enum.filter(fn c ->
        String.contains?(String.downcase(c.iso), needle) or
          String.contains?(String.downcase(c.name), needle) or
          String.contains?(String.trim_leading(c.dial_code, "+"), needle)
      end)
      |> Enum.map(fn c -> {label_for(c), c.iso} end)
    end
  end

  def filter_options(_), do: options()

  @doc "Looks up a country by ISO 3166-1 alpha-2 code."
  def by_iso(iso) when is_binary(iso) do
    Enum.find(@countries, &(&1.iso == String.upcase(iso)))
  end

  def by_iso(_), do: nil

  @doc """
  Splits a composite phone string like `"+60 123456789"` or `"+60123456789"`
  into `{dial_code, number, iso}`. The longest matching dial-code prefix wins.
  Returns `{nil, raw, nil}` if no dial-code prefix is detected.
  """
  def parse(value) when is_binary(value) do
    trimmed = String.trim(value)

    cond do
      trimmed == "" ->
        {nil, "", nil}

      String.starts_with?(trimmed, "+") ->
        match =
          @countries
          |> Enum.filter(fn c -> String.starts_with?(trimmed, c.dial_code) end)
          |> Enum.max_by(fn c -> String.length(c.dial_code) end, fn -> nil end)

        case match do
          nil ->
            {nil, trimmed, nil}

          c ->
            rest =
              trimmed
              |> String.replace_prefix(c.dial_code, "")
              |> String.trim_leading()

            {c.dial_code, rest, c.iso}
        end

      true ->
        {nil, trimmed, nil}
    end
  end

  def parse(_), do: {nil, "", nil}

  defp label_for(%{iso: iso, name: name, dial_code: dial}) do
    "#{dial} #{name} (#{iso})"
  end
end

defmodule Elixirbits.Cldr do
  use Cldr,
    locales: ["en"],
    default_locale: "en",
    providers: [
      Cldr.Calendar,
      Cldr.DateTime,
      Cldr.List,
      Cldr.Number,
      Cldr.PersonName,
      Cldr.Territory,
      Cldr.Unit
    ]
end

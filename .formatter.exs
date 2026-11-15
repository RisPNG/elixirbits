[
  import_deps: [
    :cinder,
    :ash_typescript,
    :ash_paper_trail,
    :ash_archival,
    :ash_state_machine,
    :ash_json_api,
    :ash_phoenix,
    :ash,
    :reactor,
    :ecto,
    :phoenix
  ],
  plugins: [Spark.Formatter, Phoenix.LiveView.HTMLFormatter],
  inputs: [
    ".dialyzer_ignore.exs",
    "*.{heex,ex,exs}",
    "{config,lib,test}/**/*.{heex,ex,exs}"
  ]
]

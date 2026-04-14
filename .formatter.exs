[
  import_deps: [
    :cinder,
    :ash_typescript,
    :ash_double_entry,
    :ash_events,
    :ash_paper_trail,
    :ash_archival,
    :ash_state_machine,
    :ash_admin,
    :ash_authentication_phoenix,
    :ash_authentication,
    :ash_postgres,
    :ash_json_api,
    :ash_phoenix,
    :ash,
    :reactor,
    :ecto,
    :ecto_sql,
    :phoenix
  ],
  subdirectories: ["priv/*/migrations"],
  plugins: [Spark.Formatter, Phoenix.LiveView.HTMLFormatter],
  inputs: ["*.{heex,ex,exs}", "{config,lib,test}/**/*.{heex,ex,exs}", "priv/*/seeds.exs"]
]

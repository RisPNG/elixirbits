defmodule Elixirbits.MixProject do
  use Mix.Project

  @version "0.0.1"

  def project do
    [
      app: :elixirbits,
      version: @version,
      elixir: ">= 1.18.0",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      compilers: [:phoenix_live_view] ++ Mix.compilers(),
      listeners: [Phoenix.CodeReloader],
      consolidate_protocols: Mix.env() != :dev,
      dialyzer: [
        plt_core_path: "priv/plts/core.plt",
        plt_file: {:no_warn, "priv/plts/project.plt"},
        plt_add_apps: [:ex_unit]
      ],
      releases: releases(),
      docs: [
        output: "doc/v#{@version}"
        # filter_modules: regex
      ],
      usage_rules: usage_rules()
    ]
  end

  def releases do
    [
      elixirbits: [
        burrito: [
          targets: [
            macos: [os: :darwin, cpu: :x86_64],
            linux: [os: :linux, cpu: :x86_64],
            windows: [os: :windows, cpu: :x86_64]
          ]
        ],
        applications: [elixirbits: :permanent],
        steps: [:assemble, &Burrito.wrap/1]
      ]
    ]
  end

  defp usage_rules do
    # Example for those using claude.
    [
      file: "CLAUDE.md",
      # rules to include directly in CLAUDE.md
      usage_rules: ["usage_rules:all"],
      skills: [
        location: ".claude/skills",
        # build skills that combine multiple usage rules
        build: [
          "ash-framework": [
            # The description tells people how to use this skill.
            description:
              "Use this skill working with Ash Framework or any of its extensions. Always consult this when making any domain changes, features or fixes.",
            # Include all Ash dependencies
            usage_rules: [:ash, ~r/^ash_/]
          ],
          "phoenix-framework": [
            description:
              "Use this skill working with Phoenix Framework. Consult this when working with the web layer, controllers, views, liveviews etc.",
            # Include all Phoenix dependencies
            usage_rules: [:phoenix, ~r/^phoenix_/]
          ]
        ]
      ]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Elixirbits.Application, []},
      extra_applications: [:logger, :runtime_tools, :os_mon]
    ]
  end

  def cli do
    [
      preferred_envs: [precommit: :test]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:ash, ">= 3.0.0"},
      {:ash_admin, ">= 1.0.0"},
      {:ash_archival, ">= 2.0.0"},
      {:ash_authentication, ">= 4.0.0"},
      {:ash_authentication_phoenix, ">= 2.0.0"},
      {:ash_cloak, ">= 0.2.0"},
      {:ash_double_entry, ">= 1.0.0"},
      {:ash_events, ">= 0.7.0"},
      {:ash_json_api, ">= 1.0.0"},
      {:ash_money, ">= 0.2.0"},
      {:ash_paper_trail, ">= 0.5.0"},
      {:ash_phoenix, ">= 2.0.0"},
      {:ash_postgres, ">= 2.0.0"},
      {:ash_state_machine, ">= 0.2.0"},
      {:ash_typescript, ">= 0.17.0"},
      {:bandit, ">= 1.5.0"},
      {:bcrypt_elixir, ">= 3.0.0"},
      {:burrito, ">= 1.0.0"},
      {:chromic_pdf, ">= 1.17.0"},
      {:cinder, ">= 0.12.0"},
      {:cldr_html, ">= 0.6.0"},
      {:cloak, ">= 1.0.0"},
      {:dialyxir, ">= 1.4.0", only: [:dev, :test], runtime: false},
      {:dns_cluster, ">= 0.1.1"},
      {:ecto_sql, ">= 3.10.0"},
      {:esbuild, ">= 0.8.0", runtime: Mix.env() == :dev},
      {:ex_cldr, ">= 2.0.0"},
      {:ex_cldr_calendars, ">= 1.26.0"},
      {:ex_cldr_calendars_format, ">= 1.0.0"},
      {:ex_cldr_collation, ">= 1.0.0", override: true},
      {:ex_cldr_currencies, ">= 2.13.0"},
      {:ex_cldr_dates_times, ">= 2.0.0"},
      {:ex_cldr_languages, ">= 0.2.0"},
      {:ex_cldr_lists, ">= 2.0.0"},
      {:ex_cldr_locale_display, ">= 1.1.0"},
      {:ex_cldr_messages, ">= 2.0.0"},
      {:ex_cldr_numbers, ">= 2.33.0"},
      {:ex_cldr_person_names, ">= 0.1.0"},
      {:ex_cldr_plugs, ">= 1.3.0"},
      {:ex_cldr_print, ">= 0.3.0"},
      {:ex_cldr_routes, ">= 1.5.0"},
      {:ex_cldr_territories, ">= 2.10.0"},
      {:ex_cldr_units, ">= 3.0.0"},
      {:ex_doc, ">= 0.37.0"},
      {:ex_json_schema, ">= 0.5.0"},
      {:ex_money_sql, ">= 1.0.0"},
      {:faker, ">= 0.18.0", only: [:dev]},
      {:finch, ">= 0.13.0"},
      {:floki, ">= 0.30.0", only: :test},
      {:gen_smtp, ">= 1.2.0"},
      {:gettext, ">= 0.20.0"},
      {:heroicons,
       github: "tailwindlabs/heroicons", sparse: "optimized", app: false, compile: false, depth: 1},
      {:igniter, ">= 0.6.0", only: [:dev, :test]},
      {:image, ">= 0.65.0"},
      {:jason, ">= 1.2.0"},
      {:lazy_html, ">= 0.1.0", only: :test},
      {:live_debugger, ">= 0.3.0", only: :dev},
      {:live_select, github: "rispng/live_select", branch: "testing", override: true},
      {:open_api_spex, ">= 3.0.0"},
      {:phoenix, ">= 1.7.14"},
      {:phoenix_ecto, ">= 4.5.0"},
      {:phoenix_html, ">= 4.1.0"},
      {:phoenix_live_dashboard, ">= 0.8.3"},
      {:phoenix_live_reload, ">= 1.2.0", only: :dev},
      {:phoenix_live_view, ">= 1.0.0"},
      {:phoenix_swagger, ">= 0.8.0"},
      {:picosat_elixir, ">= 0.2.0"},
      {:plug, ">= 1.14.0"},
      {:postgrex, ">= 0.0.0"},
      {:qr_code, ">= 3.0.0"},
      {:quantum, ">= 3.5.0"},
      {:req, ">= 0.5.0"},
      {:sobelow, ">= 0.13.0", only: [:dev, :test], runtime: false},
      {:sourceror, ">= 1.8.0", only: [:dev, :test]},
      {:spreadsheet, ">= 0.4.6"},
      {:styler, ">= 1.4.0", only: [:dev, :test], runtime: false},
      {:swoosh, ">= 1.18.0"},
      {:tailwind, ">= 0.2.0", runtime: Mix.env() == :dev},
      {:telemetry_metrics, ">= 1.0.0"},
      {:telemetry_poller, ">= 1.0.0"},
      {:tesla, ">= 1.11.0"},
      {:tz, ">= 0.28.0"},
      {:tzdata, ">= 1.1.0"},
      {:usage_rules, ">= 1.0.0", only: [:dev]},
      {:xlsx_writer, ">= 0.7.6"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ash.setup", "assets.setup", "assets.build", "run priv/repo/seeds.exs"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ash.setup --quiet", "test"],
      "assets.setup": [
        "tailwind.install --if-missing",
        "esbuild.install --if-missing",
        "ash_typescript.npm_install"
      ],
      "assets.build": ["compile", "tailwind elixirbits", "esbuild elixirbits"],
      "assets.deploy": [
        "tailwind elixirbits --minify",
        "esbuild elixirbits --minify",
        "phx.digest"
      ],
      precommit: ["compile --warnings-as-errors", "deps.unlock --unused", "format", "test"]
    ]
  end
end

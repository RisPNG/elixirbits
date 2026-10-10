# Elixirbits

The template I use for my web applications.

## Created with Ash using
```bash
sh <(curl 'https://ash-hq.org/install/elixirbits?install=phoenix') \
    && cd elixirbits && mix igniter.install ash ash_phoenix \
    ash_json_api ash_postgres ash_authentication \
    ash_authentication_phoenix ash_admin ash_state_machine \
    ash_events ash_money ash_double_entry ash_archival live_debugger \
    ash_paper_trail cloak ash_cloak usage_rules ash_typescript \
    cinder --auth-strategy password --auth-strategy magic_link \
    --auth-strategy api_key --framework react --setup --yes
```

For setup, development, and deployment, see the [development guide](dev/README.md).

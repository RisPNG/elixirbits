# Elixirbits

To start your Phoenix server:

* Run `mix setup` to install and setup dependencies
* Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Learn more

* Official website: https://www.phoenixframework.org/
* Guides: https://hexdocs.pm/phoenix/overview.html
* Docs: https://hexdocs.pm/phoenix
* Forum: https://elixirforum.com/c/phoenix-forum
* Source: https://github.com/phoenixframework/phoenix

## Created by Ash w/
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
defmodule Elixirbits.Application do
  # See https://hexdocs.pm/elixir/Application.html for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    endpoint = Application.fetch_env!(:elixirbits, ElixirbitsWeb.Endpoint)

    if endpoint[:auto_port] && Phoenix.Endpoint.server?(:elixirbits, ElixirbitsWeb.Endpoint) do
      port = endpoint[:http][:port]

      port =
        Enum.find_value(port..65_535, fn candidate ->
          case :gen_tcp.listen(candidate, ip: endpoint[:http][:ip]) do
            {:ok, socket} ->
              :gen_tcp.close(socket)
              candidate

            {:error, :eaddrinuse} ->
              nil

            {:error, reason} ->
              raise "Cannot bind development port #{candidate}: #{:inet.format_error(reason)}"
          end
        end) || raise "No available development port from #{port} to 65535"

      Application.put_env(
        :elixirbits,
        ElixirbitsWeb.Endpoint,
        put_in(endpoint[:http][:port], port)
      )
    end

    children = [
      ElixirbitsWeb.Telemetry,
      Elixirbits.Repo,
      {DNSCluster, query: Application.get_env(:elixirbits, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Elixirbits.PubSub},
      ElixirbitsWeb.Presence,
      Elixirbits.Scheduler,
      Elixirbits.Accounts.LoginGuard,
      # Start a worker by calling: Elixirbits.Worker.start_link(arg)
      # {Elixirbits.Worker, arg},
      # Start to serve requests, typically the last entry
      ElixirbitsWeb.Endpoint,
      {AshAuthentication.Supervisor, [otp_app: :elixirbits]}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html for other strategies and supported options
    opts = [strategy: :one_for_one, name: Elixirbits.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ElixirbitsWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end

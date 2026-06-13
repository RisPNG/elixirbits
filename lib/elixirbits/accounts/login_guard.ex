defmodule Elixirbits.Accounts.LoginGuard do
  use GenServer

  @table __MODULE__
  @failures_per_lock 5
  @base_cooldown_seconds 5 * 60
  @sweep_interval_ms :timer.minutes(30)
  @stale_after_seconds 7 * 24 * 60 * 60

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def check(email) do
    key = email |> to_string() |> String.trim() |> String.downcase()

    case :ets.lookup(@table, key) do
      [{^key, _failures, locked_until, _updated_at}] ->
        remaining = locked_until - System.system_time(:second)
        if remaining > 0, do: {:locked, remaining}, else: :ok

      [] ->
        :ok
    end
  end

  def record_failure(email) do
    key = email |> to_string() |> String.trim() |> String.downcase()
    now = System.system_time(:second)
    failures = :ets.update_counter(@table, key, {2, 1}, {key, 0, 0, now})

    if rem(failures, @failures_per_lock) == 0 do
      cooldown =
        @base_cooldown_seconds * Integer.pow(2, div(failures, @failures_per_lock) - 1)

      :ets.insert(@table, {key, failures, now + cooldown, now})
      {:locked, cooldown}
    else
      :ets.update_element(@table, key, {4, now})
      :ok
    end
  end

  def record_success(email) do
    key = email |> to_string() |> String.trim() |> String.downcase()
    :ets.delete(@table, key)
    :ok
  end

  @impl true
  def init(_opts) do
    :ets.new(@table, [
      :named_table,
      :public,
      :set,
      read_concurrency: true,
      write_concurrency: true
    ])

    Process.send_after(self(), :sweep, @sweep_interval_ms)
    {:ok, nil}
  end

  @impl true
  def handle_info(:sweep, state) do
    now = System.system_time(:second)
    stale_cutoff = now - @stale_after_seconds

    :ets.select_delete(@table, [
      {{:_, :_, :"$1", :"$2"}, [{:<, :"$1", now}, {:<, :"$2", stale_cutoff}], [true]}
    ])

    Process.send_after(self(), :sweep, @sweep_interval_ms)
    {:noreply, state}
  end
end

defmodule Elixirbits.Numbering do
  use Ash.Domain, otp_app: :elixirbits

  alias Elixirbits.CoreUtils.Resource

  resources do
    resource Elixirbits.Numbering.NumberSequence do
      define :ensure_sequence, action: :ensure, default_options: [actor: %{system: true}]
      define :increment_sequence, action: :increment, default_options: [actor: %{system: true}]
    end
  end

  @doc """
  Allocates a running document number for a local date, such as `INV-20260618-00001`.

  A Date fixes the period directly. A DateTime is converted using the `:timezone` option, which defaults to `Etc/UTC`. Without a date, the current instant is used. Formatting accepts `:prefix`, `:suffix`, `:padding`, and `:separator`. The allocated counter cannot be overridden. Failed or canceled documents may leave gaps.
  """
  def next_number(doc_type, date_or_opts \\ [], opts \\ [])

  def next_number(doc_type, %Date{} = date, opts) do
    period_key = Date.to_iso8601(date)

    sequence =
      ensure_sequence!(%{doc_type: doc_type, period_key: period_key})
      |> increment_sequence!(%{})

    format_opts =
      [prefix: [doc_type, Calendar.strftime(date, "%Y%m%d")], padding: 5]
      |> Keyword.merge(Keyword.take(opts, [:prefix, :suffix, :padding, :separator]))
      |> Keyword.put(:start, sequence.current_value)

    Resource.next_sequence([], format_opts)
  end

  def next_number(doc_type, %DateTime{} = instant, opts) do
    date =
      instant
      |> DateTime.shift_zone!(Keyword.get(opts, :timezone, "Etc/UTC"))
      |> DateTime.to_date()

    next_number(doc_type, date, opts)
  end

  def next_number(doc_type, opts, []) when is_list(opts) do
    next_number(doc_type, DateTime.utc_now(), opts)
  end
end

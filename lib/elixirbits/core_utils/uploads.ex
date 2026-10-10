defmodule Elixirbits.CoreUtils.Upload do
  @moduledoc "Persists public LiveView uploads outside the application release."

  def consume(socket, upload_name, scope) do
    Phoenix.LiveView.consume_uploaded_entries(socket, upload_name, fn %{path: path}, entry ->
      filename = Ash.UUID.generate() <> Path.extname(entry.client_name)
      directory = Path.join(Application.fetch_env!(:elixirbits, :upload_directory), scope)
      File.mkdir_p!(directory)
      File.cp!(path, Path.join(directory, filename))
      {:ok, "/uploads/#{scope}/#{filename}"}
    end)
  end

  def delete(<<"/uploads/", path::binary>>) do
    if path != "" and Path.type(path) == :relative and
         Enum.all?(Path.split(path), &(&1 not in [".", "..", ""])) do
      path
      |> then(&Path.join(Application.fetch_env!(:elixirbits, :upload_directory), &1))
      |> File.rm()
      |> case do
        :ok -> :ok
        {:error, :enoent} -> :ok
        error -> error
      end
    else
      {:error, :invalid_path}
    end
  end

  def delete(_url), do: {:error, :invalid_path}
end

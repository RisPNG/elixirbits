defmodule Elixirbits.CoreUtils.UploadTest do
  use ExUnit.Case, async: false

  alias Elixirbits.CoreUtils.Upload

  setup do
    directory =
      Path.join(System.tmp_dir!(), "elixirbits-upload-#{System.unique_integer([:positive])}")

    public = Path.join(directory, "public")
    original = Application.fetch_env!(:elixirbits, :upload_directory)
    File.mkdir_p!(Path.join(public, "users"))
    Application.put_env(:elixirbits, :upload_directory, public)

    on_exit(fn ->
      Application.put_env(:elixirbits, :upload_directory, original)
      File.rm_rf!(directory)
    end)

    %{directory: directory, public: public}
  end

  test "deleting a stored upload and a missing upload succeeds", %{public: public} do
    path = Path.join(public, "users/avatar.png")
    File.write!(path, "avatar")
    assert :ok = Upload.delete("/uploads/users/avatar.png")
    refute File.exists?(path)
    assert :ok = Upload.delete("/uploads/users/avatar.png")
  end

  test "invalid and traversing paths cannot delete files outside the public directory", context do
    outside = Path.join(context.directory, "outside.png")
    File.write!(outside, "outside")

    for url <- [
          "/uploads/../outside.png",
          "/uploads/users/../../outside.png",
          "/uploads//#{outside}",
          "/uploads/",
          "/other/users/avatar.png",
          outside,
          nil
        ] do
      assert {:error, :invalid_path} = Upload.delete(url)
    end

    assert File.read!(outside) == "outside"
    assert File.dir?(context.public)
  end

  test "deletion preserves filesystem errors other than a missing file", %{public: public} do
    directory = Path.join(public, "users/directory")
    File.mkdir_p!(directory)
    assert {:error, reason} = Upload.delete("/uploads/users/directory")
    assert reason in [:eperm, :eisdir]
    assert File.dir?(directory)
  end
end

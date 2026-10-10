defmodule ElixirbitsWeb.Admin.UserLive.UploadsTest do
  use ElixirbitsWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Elixirbits.AccessControl.Sitenav
  alias Elixirbits.Accounts.User

  @system %{system: true}
  @portrait Base.decode64!(
              "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aRuoAAAAASUVORK5CYII="
            )

  setup %{conn: conn} do
    Ash.create!(
      Sitenav,
      %{code: "USERS", name: "Users", url: "admin/users", level: 1},
      actor: @system
    )

    directory =
      Path.join(System.tmp_dir!(), "elixirbits-avatar-#{System.unique_integer([:positive])}")

    original = Application.fetch_env!(:elixirbits, :upload_directory)
    File.mkdir_p!(Path.join(directory, "users"))
    Application.put_env(:elixirbits, :upload_directory, directory)

    on_exit(fn ->
      Application.put_env(:elixirbits, :upload_directory, original)
      File.rm_rf!(directory)
    end)

    actor = create_user(roles: ["superuser"])
    %{conn: log_in_user(conn, actor), directory: directory}
  end

  test "invalid profile submission retains its completed upload for correction", context do
    user = create_user()
    {:ok, view, _html} = live(context.conn, ~p"/admin/users/#{user.id}/update")

    upload =
      file_input(view, "#user-form", :display_pic, [
        %{name: "portrait.png", content: @portrait, type: "image/png"}
      ])

    render_upload(upload, "portrait.png")

    render_submit(view, "save", %{"form" => %{"sex" => "INVALID"}})
    assert has_element?(view, "[phx-click='cancel_upload']")
    assert File.ls!(Path.join(context.directory, "users")) == []
    assert is_nil(Ash.get!(User, user.id, actor: @system).display_pic_url)

    render_submit(view, "save", %{"form" => %{"display_name" => "Corrected"}})
    assert_redirect(view, "/admin/users")
    saved = Ash.get!(User, user.id, actor: @system)
    assert saved.display_name == "Corrected"
    assert saved.display_pic_name == "portrait.png"
    assert String.starts_with?(saved.display_pic_url, "/uploads/users/")
    assert [filename] = File.ls!(Path.join(context.directory, "users"))
    assert File.read!(Path.join([context.directory, "users", filename])) == @portrait
  end

  test "failed action removes the consumed upload and preserves the stored avatar",
       context do
    previous = Path.join(context.directory, "users/previous.png")
    File.write!(previous, "previous avatar")

    user =
      create_user(
        display_pic_url: "/uploads/users/previous.png",
        display_pic_name: "previous.png"
      )

    {:ok, view, _html} = live(context.conn, ~p"/admin/users/#{user.id}/update")

    upload =
      file_input(view, "#user-form", :display_pic, [
        %{name: "portrait.png", content: @portrait, type: "image/png"}
      ])

    render_upload(upload, "portrait.png")

    test_pid = self()
    directory = context.directory

    :sys.replace_state(view.pid, fn %{socket: socket} = state ->
      form =
        AshPhoenix.Form.for_update(socket.assigns.user, :update,
          actor: socket.assigns.current_user,
          forms: [auto?: true],
          prepare_source: fn source ->
            Ash.Changeset.before_action(source, fn changeset ->
              url = Ash.Changeset.get_attribute(changeset, :display_pic_url)
              stored_path = Path.join(directory, String.replace_prefix(url, "/uploads/", ""))
              send(test_pid, {:upload_persisted_before_failure, url, File.exists?(stored_path)})

              Ash.Changeset.add_error(changeset,
                field: :display_name,
                message: "save rejected after upload storage"
              )
            end)
          end
        )

      %{state | socket: Phoenix.Component.assign(socket, :form, Phoenix.Component.to_form(form))}
    end)

    html =
      view |> form("#user-form", form: %{display_name: "Attempted update"}) |> render_submit()

    assert_receive {:upload_persisted_before_failure, "/uploads/users/" <> filename, true}
    assert html =~ "save rejected after upload storage"
    refute File.exists?(Path.join([directory, "users", filename]))
    refute has_element?(view, "[phx-click='cancel_upload']")

    assert has_element?(view, "#user-form")
    saved = Ash.get!(User, user.id, actor: @system)
    assert saved.display_pic_url == "/uploads/users/previous.png"
    assert saved.display_name != "Attempted update"
    assert File.ls!(Path.join(context.directory, "users")) == ["previous.png"]
    assert File.read!(previous) == "previous avatar"
  end

  test "a successful avatar replacement deletes the previous stored file", context do
    previous = Path.join(context.directory, "users/previous.png")
    File.write!(previous, "previous avatar")

    user =
      create_user(
        display_pic_url: "/uploads/users/previous.png",
        display_pic_name: "previous.png"
      )

    {:ok, view, _html} = live(context.conn, ~p"/admin/users/#{user.id}/update")

    upload =
      file_input(view, "#user-form", :display_pic, [
        %{name: "portrait.png", content: @portrait, type: "image/png"}
      ])

    render_upload(upload, "portrait.png")

    view |> form("#user-form") |> render_submit()
    assert_redirect(view, "/admin/users")
    refute File.exists?(previous)
    saved = Ash.get!(User, user.id, actor: @system)
    assert saved.display_pic_url != "/uploads/users/previous.png"
    assert [_filename] = File.ls!(Path.join(context.directory, "users"))
  end
end

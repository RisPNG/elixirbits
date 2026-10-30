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

  test "profile pictures use a square editor and restore the saved preview after canceling",
       context do
    user =
      create_user(
        display_pic_url: "/uploads/users/previous.png",
        display_pic_name: "previous.png"
      )

    {:ok, view, html} = live(context.conn, ~p"/admin/users/#{user.id}/update")
    document = Floki.parse_document!(html)

    assert has_element?(view, "#user-profile-picture-preview.size-32")
    assert Floki.text(Floki.find(document, "#user-form label")) =~ "Profile Picture"

    [editor] = Floki.attribute(document, "#user-form [phx-hook=FileInput]", "data-file-editor")
    assert Jason.decode!(editor) == %{"width" => 128, "height" => 128}

    [accept] = Floki.attribute(document, "#user-form input[type=file]", "accept")
    assert MapSet.new(String.split(accept, ",")) == MapSet.new(~w(.jpg .jpeg .png .gif .webp))

    [tooltip] =
      Floki.attribute(
        document,
        "#user-form [aria-label='Supported profile picture formats']",
        "data-tooltip"
      )

    for extension <- ~w(.jpg .jpeg .png .gif .webp),
        do: assert(String.downcase(tooltip) =~ extension)

    preview =
      view
      |> element("#user-form template[data-phx-portal]")
      |> render()
      |> Floki.parse_document!()

    assert Floki.find(
             preview,
             "[data-file-item]:not([hidden]) img[src='/uploads/users/previous.png']"
           ) != []

    upload =
      file_input(view, "#user-form", :display_pic, [
        %{name: "portrait.png", content: @portrait, type: "image/png"}
      ])

    render_upload(upload, "portrait.png")

    preview =
      view
      |> element("#user-form template[data-phx-portal]")
      |> render()
      |> Floki.parse_document!()

    assert Floki.find(preview, "[data-file-entry-ref]:not([hidden]) img") != []

    assert Floki.find(preview, "[data-file-item][hidden] img[src='/uploads/users/previous.png']") !=
             []

    view |> element("#user-profile-picture-cancel") |> render_click()

    preview =
      view
      |> element("#user-form template[data-phx-portal]")
      |> render()
      |> Floki.parse_document!()

    assert Floki.find(
             preview,
             "[data-file-item]:not([hidden]) img[src='/uploads/users/previous.png']"
           ) != []

    assert Floki.find(preview, "[data-file-entry-ref]") == []

    assert Ash.get!(User, user.id, actor: @system).display_pic_url ==
             "/uploads/users/previous.png"
  end

  test "removing the saved profile picture clears its preview and deletes the file after saving",
       context do
    previous = Path.join(context.directory, "users/previous.png")
    File.write!(previous, @portrait)

    user =
      create_user(
        display_pic_url: "/uploads/users/previous.png",
        display_pic_name: "previous.png"
      )

    {:ok, view, _html} = live(context.conn, ~p"/admin/users/#{user.id}/update")

    view |> element("#user-profile-picture-remove") |> render_click()

    preview =
      view
      |> element("#user-form template[data-phx-portal]")
      |> render()
      |> Floki.parse_document!()

    assert Floki.find(preview, "img") == []
    assert has_element?(view, "[aria-label='No profile picture']")
    assert has_element?(view, "#user-profile-picture-remove[disabled]")
    assert File.exists?(previous)

    view |> form("#user-form") |> render_submit()
    assert_redirect(view, "/admin/users")
    saved = Ash.get!(User, user.id, actor: @system)
    assert is_nil(saved.display_pic_url)
    assert is_nil(saved.display_pic_name)
    refute File.exists?(previous)
  end

  test "accepted GIF and WebP uploads retain their file type and bytes in storage", context do
    for {name, type, content} <- [
          {"portrait.gif", "image/gif",
           Base.decode64!("R0lGODlhAQABAIAAAP///wAAACH5BAEAAAAALAAAAAABAAEAAAICRAEAOw==")},
          {"portrait.webp", "image/webp",
           Base.decode64!("UklGRh4AAABXRUJQVlA4TBEAAAAvAAAAAAfQ//73v/+BiOh/AAA=")}
        ] do
      user = create_user()
      {:ok, view, _html} = live(context.conn, ~p"/admin/users/#{user.id}/update")
      assert has_element?(view, "[aria-label='No profile picture']")
      assert has_element?(view, "#user-profile-picture-picker", "Upload picture")

      upload =
        file_input(view, "#user-form", :display_pic, [%{name: name, content: content, type: type}])

      render_upload(upload, name)
      refute has_element?(view, "[aria-label='No profile picture']")
      assert has_element?(view, "#user-profile-picture-picker", "Change picture")

      preview =
        view
        |> element("#user-form template[data-phx-portal]")
        |> render()
        |> Floki.parse_document!()

      assert Floki.find(preview, "[data-file-entry-ref][data-file-content-type='#{type}'] img") !=
               []

      view |> form("#user-form") |> render_submit()
      assert_redirect(view, "/admin/users")
      saved = Ash.get!(User, user.id, actor: @system)
      assert saved.display_pic_name == name
      assert Path.extname(saved.display_pic_url) == Path.extname(name)

      stored_path =
        Path.join(
          context.directory,
          String.replace_prefix(saved.display_pic_url, "/uploads/", "")
        )

      assert File.read!(stored_path) == content
    end
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

    preview =
      view
      |> element("#user-form template[data-phx-portal]")
      |> render()
      |> Floki.parse_document!()

    assert Floki.find(preview, "[phx-click='cancel_upload']") != []
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

    preview =
      view
      |> element("#user-form template[data-phx-portal]")
      |> render()
      |> Floki.parse_document!()

    assert Floki.find(preview, "[phx-click='cancel_upload']") == []

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

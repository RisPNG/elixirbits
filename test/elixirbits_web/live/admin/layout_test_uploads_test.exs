defmodule ElixirbitsWeb.Admin.LayoutTestLive.UploadsTest do
  use ElixirbitsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  @image Base.decode64!(
           "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aRuoAAAAASUVORK5CYII="
         )
  @pdf "%PDF-1.4\n1 0 obj\n<< /Type /Catalog >>\nendobj\n%%EOF"

  test "shows independent filename and content preview inputs", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/dev_panel/layout_test")

    assert has_element?(
             view,
             "#layout-test-upload-tags input[type=file][name=demo_files]"
           )

    assert has_element?(
             view,
             "#layout-test-upload-previews input[type=file][name=demo_previews]"
           )

    assert has_element?(view, "#layout-test-upload-tags", "logo.svg")
    assert has_element?(view, "#layout-test-upload-previews img[src='/images/logo.svg']")
  end

  test "finishing both uploads retains filename chips and image or PDF contents", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/dev_panel/layout_test")

    files =
      file_input(view, "#layout-test-upload-form", :demo_files, [
        %{name: "notes.txt", content: "Upload notes", type: "text/plain"}
      ])

    previews =
      file_input(view, "#layout-test-upload-form", :demo_previews, [
        %{name: "portrait.png", content: @image, type: "image/png"},
        %{name: "document.pdf", content: @pdf, type: "application/pdf"}
      ])

    render_upload(files, "notes.txt")
    render_upload(previews, "portrait.png")
    render_upload(previews, "document.pdf")

    assert has_element?(
             view,
             "#layout-test-upload-previews img[data-phx-hook='Phoenix.LiveImgPreview'][alt='portrait.png']"
           )

    assert has_element?(
             view,
             "#layout-test-upload-previews [phx-hook=UploadPdfPreview][aria-label='First page of document.pdf'] canvas"
           )

    render_submit(form(view, "#layout-test-upload-form"))

    assert has_element?(view, "#uploaded-names", "notes.txt")
    assert has_element?(view, "#uploaded-names", "portrait.png")
    assert has_element?(view, "#uploaded-names", "document.pdf")
    assert has_element?(view, "#layout-test-upload-tags", "notes.txt")

    assert has_element?(
             view,
             "#layout-test-upload-previews img[src='data:image/png;base64,#{Base.encode64(@image)}']"
           )

    assert has_element?(
             view,
             "#layout-test-upload-previews [data-pdf-url='data:application/pdf;base64,#{Base.encode64(@pdf)}'] canvas"
           )

    refute has_element?(view, "#layout-test-uploads button[phx-click=cancel_upload]")

    render_click(
      element(
        view,
        "#layout-test-upload-previews button[phx-click=remove_upload][phx-value-url='data:application/pdf;base64,#{Base.encode64(@pdf)}']"
      )
    )

    refute has_element?(view, "#layout-test-upload-previews [phx-hook=UploadPdfPreview]")
    assert has_element?(view, "#layout-test-upload-previews img[alt='portrait.png']")
    assert has_element?(view, "#layout-test-upload-tags", "notes.txt")
  end

  test "cancellation selects the matching input and read-only mode preserves previews", %{
    conn: conn
  } do
    {:ok, view, _html} = live(conn, ~p"/dev_panel/layout_test")

    files =
      file_input(view, "#layout-test-upload-form", :demo_files, [
        %{name: "notes.txt", content: "Upload notes", type: "text/plain"}
      ])

    previews =
      file_input(view, "#layout-test-upload-form", :demo_previews, [
        %{name: "portrait.png", content: @image, type: "image/png"}
      ])

    render_upload(files, "notes.txt")
    render_upload(previews, "portrait.png")

    render_click(element(view, "#upload-mode-disabled"))
    refute has_element?(view, "#layout-test-uploads input[type=file]:not([disabled])")
    assert has_element?(view, "#layout-test-upload-tags label.hidden input[type=file][disabled]")

    assert has_element?(
             view,
             "#layout-test-upload-previews label.hidden input[type=file][disabled]"
           )

    refute has_element?(view, "#layout-test-uploads button[phx-click=cancel_upload]")
    refute has_element?(view, "#layout-test-uploads button[phx-click=remove_upload]")
    assert has_element?(view, "#layout-test-upload-tags", "notes.txt")
    assert has_element?(view, "#layout-test-upload-previews img[alt='portrait.png']")

    render_click(element(view, "#upload-mode-enabled"))
    render_click(element(view, "#layout-test-upload-previews button[phx-click=cancel_upload]"))

    refute has_element?(view, "#layout-test-upload-previews img[alt='portrait.png']")
    assert has_element?(view, "#layout-test-upload-tags button[phx-click=cancel_upload]")

    render_click(element(view, "#layout-test-upload-tags button[phx-click=cancel_upload]"))
    refute has_element?(view, "#layout-test-uploads button[phx-click=cancel_upload]")
  end

  test "both preview styles expose every core render mode", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/dev_panel/layout_test")

    modes =
      ElixirbitsWeb.CoreComponents.__components__().input.attrs
      |> Enum.find(&(&1.name == :render_as))
      |> Map.fetch!(:opts)
      |> Keyword.fetch!(:values)

    for mode <- modes do
      render_click(element(view, "#upload-mode-#{mode}"))
      assert has_element?(view, "#upload-mode-#{mode}[aria-pressed=true]")

      for section <- ~w(tags previews) do
        assert has_element?(view, "#layout-test-upload-#{section} input[type=file]")
      end

      if mode in ~w(enabled hidden hidden-enabled) do
        assert has_element?(view, "#layout-test-uploads input[type=file]:not([disabled])")
      else
        refute has_element?(view, "#layout-test-uploads input[type=file]:not([disabled])")
      end
    end
  end

  test "hidden-disabled preserves incomplete image and PDF uploads until they finish", %{
    conn: conn
  } do
    {:ok, view, _html} = live(conn, ~p"/dev_panel/layout_test")
    image = @image <> :binary.copy(<<0>>, 100 - byte_size(@image))
    pdf = @pdf <> :binary.copy("\n", 100 - byte_size(@pdf))

    previews =
      file_input(view, "#layout-test-upload-form", :demo_previews, [
        %{name: "portrait.png", content: image, type: "image/png"},
        %{name: "document.pdf", content: pdf, type: "application/pdf"}
      ])

    render_upload(previews, "portrait.png", 25)
    render_upload(previews, "document.pdf", 25)
    document = view |> render() |> Floki.parse_document!()
    input_selector = "#layout-test-upload-previews input[name=demo_previews]"
    [upload_id] = Floki.attribute(document, input_selector, "id")
    [active_refs] = Floki.attribute(document, input_selector, "data-phx-active-refs")

    [pdf_id] =
      Floki.attribute(document, "#layout-test-upload-previews [phx-hook=UploadPdfPreview]", "id")

    render_click(element(view, "#upload-mode-hidden-disabled"))

    assert has_element?(
             view,
             "#layout-test-upload-previews div.hidden input##{upload_id}[disabled]"
           )

    assert Floki.attribute(
             view |> render() |> Floki.parse_document!(),
             input_selector,
             "data-phx-active-refs"
           ) == [active_refs]

    assert has_element?(
             view,
             "#layout-test-upload-previews div.hidden img[data-phx-hook='Phoenix.LiveImgPreview'][alt='portrait.png']"
           )

    assert has_element?(view, "div.hidden ##{pdf_id} canvas")
    refute has_element?(view, "#layout-test-upload-previews button[phx-click=cancel_upload]")

    render_click(element(view, "#upload-mode-enabled"))
    assert has_element?(view, "#layout-test-upload-previews input##{upload_id}:not([disabled])")
    assert has_element?(view, "##{pdf_id} canvas")
    render_upload(previews, "portrait.png", 75)
    render_upload(previews, "document.pdf", 75)
    render_submit(form(view, "#layout-test-upload-form"))

    assert has_element?(
             view,
             "#layout-test-upload-previews img[src='data:image/png;base64,#{Base.encode64(image)}']"
           )

    assert has_element?(
             view,
             "#layout-test-upload-previews [data-pdf-url='data:application/pdf;base64,#{Base.encode64(pdf)}'] canvas"
           )
  end

  test "upload states and preview layouts preserve pending files", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/dev_panel/layout_test")

    previews =
      file_input(view, "#layout-test-upload-form", :demo_previews, [
        %{name: "portrait.png", content: @image, type: "image/png"},
        %{name: "document.pdf", content: @pdf, type: "application/pdf"}
      ])

    render_upload(previews, "portrait.png")
    render_upload(previews, "document.pdf")

    pdf_preview =
      view
      |> render()
      |> Floki.parse_document!()
      |> Floki.find("#layout-test-upload-previews [phx-hook=UploadPdfPreview]")
      |> Floki.attribute("id")
      |> hd()

    render_click(element(view, "#upload-preview-tag"))

    assert has_element?(view, "#upload-preview-tag[aria-pressed=true]")
    assert has_element?(view, "#layout-test-upload-previews .hidden img[alt='portrait.png']")
    assert has_element?(view, "##{pdf_preview} canvas")

    assert has_element?(
             view,
             "#layout-test-upload-previews button[aria-label='Cancel document.pdf']"
           )

    render_click(element(view, "#showcase-uploads-disabled"))
    render_click(element(view, "#showcase-uploads-required"))
    render_click(element(view, "#showcase-uploads-labels"))
    render_click(element(view, "#showcase-uploads-tooltip"))
    render_click(element(view, "#showcase-uploads-errors"))
    render_click(element(view, "#showcase-uploads-stored"))

    for name <- ~w(demo_files demo_previews) do
      assert has_element?(view, "#layout-test-uploads input[name=#{name}][disabled][required]")
    end

    refute has_element?(view, "#layout-test-upload-tags .input-floating-label", "Files")
    assert has_element?(view, "#layout-test-upload-previews [data-tooltip]")
    assert has_element?(view, "#layout-test-upload-tags", "Choose a supported file.")
    assert has_element?(view, "#layout-test-upload-previews", "Choose an image or PDF.")
    refute has_element?(view, "#layout-test-upload-previews img[src='/images/logo.svg']")
    assert has_element?(view, "##{pdf_preview} canvas")

    render_click(element(view, "#showcase-uploads-disabled"))
    render_click(element(view, "#showcase-uploads-required"))
    render_click(element(view, "#showcase-uploads-stored"))
    render_click(element(view, "#upload-preview-thumbnail"))
    assert has_element?(view, "#layout-test-upload-previews img[src='/images/logo.svg']")
    assert has_element?(view, "##{pdf_preview} canvas")

    render_submit(form(view, "#layout-test-upload-form"))

    assert has_element?(
             view,
             "#layout-test-upload-previews img[src='data:image/png;base64,#{Base.encode64(@image)}']"
           )

    assert has_element?(
             view,
             "#layout-test-upload-previews [data-pdf-url='data:application/pdf;base64,#{Base.encode64(@pdf)}'] canvas"
           )
  end
end

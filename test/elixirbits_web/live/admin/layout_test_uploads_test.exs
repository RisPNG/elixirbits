defmodule ElixirbitsWeb.Admin.LayoutTestLive.UploadsTest do
  use ElixirbitsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  @image Base.decode64!(
           "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aRuoAAAAASUVORK5CYII="
         )
  @pdf "%PDF-1.4\n1 0 obj\n<< /Type /Catalog >>\nendobj\n%%EOF"

  test "one upload input starts with a single selection and a saved image preview", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/dev_panel/layout_test")

    assert has_element?(
             view,
             "#layout-test-upload-input input[type=file][name=demo_files]:not([multiple])"
           )

    assert has_element?(
             view,
             "#layout-test-upload-input [phx-hook=FileInput][data-file-selection=single][data-file-preview=true][data-file-editor=false]"
           )

    assert has_element?(view, "#layout-test-upload-preview")
    refute has_element?(view, "#layout-test-upload-form #layout-test-upload-preview")

    portal =
      view
      |> element("#layout-test-upload-input template[data-phx-portal]")
      |> render()
      |> Floki.parse_document!()

    assert Floki.attribute(portal, "template", "data-phx-portal") == [
             ~s([id="layout-test-upload-preview"])
           ]

    refute has_element?(view, "#layout-test-upload-input img")
    assert Floki.find(preview_document(view), "img[src='/images/logo.svg']") != []
    assert has_element?(view, "#upload-selection-single[aria-pressed=true]")
    refute has_element?(view, "#upload-editor-true[disabled]")

    document = view |> render() |> Floki.parse_document!()
    assert length(Floki.find(document, "#layout-test-upload-form input[type=file]")) == 1

    [accept] =
      Floki.attribute(document, "#layout-test-upload-input input[type=file]", "accept")

    assert MapSet.new(String.split(accept, ",")) ==
             MapSet.new(~w(.png .jpg .jpeg .gif .webp .pdf .txt))
  end

  test "editor constraints require preview and reset when previews are turned off", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/dev_panel/layout_test")

    for {choice, editor} <- [
          {"false", false},
          {"true", true},
          {"exact", %{"width" => 512, "height" => 512}},
          {"ratio", %{"ratio" => 16 / 9}}
        ] do
      render_click(element(view, "#upload-editor-#{choice}"))
      assert has_element?(view, "#upload-editor-#{choice}[aria-pressed=true]")

      [constraint] =
        view
        |> render()
        |> Floki.parse_document!()
        |> Floki.attribute("#layout-test-upload-input [phx-hook=FileInput]", "data-file-editor")

      assert Jason.decode!(constraint) == editor
      assert has_element?(view, "#layout-test-upload-input [data-file-preview=true]")
    end

    render_click(element(view, "#showcase-uploads-preview"))
    assert has_element?(view, "#layout-test-upload-input [data-file-preview=false]")
    assert has_element?(view, "#layout-test-upload-input [data-file-editor=false]")
    assert has_element?(view, "#upload-editor-false[aria-pressed=true]")

    for choice <- ~w(false true exact ratio) do
      assert has_element?(view, "#upload-editor-#{choice}[disabled]")
    end

    render_click(view, "set_showcase_option", %{
      "section" => "uploads",
      "option" => "editor",
      "choice" => "true"
    })

    assert has_element?(view, "#layout-test-upload-input [data-file-editor=false]")
    assert has_element?(view, "#upload-editor-false[aria-pressed=true]")
    render_click(element(view, "#showcase-uploads-preview"))

    for choice <- ~w(false true exact ratio) do
      refute has_element?(view, "#upload-editor-#{choice}[disabled]")
    end

    assert has_element?(view, "#layout-test-upload-input [data-file-editor=false]")
    render_click(element(view, "#upload-editor-exact"))
    assert has_element?(view, "#upload-editor-exact[aria-pressed=true]")
  end

  test "multiple selection resets editing and enables it again after returning to single", %{
    conn: conn
  } do
    {:ok, view, _html} = live(conn, ~p"/dev_panel/layout_test")
    render_click(element(view, "#upload-editor-exact"))
    render_click(element(view, "#upload-selection-multiple"))

    assert has_element?(view, "#upload-selection-multiple[aria-pressed=true]")
    assert has_element?(view, "#layout-test-upload-input input[type=file][multiple]")

    assert has_element?(
             view,
             "#layout-test-upload-input [data-file-selection=multiple][data-file-editor=false]"
           )

    for choice <- ~w(false true exact ratio) do
      assert has_element?(view, "#upload-editor-#{choice}[disabled]")
    end

    render_click(view, "set_showcase_option", %{
      "section" => "uploads",
      "option" => "editor",
      "choice" => "exact"
    })

    assert has_element?(view, "#layout-test-upload-input [data-file-editor=false]")
    assert has_element?(view, "#upload-editor-false[aria-pressed=true]")
    render_click(element(view, "#upload-selection-single"))
    assert has_element?(view, "#layout-test-upload-input input[type=file]:not([multiple])")

    for choice <- ~w(false true exact ratio) do
      refute has_element?(view, "#upload-editor-#{choice}[disabled]")
    end

    assert has_element?(view, "#upload-editor-false[aria-pressed=true]")
  end

  test "singles selection accepts one file at a time and keeps editing and cycling available", %{
    conn: conn
  } do
    {:ok, view, _html} = live(conn, ~p"/dev_panel/layout_test")
    render_click(element(view, "#upload-selection-singles"))
    render_click(element(view, "#upload-editor-true"))

    assert has_element?(view, "#upload-selection-singles[aria-pressed=true]")
    assert has_element?(view, "#layout-test-upload-input [data-file-selection=singles]")
    assert has_element?(view, "#layout-test-upload-input input[type=file]:not([multiple])")
    assert has_element?(view, "#layout-test-upload-input [data-file-editor=true]")

    for {name, type, content} <- [
          {"portrait.png", "image/png", @image},
          {"document.pdf", "application/pdf", @pdf},
          {"notes.txt", "text/plain", "Upload notes"}
        ] do
      upload =
        file_input(view, "#layout-test-upload-form", :demo_files, [
          %{name: name, content: content, type: type}
        ])

      render_upload(upload, name)
      assert Floki.find(preview_document(view), "button[aria-label='Cancel #{name}']") != []
      assert has_element?(view, "#layout-test-upload-input input[type=file]:not([multiple])")
      assert has_element?(view, "#upload-editor-true[aria-pressed=true]:not([disabled])")
    end

    assert Floki.find(preview_document(view), "[data-file-cycle=previous]") != []
    assert Floki.find(preview_document(view), "[data-file-cycle=next]") != []
    assert Floki.find(preview_document(view), "img[src='/images/logo.svg']") != []
    render_submit(form(view, "#layout-test-upload-form"))

    for name <- ~w(portrait.png document.pdf notes.txt) do
      assert has_element?(view, "#uploaded-names", name)
      assert Floki.text(preview_document(view)) =~ name
    end

    document = view |> render() |> Floki.parse_document!()
    assert length(Floki.find(document, "#layout-test-upload-form input[type=file]")) == 1

    assert length(Floki.find(preview_document(view), "[data-file-item][data-file-url]")) == 4

    assert Floki.find(preview_document(view), "button[phx-click=cancel_upload]") == []
    assert Floki.find(preview_document(view), "[data-file-cycle=next]") != []
  end

  test "a saved image edit replaces its URL while cancellation retains every saved file", %{
    conn: conn
  } do
    {:ok, view, _html} = live(conn, ~p"/dev_panel/layout_test")

    image =
      file_input(view, "#layout-test-upload-form", :demo_files, [
        %{name: "portrait.png", content: @image, type: "image/png"}
      ])

    render_upload(image, "portrait.png")
    render_submit(form(view, "#layout-test-upload-form"))
    render_click(element(view, "#upload-selection-singles"))
    render_click(element(view, "#upload-editor-exact"))

    pdf =
      file_input(view, "#layout-test-upload-form", :demo_files, [
        %{name: "document.pdf", content: @pdf, type: "application/pdf"}
      ])

    render_upload(pdf, "document.pdf")
    render_submit(form(view, "#layout-test-upload-form"))
    image_url = "data:image/png;base64,#{Base.encode64(@image)}"
    pdf_url = "data:application/pdf;base64,#{Base.encode64(@pdf)}"

    assert Floki.find(
             preview_document(view),
             "[data-file-url='#{image_url}'] button[data-file-edit]"
           ) != []

    assert Floki.find(
             preview_document(view),
             "[data-file-url='#{pdf_url}'] button[data-file-edit]"
           ) == []

    assert has_element?(view, "#layout-test-upload-input [data-file-replacements]")
    edited_image = @image <> <<0>>

    cancelled =
      file_input(view, "#layout-test-upload-form", :demo_files, [
        %{name: "portrait.png", content: edited_image, type: "image/png"}
      ])

    render_upload(cancelled, "portrait.png")

    [cancelled_ref] =
      Floki.attribute(preview_document(view), "button[phx-click=cancel_upload]", "phx-value-ref")

    render_click(view, "cancel_upload", %{"ref" => cancelled_ref})
    assert Floki.find(preview_document(view), "img[src='#{image_url}']") != []
    assert Floki.find(preview_document(view), "[data-pdf-url='#{pdf_url}']") != []

    replacement =
      file_input(view, "#layout-test-upload-form", :demo_files, [
        %{name: "portrait.png", content: edited_image, type: "image/png"}
      ])

    document = replacement |> render_upload("portrait.png") |> Floki.parse_document!()

    [entry_ref] =
      Floki.attribute(
        document,
        "#layout-test-upload-input input[type=file]",
        "data-phx-active-refs"
      )

    render_submit(view, "upload_save", %{
      "demo_files_replacements" => %{entry_ref => image_url}
    })

    edited_url = "data:image/png;base64,#{Base.encode64(edited_image)}"
    assert Floki.find(preview_document(view), "img[src='#{image_url}']") == []
    assert Floki.find(preview_document(view), "img[src='#{edited_url}']") != []
    assert Floki.find(preview_document(view), "[data-pdf-url='#{pdf_url}']") != []
    assert Floki.text(preview_document(view)) =~ "portrait.png"
    assert Floki.text(preview_document(view)) =~ "document.pdf"
    assert Floki.find(preview_document(view), "button[phx-click=cancel_upload]") == []

    assert Floki.attribute(preview_document(view), "[data-file-item]", "data-file-url") ==
             [edited_url, pdf_url]
  end

  test "re-editing the first pending file retains its order when the queue is saved", %{
    conn: conn
  } do
    {:ok, view, _html} = live(conn, ~p"/dev_panel/layout_test")
    render_click(element(view, "#upload-selection-singles"))

    image =
      file_input(view, "#layout-test-upload-form", :demo_files, [
        %{name: "portrait.png", content: @image, type: "image/png"}
      ])

    render_upload(image, "portrait.png")

    pdf =
      file_input(view, "#layout-test-upload-form", :demo_files, [
        %{name: "document.pdf", content: @pdf, type: "application/pdf"}
      ])

    render_upload(pdf, "document.pdf")

    [pdf_ref] =
      Floki.attribute(
        preview_document(view),
        "button[aria-label='Cancel document.pdf']",
        "phx-value-ref"
      )

    [old_image_ref] =
      Floki.attribute(
        preview_document(view),
        "button[aria-label='Cancel portrait.png']",
        "phx-value-ref"
      )

    render_click(view, "cancel_upload", %{"ref" => old_image_ref})

    edited_image = @image <> <<0>>

    replacement =
      file_input(view, "#layout-test-upload-form", :demo_files, [
        %{name: "portrait.png", content: edited_image, type: "image/png"}
      ])

    render_upload(replacement, "portrait.png")

    [image_ref] =
      Floki.attribute(
        preview_document(view),
        "button[aria-label='Cancel portrait.png']",
        "phx-value-ref"
      )

    render_submit(view, "upload_save", %{"demo_files_order" => [image_ref, pdf_ref]})

    assert Floki.attribute(preview_document(view), "[data-file-item]", "data-file-key") ==
             [
               "/images/logo.svg",
               "data:image/png;base64,#{Base.encode64(edited_image)}",
               "data:application/pdf;base64,#{Base.encode64(@pdf)}"
             ]

    assert has_element?(view, "#uploaded-names", "portrait.png, document.pdf")
    assert Floki.find(preview_document(view), "button[phx-click=cancel_upload]") == []
  end

  test "single without preview shows its filename in the picker and preserves pending media", %{
    conn: conn
  } do
    {:ok, view, _html} = live(conn, ~p"/dev_panel/layout_test")
    render_click(element(view, "#showcase-uploads-preview"))
    assert has_element?(view, "#layout-test-upload-input [data-file-name]", "logo.svg")
    assert Floki.find(preview_document(view), "[data-file-collection][hidden]") != []
    refute has_element?(view, "#layout-test-upload-input [data-file-position]")

    upload =
      file_input(view, "#layout-test-upload-form", :demo_files, [
        %{name: "portrait.png", content: @image, type: "image/png"}
      ])

    document = upload |> render_upload("portrait.png") |> Floki.parse_document!()

    [input_id] = Floki.attribute(document, "#layout-test-upload-input input[type=file]", "id")

    [entry_ref] =
      Floki.attribute(
        document,
        "#layout-test-upload-input input[type=file]",
        "data-phx-active-refs"
      )

    assert has_element?(view, "#layout-test-upload-input [data-file-name]", "portrait.png")

    assert has_element?(
             view,
             "#layout-test-upload-input [data-file-control] button[data-file-clear]:not([disabled])"
           )

    assert Floki.find(
             preview_document(view),
             "[data-file-collection][hidden] [data-file-entry-ref='#{entry_ref}'] img[alt='portrait.png']"
           ) != []

    render_click(element(view, "#upload-mode-text-disabled"))

    assert has_element?(view, "#layout-test-upload-input [data-file-name]", "portrait.png")

    assert has_element?(
             view,
             "#layout-test-upload-input input[id='#{input_id}'][disabled][data-phx-active-refs='#{entry_ref}']"
           )

    render_click(element(view, "#upload-mode-enabled"))
    render_click(element(view, "#showcase-uploads-preview"))
    render_click(element(view, "#upload-preview-thumbnail"))

    assert Floki.find(preview_document(view), "[data-file-collection]:not([hidden])") != []
    assert Floki.find(preview_document(view), "img[alt='portrait.png']") != []

    assert has_element?(
             view,
             "#layout-test-upload-input input[id='#{input_id}'][data-phx-active-refs='#{entry_ref}']"
           )

    render_click(element(view, "#showcase-uploads-preview"))
    render_click(view, "cancel_upload", %{"ref" => entry_ref})
    assert has_element?(view, "#layout-test-upload-input [data-file-name]", "logo.svg")
    assert Floki.find(preview_document(view), "[data-file-collection][hidden]") != []
    assert Floki.find(preview_document(view), "button[phx-click=cancel_upload]") == []
  end

  test "singles filename mode retains saved names, positions, and parked native PDF viewers", %{
    conn: conn
  } do
    {:ok, view, _html} = live(conn, ~p"/dev_panel/layout_test")

    image =
      file_input(view, "#layout-test-upload-form", :demo_files, [
        %{name: "portrait.png", content: @image, type: "image/png"}
      ])

    render_upload(image, "portrait.png")
    render_submit(form(view, "#layout-test-upload-form"))
    render_click(element(view, "#upload-selection-singles"))

    pdf =
      file_input(view, "#layout-test-upload-form", :demo_files, [
        %{name: "document.pdf", content: @pdf, type: "application/pdf"}
      ])

    render_upload(pdf, "document.pdf")
    render_submit(form(view, "#layout-test-upload-form"))
    assert has_element?(view, "#layout-test-upload-input [data-file-name]", "2 files")
    assert Floki.text(Floki.find(preview_document(view), "[data-file-preview-position]")) == "1/2"

    render_click(element(view, "#showcase-uploads-preview"))
    assert has_element?(view, "#layout-test-upload-input [data-file-name]", "portrait.png")
    assert Floki.find(preview_document(view), "[data-file-collection][hidden]") != []
    assert has_element?(view, "#layout-test-upload-input [data-file-position]", "1/2")

    for direction <- ~w(previous next) do
      assert has_element?(view, "#layout-test-upload-input [data-file-cycle-input=#{direction}]")
    end

    image_url = "data:image/png;base64,#{Base.encode64(@image)}"
    pdf_url = "data:application/pdf;base64,#{Base.encode64(@pdf)}"

    assert Floki.text(
             Floki.find(
               preview_document(view),
               "[data-file-collection][hidden] [data-file-url='#{image_url}'] [data-file-filename]"
             )
           ) =~ "portrait.png"

    assert Floki.text(
             Floki.find(
               preview_document(view),
               "[data-file-collection][hidden] [data-file-url='#{pdf_url}'] [data-file-filename]"
             )
           ) =~ "document.pdf"

    assert Floki.find(
             preview_document(view),
             "[data-file-collection][hidden] [data-pdf-url='#{pdf_url}'] iframe[data-pdf-viewer]"
           ) != []

    render_click(element(view, "#showcase-uploads-stored"))
    assert has_element?(view, "#layout-test-upload-input [data-file-name]", "Choose a file")
    assert has_element?(view, "#layout-test-upload-input [data-file-position]", "0/0")
    render_click(element(view, "#showcase-uploads-stored"))
    assert has_element?(view, "#layout-test-upload-input [data-file-name]", "portrait.png")
    assert has_element?(view, "#layout-test-upload-input [data-file-position]", "1/2")

    render_click(element(view, "#upload-mode-disabled"))
    assert has_element?(view, "#layout-test-upload-input [data-file-name]", "portrait.png")
    assert has_element?(view, "#layout-test-upload-input [data-file-position]", "1/2")
    render_click(element(view, "#upload-mode-enabled"))
    render_click(element(view, "#showcase-uploads-preview"))
    assert has_element?(view, "#layout-test-upload-input [data-file-name]", "2 files")
    assert Floki.find(preview_document(view), "[data-file-collection]:not([hidden])") != []
    assert Floki.text(Floki.find(preview_document(view), "[data-file-preview-position]")) == "1/2"
    assert Floki.find(preview_document(view), "[data-pdf-url='#{pdf_url}'] iframe") != []
  end

  test "cancelling a single replacement restores its mounted saved preview", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/dev_panel/layout_test")

    upload =
      file_input(view, "#layout-test-upload-form", :demo_files, [
        %{name: "portrait.png", content: @image, type: "image/png"}
      ])

    render_upload(upload, "portrait.png")
    assert Floki.find(preview_document(view), "[data-file-stored].hidden") != []
    assert Floki.find(preview_document(view), "img[src='/images/logo.svg']") != []
    assert Floki.find(preview_document(view), "img[alt='portrait.png']") != []
    refute has_element?(view, "#uploaded-names")

    [entry_ref] =
      Floki.attribute(preview_document(view), "button[phx-click=cancel_upload]", "phx-value-ref")

    render_click(view, "cancel_upload", %{"ref" => entry_ref})

    assert Floki.find(preview_document(view), "[data-file-stored]:not(.hidden)") != []
    assert Floki.find(preview_document(view), "img[src='/images/logo.svg']") != []
    assert Floki.find(preview_document(view), "img[alt='portrait.png']") == []
    assert Floki.find(preview_document(view), "button[phx-click=cancel_upload]") == []
  end

  test "saving a single image then PDF replaces saved media and retains its caption", %{
    conn: conn
  } do
    {:ok, view, _html} = live(conn, ~p"/dev_panel/layout_test")

    image =
      file_input(view, "#layout-test-upload-form", :demo_files, [
        %{name: "portrait.png", content: @image, type: "image/png"}
      ])

    render_upload(image, "portrait.png")
    render_submit(form(view, "#layout-test-upload-form"))
    image_url = "data:image/png;base64,#{Base.encode64(@image)}"
    assert Floki.find(preview_document(view), "img[src='#{image_url}']") != []
    assert Floki.text(preview_document(view)) =~ "portrait.png"
    assert Floki.find(preview_document(view), "img[src='/images/logo.svg']") == []

    pdf =
      file_input(view, "#layout-test-upload-form", :demo_files, [
        %{name: "document.pdf", content: @pdf, type: "application/pdf"}
      ])

    render_upload(pdf, "document.pdf")
    assert Floki.find(preview_document(view), "[data-file-stored].hidden") != []
    assert Floki.find(preview_document(view), "[data-file-stored] img[src='#{image_url}']") != []

    render_submit(form(view, "#layout-test-upload-form"))
    pdf_url = "data:application/pdf;base64,#{Base.encode64(@pdf)}"

    assert Floki.find(
             preview_document(view),
             "[data-pdf-url='#{pdf_url}'] iframe[data-pdf-viewer]"
           ) != []

    assert Floki.text(preview_document(view)) =~ "document.pdf"
    assert Floki.find(preview_document(view), "img") == []
    assert Floki.find(preview_document(view), "button[phx-click=cancel_upload]") == []
    assert has_element?(view, "#uploaded-names", "document.pdf")
  end

  test "multiple files append saved image, PDF, and text data with removable captions", %{
    conn: conn
  } do
    {:ok, view, _html} = live(conn, ~p"/dev_panel/layout_test")
    render_click(element(view, "#upload-selection-multiple"))
    refute has_element?(view, "#layout-test-upload-preview")
    refute has_element?(view, "#layout-test-upload-input template[data-phx-portal]")
    assert has_element?(view, "#layout-test-upload-form [data-file-collection]")

    upload =
      file_input(view, "#layout-test-upload-form", :demo_files, [
        %{name: "notes.txt", content: "Upload notes", type: "text/plain"},
        %{name: "portrait.png", content: @image, type: "image/png"},
        %{name: "document.pdf", content: @pdf, type: "application/pdf"}
      ])

    render_upload(upload, "notes.txt")
    render_upload(upload, "portrait.png")
    render_upload(upload, "document.pdf")

    assert has_element?(
             view,
             "#layout-test-upload-input img[data-phx-hook='Phoenix.LiveImgPreview'][alt='portrait.png']"
           )

    assert has_element?(
             view,
             "#layout-test-upload-input [phx-hook=UploadPdfPreview] iframe[data-pdf-viewer][title='PDF preview of document.pdf']"
           )

    assert has_element?(
             view,
             "#layout-test-upload-input [phx-hook=UploadPdfPreview] a[data-pdf-open][target=_blank][rel='noopener noreferrer']"
           )

    refute has_element?(view, "#layout-test-upload-input canvas")
    render_submit(form(view, "#layout-test-upload-form"))

    for name <- ~w(notes.txt portrait.png document.pdf) do
      assert has_element?(view, "#uploaded-names", name)
      assert has_element?(view, "#layout-test-upload-input", name)
    end

    assert has_element?(view, "#layout-test-upload-input img[src='/images/logo.svg']")

    assert has_element?(
             view,
             "#layout-test-upload-input img[src='data:image/png;base64,#{Base.encode64(@image)}']"
           )

    assert has_element?(
             view,
             "#layout-test-upload-input [data-pdf-url='data:application/pdf;base64,#{Base.encode64(@pdf)}'] iframe[data-pdf-viewer][title='PDF preview of PDF']"
           )

    assert has_element?(
             view,
             "#layout-test-upload-input button[phx-click=remove_upload][phx-value-url='data:text/plain;base64,#{Base.encode64("Upload notes")}']"
           )

    refute has_element?(view, "#layout-test-uploads button[phx-click=cancel_upload]")

    render_click(
      element(
        view,
        "#layout-test-upload-input button[phx-click=remove_upload][phx-value-url='data:application/pdf;base64,#{Base.encode64(@pdf)}']"
      )
    )

    refute has_element?(view, "#layout-test-upload-input [phx-hook=UploadPdfPreview]")
    assert has_element?(view, "#layout-test-upload-input img[alt='Image']")
    assert has_element?(view, "#layout-test-upload-input", "notes.txt")
    refute has_element?(view, "#layout-test-upload-input", "document.pdf")
  end

  test "the same queue accepts GIF, WebP, and text files and saves their bytes", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/dev_panel/layout_test")

    for {name, type, bytes} <- [
          {"animation.gif", "image/gif",
           Base.decode64!("R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7")},
          {"portrait.webp", "image/webp",
           Base.decode64!("UklGRiIAAABXRUJQVlA4IBYAAAAwAQCdASoBAAEADsD+JaQAA3AAAAAA")},
          {"notes.txt", "text/plain", "Upload notes"}
        ] do
      upload =
        file_input(view, "#layout-test-upload-form", :demo_files, [
          %{name: name, content: bytes, type: type}
        ])

      render_upload(upload, name)
      assert Floki.find(preview_document(view), "button[aria-label='Cancel #{name}']") != []
      render_submit(form(view, "#layout-test-upload-form"))
      assert has_element?(view, "#uploaded-names", name)

      assert Floki.find(
               preview_document(view),
               "button[phx-click=remove_upload][phx-value-url='data:#{type};base64,#{Base.encode64(bytes)}']"
             ) != []

      assert Floki.find(preview_document(view), "button[phx-click=cancel_upload]") == []
    end
  end

  test "pending files lock selection changes until the queue is cancelled or saved", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/dev_panel/layout_test")

    upload =
      file_input(view, "#layout-test-upload-form", :demo_files, [
        %{name: "portrait.png", content: @image, type: "image/png"}
      ])

    render_upload(upload, "portrait.png", 25)
    document = view |> render() |> Floki.parse_document!()
    [input_id] = Floki.attribute(document, "#layout-test-upload-input input[type=file]", "id")

    [active_refs] =
      Floki.attribute(
        document,
        "#layout-test-upload-input input[type=file]",
        "data-phx-active-refs"
      )

    for selection <- ~w(single singles multiple) do
      assert has_element?(view, "#upload-selection-#{selection}[disabled]")
    end

    for selection <- ~w(singles multiple) do
      render_click(view, "set_showcase_option", %{
        "section" => "uploads",
        "option" => "selection",
        "choice" => selection
      })

      assert has_element?(
               view,
               "#layout-test-upload-input input[id='#{input_id}'][data-phx-active-refs='#{active_refs}']:not([multiple])"
             )
    end

    assert has_element?(
             view,
             "#layout-test-upload-input input[id='#{input_id}'][data-phx-active-refs='#{active_refs}']:not([multiple])"
           )

    assert has_element?(view, "#upload-selection-single[aria-pressed=true]")
    assert Floki.find(preview_document(view), "img[alt='portrait.png']") != []

    [entry_ref] =
      Floki.attribute(preview_document(view), "button[phx-click=cancel_upload]", "phx-value-ref")

    render_click(view, "cancel_upload", %{"ref" => entry_ref})
    refute has_element?(view, "#upload-selection-singles[disabled]")
    refute has_element?(view, "#upload-selection-multiple[disabled]")
    render_click(element(view, "#upload-selection-multiple"))
    assert has_element?(view, "#layout-test-upload-input input[type=file][multiple]")
    refute has_element?(view, "#layout-test-upload-input input[id='#{input_id}']")

    replacement =
      file_input(view, "#layout-test-upload-form", :demo_files, [
        %{name: "notes.txt", content: "Replacement notes", type: "text/plain"}
      ])

    render_upload(replacement, "notes.txt")
    assert has_element?(view, "#upload-selection-single[disabled]")
    render_submit(form(view, "#layout-test-upload-form"))
    refute has_element?(view, "#upload-selection-single[disabled]")
    render_click(element(view, "#upload-selection-single"))
    assert has_element?(view, "#layout-test-upload-input input[type=file]:not([multiple])")
    assert has_element?(view, "#uploaded-names", "notes.txt")
  end

  test "selection changes retain saved files and single renders only the first", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/dev_panel/layout_test")

    image =
      file_input(view, "#layout-test-upload-form", :demo_files, [
        %{name: "portrait.png", content: @image, type: "image/png"}
      ])

    render_upload(image, "portrait.png")
    render_submit(form(view, "#layout-test-upload-form"))
    render_click(element(view, "#upload-selection-multiple"))

    pdf =
      file_input(view, "#layout-test-upload-form", :demo_files, [
        %{name: "document.pdf", content: @pdf, type: "application/pdf"}
      ])

    render_upload(pdf, "document.pdf")
    render_submit(form(view, "#layout-test-upload-form"))
    assert has_element?(view, "#layout-test-upload-input", "portrait.png")
    assert has_element?(view, "#layout-test-upload-input", "document.pdf")

    render_click(element(view, "#upload-selection-single"))
    assert Floki.text(preview_document(view)) =~ "portrait.png"
    refute Floki.text(preview_document(view)) =~ "document.pdf"
    assert Floki.find(preview_document(view), "[phx-hook=UploadPdfPreview]") == []

    render_click(element(view, "#upload-selection-multiple"))
    assert has_element?(view, "#layout-test-upload-input", "portrait.png")
    assert has_element?(view, "#layout-test-upload-input", "document.pdf")
    assert has_element?(view, "#layout-test-upload-input [phx-hook=UploadPdfPreview]")
  end

  test "cancelling one entry retains other selections and read-only mode preserves previews", %{
    conn: conn
  } do
    {:ok, view, _html} = live(conn, ~p"/dev_panel/layout_test")
    render_click(element(view, "#upload-selection-multiple"))

    upload =
      file_input(view, "#layout-test-upload-form", :demo_files, [
        %{name: "notes.txt", content: "Upload notes", type: "text/plain"},
        %{name: "portrait.png", content: @image, type: "image/png"}
      ])

    render_upload(upload, "notes.txt")
    render_upload(upload, "portrait.png")
    render_click(element(view, "#upload-mode-disabled"))
    refute has_element?(view, "#layout-test-uploads input[type=file]:not([disabled])")
    assert has_element?(view, "#layout-test-upload-input label.hidden input[type=file][disabled]")
    refute has_element?(view, "#layout-test-uploads button[phx-click=cancel_upload]")
    refute has_element?(view, "#layout-test-uploads button[phx-click=remove_upload]")
    assert has_element?(view, "#layout-test-upload-input", "notes.txt")
    assert has_element?(view, "#layout-test-upload-input img[alt='portrait.png']")

    render_click(element(view, "#upload-mode-enabled"))

    render_click(
      element(view, "#layout-test-upload-input button[aria-label='Cancel portrait.png']")
    )

    refute has_element?(view, "#layout-test-upload-input img[alt='portrait.png']")
    assert has_element?(view, "#layout-test-upload-input button[aria-label='Cancel notes.txt']")
    assert has_element?(view, "#upload-selection-single[disabled]")

    render_click(element(view, "#layout-test-upload-input button[aria-label='Cancel notes.txt']"))
    refute has_element?(view, "#layout-test-uploads button[phx-click=cancel_upload]")
    refute has_element?(view, "#upload-selection-single[disabled]")
  end

  test "one upload input exposes every render mode for each selection mode", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/dev_panel/layout_test")

    modes =
      ElixirbitsWeb.CoreComponents.__components__().input.attrs
      |> Enum.find(&(&1.name == :render_as))
      |> Map.fetch!(:opts)
      |> Keyword.fetch!(:values)

    for selection <- ~w(single singles multiple), mode <- modes do
      render_click(element(view, "#upload-selection-#{selection}"))
      render_click(element(view, "#upload-mode-#{mode}"))
      assert has_element?(view, "#upload-mode-#{mode}[aria-pressed=true]")
      assert has_element?(view, "#layout-test-upload-input input[type=file]")
      assert has_element?(view, "#layout-test-upload-input [data-file-selection=#{selection}]")

      if selection == "multiple" do
        assert has_element?(view, "#layout-test-upload-input input[type=file][multiple]")
      else
        assert has_element?(view, "#layout-test-upload-input input[type=file]:not([multiple])")
      end

      assert view
             |> render()
             |> Floki.parse_document!()
             |> Floki.find("#layout-test-upload-form input[type=file]")
             |> length() == 1

      if mode in ~w(enabled text text-enabled hidden hidden-enabled) do
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
    render_click(element(view, "#upload-selection-multiple"))
    image = @image <> :binary.copy(<<0>>, 100 - byte_size(@image))
    pdf = @pdf <> :binary.copy("\n", 100 - byte_size(@pdf))

    upload =
      file_input(view, "#layout-test-upload-form", :demo_files, [
        %{name: "portrait.png", content: image, type: "image/png"},
        %{name: "document.pdf", content: pdf, type: "application/pdf"}
      ])

    render_upload(upload, "portrait.png", 25)
    render_upload(upload, "document.pdf", 25)
    document = view |> render() |> Floki.parse_document!()
    input_selector = "#layout-test-upload-input input[name=demo_files]"
    [upload_id] = Floki.attribute(document, input_selector, "id")
    [active_refs] = Floki.attribute(document, input_selector, "data-phx-active-refs")

    [pdf_id] =
      Floki.attribute(document, "#layout-test-upload-input [phx-hook=UploadPdfPreview]", "id")

    render_click(element(view, "#upload-mode-hidden-disabled"))

    assert has_element?(
             view,
             "#layout-test-upload-input div.hidden input##{upload_id}[disabled]"
           )

    assert Floki.attribute(
             view |> render() |> Floki.parse_document!(),
             input_selector,
             "data-phx-active-refs"
           ) == [active_refs]

    assert has_element?(
             view,
             "#layout-test-upload-input div.hidden img[data-phx-hook='Phoenix.LiveImgPreview'][alt='portrait.png']"
           )

    assert has_element?(
             view,
             "div.hidden ##{pdf_id} iframe[data-pdf-viewer][title='PDF preview of document.pdf']"
           )

    refute has_element?(view, "#layout-test-upload-input button[phx-click=cancel_upload]")
    render_click(element(view, "#upload-mode-enabled"))
    assert has_element?(view, "#layout-test-upload-input input##{upload_id}:not([disabled])")
    assert has_element?(view, "##{pdf_id} iframe[data-pdf-viewer]")
    render_upload(upload, "portrait.png", 75)
    render_upload(upload, "document.pdf", 75)
    render_submit(form(view, "#layout-test-upload-form"))

    assert has_element?(
             view,
             "#layout-test-upload-input img[src='data:image/png;base64,#{Base.encode64(image)}']"
           )

    assert has_element?(
             view,
             "#layout-test-upload-input [data-pdf-url='data:application/pdf;base64,#{Base.encode64(pdf)}'] iframe[data-pdf-viewer]"
           )
  end

  test "upload states, preview toggles, and layouts preserve pending files", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/dev_panel/layout_test")
    render_click(element(view, "#upload-selection-multiple"))

    upload =
      file_input(view, "#layout-test-upload-form", :demo_files, [
        %{name: "portrait.png", content: @image, type: "image/png"},
        %{name: "document.pdf", content: @pdf, type: "application/pdf"}
      ])

    render_upload(upload, "portrait.png")
    render_upload(upload, "document.pdf")

    [pdf_preview] =
      view
      |> render()
      |> Floki.parse_document!()
      |> Floki.attribute("#layout-test-upload-input [phx-hook=UploadPdfPreview]", "id")

    render_click(element(view, "#upload-preview-tag"))
    assert has_element?(view, "#upload-preview-tag[aria-pressed=true]")
    assert has_element?(view, "#layout-test-upload-input .hidden img[alt='portrait.png']")

    assert has_element?(
             view,
             "#layout-test-upload-input .hidden ##{pdf_preview} iframe[data-pdf-viewer]"
           )

    assert has_element?(
             view,
             "#layout-test-upload-input button[aria-label='Cancel document.pdf']"
           )

    render_click(element(view, "#showcase-uploads-preview"))
    assert has_element?(view, "#layout-test-upload-input [data-file-preview=false]")
    assert has_element?(view, "#upload-preview-tag[disabled]")
    assert has_element?(view, "#upload-preview-thumbnail[disabled]")
    refute has_element?(view, "#layout-test-upload-input [phx-hook=UploadPdfPreview]")
    assert has_element?(view, "#layout-test-upload-input", "portrait.png")
    assert has_element?(view, "#layout-test-upload-input", "document.pdf")

    for option <- ~w(disabled required labels tooltip errors stored) do
      render_click(element(view, "#showcase-uploads-#{option}"))
    end

    assert has_element?(
             view,
             "#layout-test-upload-input input[name=demo_files][disabled][required]"
           )

    refute has_element?(view, "#layout-test-upload-input .input-floating-label", "Files")
    assert has_element?(view, "#layout-test-upload-input [data-tooltip]")
    assert has_element?(view, "#layout-test-upload-input", "Choose a supported file.")
    refute has_element?(view, "#layout-test-upload-input img[src='/images/logo.svg']")
    refute has_element?(view, "#layout-test-upload-input [phx-hook=UploadPdfPreview]")

    for option <- ~w(disabled required stored preview) do
      render_click(element(view, "#showcase-uploads-#{option}"))
    end

    render_click(element(view, "#upload-preview-thumbnail"))
    assert has_element?(view, "#layout-test-upload-input img[src='/images/logo.svg']")
    assert has_element?(view, "##{pdf_preview} iframe[data-pdf-viewer]")
    render_submit(form(view, "#layout-test-upload-form"))

    assert has_element?(
             view,
             "#layout-test-upload-input img[src='data:image/png;base64,#{Base.encode64(@image)}']"
           )

    assert has_element?(
             view,
             "#layout-test-upload-input [data-pdf-url='data:application/pdf;base64,#{Base.encode64(@pdf)}'] iframe[data-pdf-viewer]"
           )
  end

  defp preview_document(view) do
    view
    |> element(
      "#layout-test-upload-input template[data-phx-portal], #layout-test-upload-input [data-file-collection]"
    )
    |> render()
    |> Floki.parse_document!()
  end
end

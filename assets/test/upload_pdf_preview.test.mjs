import test from "node:test"
import assert from "node:assert/strict"
import {readFile} from "node:fs/promises"

const source = await readFile(new URL("../js/upload_pdf_preview.js", import.meta.url), "utf8")

async function withPreviewHarness(options, run) {
  const originals = new Map(["document", "window", "getComputedStyle", "pdfPreviewTestDependencies"].map(name => [name, Object.getOwnPropertyDescriptor(globalThis, name)]))
  const originalRevoke = URL.revokeObjectURL
  const documentRequested = Promise.withResolvers()
  const renderRequested = Promise.withResolvers()
  const rendered = options.rendered ?? Promise.withResolvers()
  if (!options.rendered) rendered.resolve()
  const requests = []
  const revoked = []
  const canvas = {hidden: true, width: 0, height: 0}
  const status = {hidden: false, textContent: "Loading PDF preview..."}
  const input = {id: "upload-input"}
  let fileUrls = 0
  let destroyed = 0
  let canceled = 0
  let pageRequests = 0
  const page = {
    getViewport({scale}) { return {width: 400 * scale, height: 800 * scale} },
    render(parameters) {
      renderRequested.resolve(parameters)
      return {
        promise: rendered.promise,
        cancel() {
          canceled++
          rendered.reject(Object.assign(new Error("Rendering canceled"), {name: "RenderingCancelledException"}))
        },
      }
    },
  }
  const pdf = {getPage(number) { pageRequests++; assert.equal(number, 1); return Promise.resolve(page) }}
  const loading = options.loading ?? Promise.withResolvers()
  if (!options.loading) loading.resolve(pdf)
  const pdfjs = {
    GlobalWorkerOptions: {},
    getDocument(parameters) {
      requests.push(parameters)
      documentRequested.resolve()
      return {
        promise: loading.promise,
        destroy() {
          destroyed++
          loading.reject(new Error("Document loading canceled"))
          return Promise.resolve()
        },
      }
    },
  }

  globalThis.document = {getElementById(id) { assert.equal(id, input.id); return input }}
  globalThis.window = {devicePixelRatio: 4}
  globalThis.getComputedStyle = () => ({height: "144px"})
  globalThis.pdfPreviewTestDependencies = {
    getFileURLForUpload(element, ref) {
      assert.equal(element, input)
      assert.equal(ref, "file-ref")
      fileUrls++
      return "blob:pending-pdf"
    },
    loadPdf: () => options.imported?.promise ?? Promise.resolve(pdfjs),
  }
  URL.revokeObjectURL = url => revoked.push(url)

  try {
    const testSource = source
      .replace('import {getFileURLForUpload} from "phoenix_live_view"', "const {getFileURLForUpload} = globalThis.pdfPreviewTestDependencies")
      .replace('await import("pdfjs-dist")', "await globalThis.pdfPreviewTestDependencies.loadPdf()")
      .replaceAll("import.meta.url", '"https://app.test/assets/app.js"')
    const hook = (await import(`data:text/javascript;base64,${Buffer.from(testSource).toString("base64")}#${Math.random()}`)).default
    const context = {
      ...hook,
      el: {
        dataset: options.url ? {pdfUrl: options.url} : {uploadRef: input.id, entryRef: "file-ref"},
        querySelector: selector => selector === "canvas" ? canvas : status,
      },
    }
    await run({context, canvas, status, requests, revoked, loading, rendered, pdf, pdfjs, documentRequested, renderRequested, counts: () => ({fileUrls, destroyed, canceled, pageRequests})})
  } finally {
    URL.revokeObjectURL = originalRevoke
    for (const [name, descriptor] of originals) {
      if (descriptor) Object.defineProperty(globalThis, name, descriptor)
      else delete globalThis[name]
    }
  }
}

test("pending PDFs render a bounded first-page thumbnail and release their worker and blob URL", async () => {
  await withPreviewHarness({}, async ({context, canvas, status, requests, revoked, pdfjs, counts}) => {
    await context.mounted()
    assert.equal(canvas.hidden, false)
    assert.equal(canvas.width, 144)
    assert.equal(canvas.height, 288)
    assert.equal(status.hidden, true)
    assert.equal(requests[0].url, "blob:pending-pdf")
    assert.equal(pdfjs.GlobalWorkerOptions.workerSrc, "https://app.test/assets/pdf.worker.js")
    assert.equal(requests[0].standardFontDataUrl, "https://app.test/assets/standard_fonts/")
    assert.deepEqual(counts(), {fileUrls: 1, destroyed: 1, canceled: 0, pageRequests: 1})
    assert.deepEqual(revoked, ["blob:pending-pdf"])

    context.destroyed()
    assert.equal(canvas.width, 0)
    assert.equal(canvas.height, 0)
    assert.equal(counts().destroyed, 1)
    assert.deepEqual(revoked, ["blob:pending-pdf"])
  })
})

test("saved PDF previews use their stored URL without consulting or revoking an upload", async () => {
  await withPreviewHarness({url: "data:application/pdf;base64,cGRm"}, async ({context, canvas, requests, revoked, counts}) => {
    await context.mounted()
    assert.equal(canvas.hidden, false)
    assert.equal(requests[0].url, "data:application/pdf;base64,cGRm")
    assert.equal(counts().fileUrls, 0)
    assert.deepEqual(revoked, [])
    context.destroyed()
    assert.deepEqual(revoked, [])
  })
})

test("removal while the renderer is importing never starts a document or creates a blob URL", async () => {
  const imported = Promise.withResolvers()
  await withPreviewHarness({imported}, async ({context, canvas, requests, revoked, pdfjs, counts}) => {
    const mounted = context.mounted()
    context.destroyed()
    imported.resolve(pdfjs)
    await mounted
    assert.equal(canvas.width, 0)
    assert.equal(canvas.height, 0)
    assert.equal(requests.length, 0)
    assert.equal(counts().fileUrls, 0)
    assert.deepEqual(revoked, [])
  })
})

test("removal while the document is loading cancels it once and releases its blob URL", async () => {
  const loading = Promise.withResolvers()
  await withPreviewHarness({loading}, async ({context, status, revoked, documentRequested, counts}) => {
    const mounted = context.mounted()
    await documentRequested.promise
    context.destroyed()
    await mounted
    assert.equal(counts().destroyed, 1)
    assert.equal(counts().pageRequests, 0)
    assert.deepEqual(revoked, ["blob:pending-pdf"])
    assert.equal(status.textContent, "Loading PDF preview...")
  })
})

test("removal while rendering cancels the page and frees the document and canvas", async () => {
  const rendered = Promise.withResolvers()
  await withPreviewHarness({rendered}, async ({context, canvas, status, revoked, renderRequested, counts}) => {
    const mounted = context.mounted()
    await renderRequested.promise
    context.destroyed()
    await mounted
    assert.deepEqual(counts(), {fileUrls: 1, destroyed: 1, canceled: 1, pageRequests: 1})
    assert.deepEqual(revoked, ["blob:pending-pdf"])
    assert.equal(canvas.hidden, true)
    assert.equal(canvas.width, 0)
    assert.equal(canvas.height, 0)
    assert.equal(status.textContent, "Loading PDF preview...")
  })
})

test("password-protected and invalid PDFs show clear errors and release their resources", async () => {
  for (const [name, message] of [["PasswordException", "PDF is password protected."], ["InvalidPDFException", "PDF preview unavailable."]]) {
    const loading = Promise.withResolvers()
    await withPreviewHarness({loading}, async ({context, canvas, status, revoked, documentRequested, counts}) => {
      const mounted = context.mounted()
      await documentRequested.promise
      loading.reject(Object.assign(new Error("Cannot open PDF"), {name}))
      await mounted
      assert.equal(canvas.hidden, true)
      assert.equal(status.hidden, false)
      assert.equal(status.textContent, message)
      assert.equal(counts().destroyed, 1)
      assert.deepEqual(revoked, ["blob:pending-pdf"])
    })
  }
})

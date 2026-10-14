import test from "node:test"
import assert from "node:assert/strict"
import {readFile} from "node:fs/promises"

const source = await readFile(new URL("../js/upload_pdf_preview.js", import.meta.url), "utf8")

async function withPreviewHarness(options, run) {
  const originals = new Map(["document", "navigator", "fetch", "pdfPreviewTestDependencies"].map(name => [name, Object.getOwnPropertyDescriptor(globalThis, name)]))
  const originalCreate = URL.createObjectURL
  const originalRevoke = URL.revokeObjectURL
  const blob = new Blob(["%PDF native viewer"], {type: "application/pdf"})
  const fetched = options.fetched ?? Promise.withResolvers()
  if (!options.fetched) fetched.resolve({blob: () => options.blobbed?.promise ?? Promise.resolve(blob)})
  const fetchRequested = Promise.withResolvers()
  const viewer = {hidden: true, src: "", removeAttribute(name) { assert.equal(name, "src"); this.src = "" }}
  const open = {hidden: true, href: ""}
  const status = {hidden: false, textContent: "Loading PDF preview..."}
  const input = {id: "upload-input"}
  const requests = []
  const created = []
  const revoked = []
  let fileUrls = 0

  Object.defineProperty(globalThis, "document", {configurable: true, value: {getElementById(id) { assert.equal(id, input.id); return input }}})
  Object.defineProperty(globalThis, "navigator", {configurable: true, value: {pdfViewerEnabled: options.nativeSupported ?? true}})
  Object.defineProperty(globalThis, "fetch", {configurable: true, value: url => {
    requests.push(url)
    fetchRequested.resolve()
    return fetched.promise
  }})
  globalThis.pdfPreviewTestDependencies = {
    getFileURLForUpload(element, ref) {
      assert.equal(element, input)
      assert.equal(ref, "file-ref")
      fileUrls++
      return "blob:pending-pdf"
    },
  }
  URL.createObjectURL = value => { created.push(value); return "blob:saved-pdf" }
  URL.revokeObjectURL = url => revoked.push(url)

  try {
    const testSource = source.replace('import {getFileURLForUpload} from "phoenix_live_view"', "const {getFileURLForUpload} = globalThis.pdfPreviewTestDependencies")
    const hook = (await import(`data:text/javascript;base64,${Buffer.from(testSource).toString("base64")}#${Math.random()}`)).default
    const elements = {"[data-pdf-viewer]": viewer, "[data-pdf-open]": open, "[data-pdf-status]": status}
    const context = {
      ...hook,
      el: {
        dataset: options.url ? {pdfUrl: options.url} : {uploadRef: input.id, entryRef: "file-ref"},
        querySelector: selector => elements[selector],
      },
    }
    await run({context, viewer, open, status, requests, created, revoked, fetched, blob, fetchRequested, counts: () => ({fileUrls})})
  } finally {
    URL.createObjectURL = originalCreate
    URL.revokeObjectURL = originalRevoke
    for (const [name, descriptor] of originals) {
      if (descriptor) Object.defineProperty(globalThis, name, descriptor)
      else delete globalThis[name]
    }
  }
}

test("pending PDFs use the native viewer and retain their upload URL until removal", async () => {
  await withPreviewHarness({}, async ({context, viewer, open, status, requests, revoked, counts}) => {
    await context.mounted()
    assert.equal(viewer.hidden, false)
    assert.equal(viewer.src, "blob:pending-pdf")
    assert.equal(open.hidden, false)
    assert.equal(open.href, viewer.src)
    assert.equal(status.hidden, true)
    assert.deepEqual(requests, [])
    assert.equal(counts().fileUrls, 1)
    assert.deepEqual(revoked, [])

    context.destroyed()
    assert.equal(viewer.src, "")
    assert.deepEqual(revoked, ["blob:pending-pdf"])
    context.destroyed()
    assert.deepEqual(revoked, ["blob:pending-pdf"])
  })
})

test("served PDF URLs use the native viewer without creating or revoking an object URL", async () => {
  await withPreviewHarness({url: "https://app.test/uploads/document.pdf"}, async ({context, viewer, open, created, requests, revoked, counts}) => {
    await context.mounted()
    assert.equal(viewer.hidden, false)
    assert.equal(viewer.src, "https://app.test/uploads/document.pdf")
    assert.equal(open.href, viewer.src)
    assert.equal(counts().fileUrls, 0)
    assert.deepEqual(requests, [])
    assert.deepEqual(created, [])
    context.destroyed()
    assert.deepEqual(revoked, [])
  })
})

test("saved data URLs become browser-openable object URLs and remain valid until removal", async () => {
  const url = "data:application/pdf;base64,cGRm"
  await withPreviewHarness({url}, async ({context, viewer, open, status, requests, created, revoked, blob, counts}) => {
    await context.mounted()
    assert.equal(viewer.hidden, false)
    assert.equal(viewer.src, "blob:saved-pdf")
    assert.equal(open.hidden, false)
    assert.equal(open.href, "blob:saved-pdf")
    assert.equal(status.hidden, true)
    assert.deepEqual(requests, [url])
    assert.deepEqual(created, [blob])
    assert.equal(counts().fileUrls, 0)
    assert.deepEqual(revoked, [])
    context.destroyed()
    context.destroyed()
    assert.deepEqual(revoked, ["blob:saved-pdf"])
  })
})

test("browsers without inline PDF support retain an accessible link instead of an iframe", async () => {
  await withPreviewHarness({nativeSupported: false}, async ({context, viewer, open, status, revoked}) => {
    await context.mounted()
    assert.equal(viewer.hidden, true)
    assert.equal(viewer.src, "")
    assert.equal(open.hidden, false)
    assert.equal(open.href, "blob:pending-pdf")
    assert.equal(status.hidden, false)
    assert.equal(status.textContent, "Open this PDF in your browser.")
    assert.deepEqual(revoked, [])
    context.destroyed()
    assert.deepEqual(revoked, ["blob:pending-pdf"])
  })
})

test("removal before a saved data URL is fetched never creates a URL or updates the removed viewer", async () => {
  const fetched = Promise.withResolvers()
  await withPreviewHarness({url: "data:application/pdf;base64,cGRm", fetched}, async ({context, viewer, open, status, fetchRequested, created, revoked, blob}) => {
    const mounted = context.mounted()
    await fetchRequested.promise
    context.destroyed()
    fetched.resolve({blob: () => Promise.resolve(blob)})
    await mounted
    assert.equal(viewer.src, "")
    assert.equal(viewer.hidden, true)
    assert.equal(open.href, "")
    assert.equal(open.hidden, true)
    assert.equal(status.textContent, "Loading PDF preview...")
    assert.deepEqual(created, [])
    assert.deepEqual(revoked, [])
  })
})

test("removal while a saved data URL becomes a blob never allocates a viewer URL", async () => {
  const blobbed = Promise.withResolvers()
  await withPreviewHarness({url: "data:application/pdf;base64,cGRm", blobbed}, async ({context, viewer, open, fetchRequested, created, revoked, blob}) => {
    const mounted = context.mounted()
    await fetchRequested.promise
    context.destroyed()
    blobbed.resolve(blob)
    await mounted
    assert.equal(viewer.src, "")
    assert.equal(open.href, "")
    assert.deepEqual(created, [])
    assert.deepEqual(revoked, [])
  })
})

test("a saved data URL that cannot be materialized shows an error without unusable viewer links", async () => {
  const fetched = Promise.withResolvers()
  await withPreviewHarness({url: "data:application/pdf;base64,cGRm", fetched}, async ({context, viewer, open, status, fetchRequested, created, revoked}) => {
    const mounted = context.mounted()
    await fetchRequested.promise
    fetched.reject(new TypeError("Failed to fetch"))
    await mounted
    assert.equal(viewer.hidden, true)
    assert.equal(open.hidden, true)
    assert.equal(status.hidden, false)
    assert.equal(status.textContent, "PDF preview unavailable.")
    assert.deepEqual(created, [])
    assert.deepEqual(revoked, [])
  })
})

test("a data URL failure after removal does not update the disconnected status", async () => {
  const fetched = Promise.withResolvers()
  await withPreviewHarness({url: "data:application/pdf;base64,cGRm", fetched}, async ({context, status, fetchRequested, created, revoked}) => {
    const mounted = context.mounted()
    await fetchRequested.promise
    context.destroyed()
    fetched.reject(new TypeError("Failed to fetch"))
    await mounted
    assert.equal(status.textContent, "Loading PDF preview...")
    assert.deepEqual(created, [])
    assert.deepEqual(revoked, [])
  })
})

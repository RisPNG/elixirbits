import test from "node:test"
import assert from "node:assert/strict"
import {readFile} from "node:fs/promises"

class UIEvent extends Event {
  stopImmediatePropagation() { this.stopped = true; super.stopImmediatePropagation() }
}

class Element {
  constructor(parent = null) {
    this.parent = parent
    this.listeners = []
    this.dataset = {}
    this.nodes = new Map()
    this.hidden = true
    this.textContent = ""
    this.classes = new Set()
    this.classList = {toggle: (name, enabled) => enabled ? this.classes.add(name) : this.classes.delete(name)}
  }
  addEventListener(type, callback, capture = false) { this.listeners.push({type, callback, capture}) }
  removeEventListener(type, callback, capture = false) { this.listeners = this.listeners.filter(item => !(item.type === type && item.callback === callback && item.capture === capture)) }
  querySelector(selector) { return this.nodes.get(selector) || null }
  querySelectorAll(selector) { return this.nodes.get(selector) || [] }
  matches(selector) { return selector === ":focus-visible" && this.focusVisible === true }
  closest(selector) {
    const key = selector.slice(6, -1).replace(/-([a-z])/g, (_, char) => char.toUpperCase())
    for (let element = this; element; element = element.parent) if (element.dataset[key] !== undefined) return element
    return null
  }
  getAttribute(name) { return this[name] ?? null }
  click() { this.dispatchEvent(new UIEvent("click", {bubbles: true, cancelable: true})) }
  replaceChildren(...children) { this.children = children }
  removeAttribute(name) { delete this[name] }
  dispatchEvent(event) {
    Object.defineProperty(event, "target", {value: this, configurable: true})
    const path = []
    for (let element = this; element; element = element.parent) path.push(element)
    for (const element of path.slice().reverse()) {
      for (const item of element.listeners.filter(item => item.type === event.type && item.capture)) {
        item.callback(event)
        if (event.stopped) return !event.defaultPrevented
      }
    }
    for (const element of event.bubbles ? path : [this]) {
      for (const item of element.listeners.filter(item => item.type === event.type && !item.capture)) {
        item.callback(event)
        if (event.stopped) return !event.defaultPrevented
      }
    }
    return !event.defaultPrevented
  }
}

class Editor {
  static instances = []
  constructor() { Editor.instances.push(this) }
  edit(file, options) { this.file = file; this.options = options; return new Promise(resolve => { this.resolve = resolve }) }
  destroy() { this.destroyed = true; this.resolve?.(null); this.resolve = null }
}

const source = (await readFile(new URL("../js/file_input.js", import.meta.url), "utf8"))
  .replace('import {getFileURLForUpload} from "phoenix_live_view"', "const getFileURLForUpload = (...args) => globalThis.__getUploadUrl(...args)")
  .replace('await import("./image_editor")', "await globalThis.__loadImageEditor()")
const {default: hook, FilePreview: previewHook} = await import(`data:text/javascript;base64,${Buffer.from(source).toString("base64")}`)
const settled = () => new Promise(resolve => setImmediate(resolve))
let fixtureId = 0

function fixture(options = {}, mount = true) {
  const originals = {Event: globalThis.Event, DataTransfer: globalThis.DataTransfer, document: globalThis.document, fetch: globalThis.fetch, navigator: Object.getOwnPropertyDescriptor(globalThis, "navigator"), create: URL.createObjectURL, revoke: URL.revokeObjectURL}
  const created = []
  const revoked = []
  globalThis.Event = UIEvent
  globalThis.DataTransfer = class {
    constructor() { this.files = []; this.items = {add: file => this.files.push(file)} }
  }
  Object.defineProperty(globalThis, "navigator", {value: {pdfViewerEnabled: true}, configurable: true})
  URL.createObjectURL = file => { const url = `blob:${created.length}`; created.push({file, url}); return url }
  URL.revokeObjectURL = url => revoked.push(url)
  globalThis.__loadImageEditor = async () => ({default: Editor})
  globalThis.document = {createElement: () => new Element()}
  globalThis.__getUploadUrl = (input, ref) => input.files.find(file => file._phxRef === ref) ? URL.createObjectURL(input.files.find(file => file._phxRef === ref)) : null
  Editor.instances = []
  const window = new Element()
  const form = new Element(window)
  const root = new Element(form)
  const input = new Element(root)
  input.id = `file-${++fixtureId}`
  input.files = []
  input.disabled = false
  input.placeholder = "Choose a file"
  input.name = "files"
  input.form = form
  const name = new Element()
  name.textContent = "Choose a file"
  const readonly = new Element()
  const error = new Element()
  const region = new Element()
  const image = new Element()
  const pdf = new Element()
  const open = new Element()
  const previewName = new Element()
  const caption = new Element()
  const stored = new Element()
  const clear = new Element(root)
  clear.dataset.fileClear = ""
  const edit = new Element(root)
  edit.dataset.fileEdit = ""
  const previous = new Element(root)
  previous.dataset.filePrevious = ""
  const next = new Element(root)
  next.dataset.fileNext = ""
  const metadata = new Element(root)
  const editorTemplate = new Element(root)
  const inputPosition = new Element()
  const previewPosition = new Element()
  Object.assign(root.dataset, {fileEditor: "true", fileSelection: "single", fileEntryRefs: "[]", filePreview: "true", fileMode: "enabled", ...options})
  root.nodes.set("[data-file-input]", input)
  root.nodes.set("[data-file-name]", name)
  root.nodes.set("[data-file-readonly-name]", readonly)
  root.nodes.set("[data-file-error]", error)
  root.nodes.set("[data-file-preview-region]", region)
  root.nodes.set("[data-file-open][data-entry-ref]", [])
  root.nodes.set("[data-file-stored]", [stored])
  root.nodes.set("[data-file-clear]", clear)
  root.nodes.set("[data-file-item]", [])
  root.nodes.set("[data-file-replacements]", metadata)
  root.nodes.set("[data-file-editor-template]", editorTemplate)
  root.nodes.set("[data-file-previous], [data-file-next]", [previous, next])
  root.nodes.set("[data-file-position]", [inputPosition, previewPosition])
  region.nodes.set("[data-file-preview-image]", image)
  region.nodes.set("[data-file-preview-pdf]", pdf)
  region.nodes.set("[data-file-preview-open]", open)
  region.nodes.set("[data-file-preview-name]", previewName)
  region.nodes.set("[data-file-preview-caption]", caption)
  region.nodes.set("[data-file-edit]", edit)
  const context = {...hook, el: root}
  const changes = []
  let uploadRef = 0
  if (root.dataset.fileUploadName) window.addEventListener("input", () => {
    for (const file of input.files) if (file._phxRef === undefined) file._phxRef = String(++uploadRef)
  })
  window.addEventListener("change", () => changes.push([...input.files]))
  if (mount) context.mounted()
  return {
    context, root, input, form, window, name, readonly, error, region, image, pdf, open, previewName, caption, stored, clear, edit, previous, next, metadata, editorTemplate, inputPosition, previewPosition, changes, created, revoked,
    select(file) {
      input.files = [file]
      input.dispatchEvent(new UIEvent("input", {bubbles: true}))
      input.dispatchEvent(new UIEvent("change", {bubbles: true}))
    },
    cleanup() {
      context.destroyed()
      globalThis.Event = originals.Event
      globalThis.DataTransfer = originals.DataTransfer
      globalThis.document = originals.document
      globalThis.fetch = originals.fetch
      if (originals.navigator) Object.defineProperty(globalThis, "navigator", originals.navigator)
      else delete globalThis.navigator
      URL.createObjectURL = originals.create
      URL.revokeObjectURL = originals.revoke
      delete globalThis.__loadImageEditor
      delete globalThis.__getUploadUrl
    },
  }
}

function detachedPreview(setup, mount = true) {
  const source = new Element()
  source.nodes.set("[data-file-item]", [])
  setup.root.nodes.set("template[data-phx-portal]", {content: source})
  const collection = new Element(setup.window)
  Object.assign(collection.dataset, {fileInputId: setup.input.id, fileDetached: "true", fileCollection: ""})
  for (const selector of ["[data-file-preview-region]", "[data-file-open][data-entry-ref]", "[data-file-stored]", "[data-file-item]", "[data-file-previous], [data-file-next]"]) {
    collection.nodes.set(selector, setup.root.nodes.get(selector))
    setup.root.nodes.delete(selector)
  }
  collection.nodes.set("[data-file-position]", [setup.previewPosition])
  setup.root.nodes.set("[data-file-position]", [setup.inputPosition])
  setup.previous.parent = setup.next.parent = setup.edit.parent = collection
  const context = {...previewHook, el: collection}
  if (mount) context.mounted()
  return {context, collection, source}
}

function serverItem(setup, {url, ref, type = "image/png", name = "image.png"}) {
  const element = new Element(setup.root)
  Object.assign(element.dataset, {fileItem: "", fileKey: url || ref, fileContentType: type, fileItemName: name})
  if (url) element.dataset.fileUrl = url
  if (ref) element.dataset.fileEntryRef = ref
  element.classes.add("hidden")
  return element
}

test("a detached native preview delegates selection actions to its form owner", async () => {
  const setup = fixture({fileSelection: "singles", fileEditor: "false"})
  const preview = detachedPreview(setup)
  try {
    await settled()
    const image = new File(["image"], "portrait.png", {type: "image/png"})
    const pdf = new File(["pdf"], "document.pdf", {type: "application/pdf"})
    setup.select(image)
    setup.select(pdf)
    assert.deepEqual(setup.context.files, [image, pdf])
    assert.equal(preview.collection.hidden, false)
    assert.equal(setup.name.textContent, "2 files")
    assert.equal(setup.pdf.hidden, false)
    assert.equal(setup.previewPosition.textContent, "2/2")
    setup.previous.click()
    assert.equal(setup.image.hidden, false)
    assert.equal(setup.caption.textContent, "portrait.png")
    assert.equal(setup.inputPosition.textContent, "1/2")
    assert.equal(setup.previewPosition.textContent, "1/2")

    setup.root.dataset.fileEditor = "true"
    setup.context.updated()
    setup.edit.click()
    await settled()
    assert.equal(Editor.instances.at(-1).file, image)
    const submit = new UIEvent("submit", {bubbles: true, cancelable: true})
    setup.form.dispatchEvent(submit)
    assert.equal(submit.defaultPrevented, true)
    const edited = new File(["cropped"], "portrait.png", {type: "image/png"})
    Editor.instances.at(-1).resolve(edited)
    await settled()
    assert.deepEqual(setup.input.files, [edited, pdf])
    assert.equal(setup.caption.textContent, "portrait.png")
    assert.equal(setup.previewPosition.textContent, "1/2")
    assert.equal(setup.context.preparing, false)

    const drop = new UIEvent("drop", {bubbles: true, cancelable: true})
    const dropped = new File(["text"], "notes.txt", {type: "text/plain"})
    drop.dataTransfer = {files: [dropped]}
    preview.collection.dispatchEvent(drop)
    assert.equal(drop.defaultPrevented, true)
    assert.deepEqual(setup.input.files, [edited, pdf, dropped])
    assert.equal(setup.previewName.textContent, "notes.txt")
    assert.equal(setup.name.textContent, "3 files")
    assert.equal(setup.previewPosition.textContent, "3/3")
    assert.equal(setup.metadata.parent, setup.root)
    assert.equal(setup.metadata.parent.parent, setup.form)
  } finally {
    preview.context.destroyed()
    setup.cleanup()
    await settled()
  }
})

test("a preview mounted before its input reads canonical portal metadata without changing the inert source", async () => {
  const setup = fixture({fileSelection: "singles", fileUploadName: "photos", filePreview: "false"}, false)
  const preview = detachedPreview(setup)
  try {
    const a = serverItem(setup, {url: "/a.png", name: "source-a.png"})
    const b = serverItem(setup, {url: "/b.png", name: "source-b.png"})
    const filename = new Element()
    filename.textContent = " landscape.png "
    b.nodes.set("[data-file-filename]", filename)
    preview.source.nodes.set("[data-file-item]", [a, b])
    const faceA = serverItem(setup, {url: "/a.png", name: "stale-a.png"})
    const faceB = serverItem(setup, {url: "/b.png", name: "stale-b.png"})
    faceA.parent = faceB.parent = preview.collection
    preview.collection.nodes.set("[data-file-item]", [faceA, faceB])
    await settled()
    assert.equal(preview.collection.hidden, true)
    setup.context.mounted()
    assert.equal(setup.name.textContent, "source-a.png")
    setup.next.click()
    assert.equal(setup.name.textContent, "landscape.png")
    assert.equal(setup.inputPosition.textContent, "2/2")
    assert.equal(a.hidden, true)
    assert.equal(b.hidden, true)
    assert.equal(b.classes.has("hidden"), true)
    assert.equal(faceB.hidden, false)
    assert.equal(faceA.hidden, true)

    setup.root.dataset.filePreview = "true"
    setup.context.updated()
    preview.context.reconnected()
    await settled()
    assert.equal(preview.collection.hidden, false)
    assert.equal(setup.name.textContent, "2 files")
    assert.equal(setup.context.activeKey, "/b.png")
    assert.equal(setup.previewPosition.textContent, "2/2")
  } finally {
    preview.context.destroyed()
    setup.cleanup()
    await settled()
  }
})

test("detached preview removal releases media URLs while its input retains the accepted collection", async () => {
  const setup = fixture({fileSelection: "singles", fileEditor: "false"})
  const preview = detachedPreview(setup)
  let replacement
  try {
    await settled()
    const file = new File(["pdf"], "document.pdf", {type: "application/pdf"})
    setup.select(file)
    const originalURL = setup.pdf.src
    preview.context.destroyed()
    await settled()
    assert.equal(setup.pdf.src, undefined)
    assert.equal(setup.open.href, undefined)
    assert.deepEqual(setup.revoked, [originalURL])
    assert.deepEqual(setup.context.files, [file])
    assert.equal(setup.name.textContent, "1 file")
    assert.equal(setup.context.objectUrl, null)

    replacement = {...previewHook, el: preview.collection}
    replacement.mounted()
    await settled()
    assert.equal(setup.pdf.hidden, false)
    assert.notEqual(setup.pdf.src, originalURL)
    assert.equal(setup.created.at(-1).file, file)
    const replacementURL = setup.pdf.src
    setup.context.destroyed()
    assert.equal(preview.collection.hidden, true)
    assert.equal(setup.pdf.src, undefined)
    assert.equal(setup.open.href, undefined)
    assert.deepEqual(setup.revoked, [originalURL, replacementURL])
    setup.next.click()
    replacement.reconnected()
    await settled()
    assert.equal(preview.collection.hidden, true)
    assert.deepEqual(setup.context.files, [])
  } finally {
    replacement?.destroyed()
    if (!preview.context.disposed) preview.context.destroyed()
    setup.cleanup()
    await settled()
  }
})

test("detached collections synchronize hidden modes, keyboard focus, and preview-off filenames", async () => {
  const setup = fixture({fileSelection: "singles", fileEditor: "false", fileMode: "text"})
  const preview = detachedPreview(setup)
  try {
    await settled()
    const first = new File(["first"], "first.png", {type: "image/png"})
    const second = new File(["second"], "second.png", {type: "image/png"})
    setup.select(first)
    setup.select(second)
    setup.input.focusVisible = true
    setup.input.dispatchEvent(new UIEvent("focusin", {bubbles: true}))
    assert.equal(preview.collection.dataset.fileFocused, "true")
    assert.equal(preview.collection.dataset.fileMode, "text")
    setup.root.dataset.filePreview = "false"
    setup.context.updated()
    assert.equal(preview.collection.hidden, true)
    assert.equal(setup.name.textContent, "second.png")
    assert.equal(setup.inputPosition.textContent, "2/2")
    assert.equal(setup.image.src, undefined)
    setup.input.disabled = true
    setup.previous.click()
    assert.equal(setup.name.textContent, "first.png")
    assert.equal(setup.inputPosition.textContent, "1/2")
    setup.input.dispatchEvent(new UIEvent("focusout", {bubbles: true}))
    assert.equal(preview.collection.dataset.fileFocused, "false")
    setup.root.dataset.filePreview = "true"
    setup.root.dataset.fileMode = "hidden-text"
    setup.context.updated()
    assert.equal(preview.collection.hidden, true)
    setup.root.dataset.fileMode = "text-enabled"
    setup.context.updated()
    assert.equal(preview.collection.hidden, false)
    assert.equal(preview.collection.dataset.fileMode, "text-enabled")
    assert.equal(setup.previewPosition.textContent, "1/2")
    assert.equal(setup.caption.textContent, "first.png")
  } finally {
    preview.context.destroyed()
    setup.cleanup()
    await settled()
  }
})

test("portal source and connected patches preserve fresh Save slots and delegate compact removal to connected buttons", async () => {
  const setup = fixture({fileSelection: "singles", fileEditor: "false", fileUploadName: "photos"})
  const preview = detachedPreview(setup)
  try {
    const logo = serverItem(setup, {url: "/logo.png", name: "logo.png"})
    preview.source.nodes.set("[data-file-item]", [logo])
    const logoFace = serverItem(setup, {url: "/logo.png"})
    logoFace.parent = preview.collection
    preview.collection.nodes.set("[data-file-item]", [logoFace])
    await settled()
    const image = new File(["png"], "portrait.png", {type: "image/png"})
    const pdf = new File(["pdf"], "document.pdf", {type: "application/pdf"})
    setup.select(image)
    setup.select(pdf)
    const pendingImage = serverItem(setup, {ref: image._phxRef, name: image.name})
    const pendingPDF = serverItem(setup, {ref: pdf._phxRef, name: pdf.name, type: pdf.type})
    preview.source.nodes.set("[data-file-item]", [logo, pendingImage, pendingPDF])
    setup.root.dataset.fileEntryRefs = JSON.stringify([image._phxRef, pdf._phxRef])
    setup.context.updated()
    const pendingImageFace = serverItem(setup, {ref: image._phxRef})
    const pendingPDFFace = serverItem(setup, {ref: pdf._phxRef})
    pendingImageFace.parent = pendingPDFFace.parent = preview.collection
    preview.collection.nodes.set("[data-file-item]", [logoFace, pendingImageFace, pendingPDFFace])
    preview.context.updated()
    await settled()
    setup.previous.click()
    assert.equal(setup.context.activeKey, image._phxRef)
    assert.equal(setup.previewPosition.textContent, "2/3")

    const savedImage = serverItem(setup, {url: "/saved-image.png", name: image.name})
    const savedPDF = serverItem(setup, {url: "/saved-pdf.pdf", name: pdf.name, type: pdf.type})
    preview.source.nodes.set("[data-file-item]", [logo, savedImage, savedPDF, pendingImage, pendingPDF])
    setup.context.updated()
    const savedImageFace = serverItem(setup, {url: "/saved-image.png"})
    const savedPDFFace = serverItem(setup, {url: "/saved-pdf.pdf"})
    savedImageFace.parent = savedPDFFace.parent = preview.collection
    preview.collection.nodes.set("[data-file-item]", [logoFace, savedImageFace, savedPDFFace, pendingImageFace, pendingPDFFace])
    preview.context.updated()
    preview.context.updated()
    await settled()
    assert.deepEqual(setup.context.items.map(item => item.key), ["/logo.png", image._phxRef, pdf._phxRef])
    assert.equal(setup.name.textContent, "3 files")
    assert.equal(setup.previewPosition.textContent, "2/3")
    assert.equal(pendingImageFace.hidden, false)
    assert.equal(savedImageFace.hidden, true)
    assert.equal(pendingImage.hidden, true)

    setup.root.dataset.fileEntryRefs = "[]"
    preview.source.nodes.set("[data-file-item]", [logo, savedImage, savedPDF])
    setup.context.updated()
    preview.collection.nodes.set("[data-file-item]", [logoFace, savedImageFace, savedPDFFace])
    const remove = new Element(savedImageFace)
    const removals = []
    remove.addEventListener("click", () => removals.push("connected"))
    savedImageFace.nodes.set("button[phx-click='cancel_upload'], button[phx-click='remove_upload']", remove)
    const inertRemove = new Element(savedImage)
    inertRemove.addEventListener("click", () => removals.push("inert"))
    savedImage.nodes.set("button[phx-click='cancel_upload'], button[phx-click='remove_upload']", inertRemove)
    preview.context.updated()
    await settled()
    assert.equal(setup.context.activeKey, "/saved-image.png")
    assert.equal(setup.previewPosition.textContent, "2/3")
    assert.equal(savedImageFace.hidden, false)
    assert.equal(setup.name.textContent, "3 files")
    assert.deepEqual(setup.metadata.children, [])
    setup.root.dataset.filePreview = "false"
    setup.context.updated()
    assert.equal(setup.name.textContent, "portrait.png")
    assert.equal(setup.clear.hidden, false)
    setup.clear.click()
    assert.deepEqual(removals, ["connected"])
  } finally {
    preview.context.destroyed()
    setup.cleanup()
    await settled()
  }
})

test("detached saved and pending edits retain form metadata and wait for the input target's cancellation reply", async () => {
  const setup = fixture({fileSelection: "singles", fileUploadName: "photos"})
  const preview = detachedPreview(setup)
  try {
    const stored = serverItem(setup, {url: "/saved.png", name: "landscape.png"})
    const face = serverItem(setup, {url: "/saved.png", name: "stale.png"})
    face.parent = preview.collection
    const edit = new Element(face)
    edit.dataset.fileEdit = ""
    preview.source.nodes.set("[data-file-item]", [stored])
    preview.collection.nodes.set("[data-file-item]", [face])
    globalThis.fetch = async () => ({ok: true, blob: async () => new Blob(["saved bytes"], {type: "image/png"})})
    await settled()
    edit.click()
    await settled()
    assert.equal(Editor.instances.at(-1).file.name, "landscape.png")
    const first = new File(["first edit"], "landscape.png", {type: "image/png"})
    Editor.instances.at(-1).resolve(first)
    await settled()
    assert.deepEqual(setup.metadata.children.map(input => [input.name, input.value]), [
      [`photos_replacements[${first._phxRef}]`, "/saved.png"],
      ["photos_order[]", first._phxRef],
    ])
    assert.equal(setup.metadata.parent.parent, setup.form)
    const pending = serverItem(setup, {ref: first._phxRef, name: first.name})
    const pendingFace = serverItem(setup, {ref: first._phxRef, name: first.name})
    pendingFace.parent = preview.collection
    const pendingEdit = new Element(pendingFace)
    pendingEdit.dataset.fileEdit = ""
    preview.source.nodes.set("[data-file-item]", [stored, pending])
    preview.collection.nodes.set("[data-file-item]", [face, pendingFace])
    setup.root.dataset.fileEntryRefs = JSON.stringify([first._phxRef])
    setup.context.updated()
    setup.input["phx-target"] = "#editor-owner"
    const calls = []
    let reply
    setup.context.pushEventTo = (target, event, payload) => {
      calls.push({target, event, payload})
      return new Promise(resolve => { reply = resolve })
    }
    pendingEdit.click()
    await settled()
    assert.equal(Editor.instances.at(-1).file, first)
    assert.deepEqual(calls, [])
    const second = new File(["second edit"], "landscape.png", {type: "image/png"})
    Editor.instances.at(-1).resolve(second)
    await settled()
    assert.deepEqual(calls, [{target: "#editor-owner", event: "cancel_upload", payload: {ref: first._phxRef, upload: "photos"}}])
    assert.deepEqual(setup.context.files, [first])
    assert.equal(setup.metadata.children[0].name, `photos_replacements[${first._phxRef}]`)
    setup.root.dataset.fileEntryRefs = "[]"
    preview.source.nodes.set("[data-file-item]", [stored])
    preview.collection.nodes.set("[data-file-item]", [face])
    setup.context.updated()
    reply([{status: "fulfilled", value: {}}])
    await settled()
    assert.deepEqual(setup.context.files, [second])
    assert.deepEqual(setup.metadata.children.map(input => [input.name, input.value]), [
      [`photos_replacements[${second._phxRef}]`, "/saved.png"],
      ["photos_order[]", second._phxRef],
    ])
    assert.equal(setup.name.textContent, "1 file")
    assert.equal(setup.previewPosition.textContent, "1/1")
  } finally {
    preview.context.destroyed()
    setup.cleanup()
    await settled()
  }
})

test("separate input IDs isolate detached actions and inline preview hooks leave bubbling to the input", async () => {
  const first = fixture({fileSelection: "singles", fileEditor: "false"})
  const detached = detachedPreview(first)
  const second = fixture({fileSelection: "singles", fileEditor: "false"})
  const inlineCollection = new Element(second.root)
  Object.assign(inlineCollection.dataset, {fileInputId: second.input.id, fileDetached: "false", fileCollection: ""})
  for (const selector of ["[data-file-preview-region]", "[data-file-open][data-entry-ref]", "[data-file-stored]", "[data-file-item]", "[data-file-previous], [data-file-next]", "[data-file-position]"]) inlineCollection.nodes.set(selector, second.root.nodes.get(selector))
  second.previous.parent = second.next.parent = inlineCollection
  const inline = {...previewHook, el: inlineCollection}
  inline.mounted()
  try {
    await settled()
    first.select(new File(["A"], "a.png", {type: "image/png"}))
    first.select(new File(["B"], "b.png", {type: "image/png"}))
    second.select(new File(["C"], "c.png", {type: "image/png"}))
    second.select(new File(["D"], "d.png", {type: "image/png"}))
    first.previous.click()
    assert.equal(first.caption.textContent, "a.png")
    assert.equal(second.caption.textContent, "d.png")
    second.previous.click()
    assert.equal(second.caption.textContent, "c.png")
    assert.equal(first.caption.textContent, "a.png")
    assert.equal(first.previewPosition.textContent, "1/2")
    assert.equal(second.previewPosition.textContent, "1/2")
    detached.context.destroyed()
    await settled()
    assert.deepEqual(first.context.files.map(file => file.name), ["a.png", "b.png"])
    assert.deepEqual(second.context.files.map(file => file.name), ["c.png", "d.png"])
    assert.equal(inlineCollection.hidden, false)
    assert.equal(second.image.hidden, false)
  } finally {
    inline.destroyed()
    second.cleanup()
    if (!detached.context.disposed) detached.context.destroyed()
    first.cleanup()
    await settled()
  }
})

test("original image events are intercepted and only the approved image reaches normal form listeners", async () => {
  const setup = fixture({fileUploadName: "avatar"})
  try {
    const previous = new File(["previous"], "previous.png", {type: "image/png"})
    setup.context.acceptSelection(previous)
    setup.changes.length = 0
    const original = new File(["original"], "original.png", {type: "image/png"})
    setup.select(original)
    await settled()
    assert.deepEqual(setup.input.files, [previous])
    assert.deepEqual(setup.changes, [])
    const submit = new UIEvent("submit", {bubbles: true, cancelable: true})
    setup.form.dispatchEvent(submit)
    assert.equal(submit.defaultPrevented, true)
    const edited = new File(["cropped"], "cropped.png", {type: "image/png"})
    Editor.instances.at(-1).resolve(edited)
    await settled()
    assert.deepEqual(setup.input.files, [edited])
    assert.deepEqual(setup.changes, [[edited]])
    assert.equal(setup.context.preparing, false)
    assert.equal(setup.name.textContent, "cropped.png")
  } finally { setup.cleanup() }
})

test("cancel and a stale edit preserve the last accepted file without exposing rejected bytes", async () => {
  const setup = fixture()
  try {
    const previous = new File(["old"], "old.png", {type: "image/png"})
    setup.context.acceptSelection(previous)
    setup.changes.length = 0
    setup.select(new File(["first"], "first.png", {type: "image/png"}))
    await settled()
    const first = Editor.instances.at(-1)
    setup.select(new File(["second"], "second.png", {type: "image/png"}))
    await settled()
    assert.equal(first.destroyed, true)
    Editor.instances.at(-1).destroy()
    await settled()
    assert.deepEqual(setup.input.files, [previous])
    assert.deepEqual(setup.changes, [])
    assert.equal(setup.context.preparing, false)
  } finally { setup.cleanup() }
})

test("a disabled field cancels preparation and ignores dropped files", async () => {
  const setup = fixture()
  try {
    setup.select(new File(["image"], "image.png", {type: "image/png"}))
    await settled()
    const editor = Editor.instances.at(-1)
    setup.input.disabled = true
    setup.context.updated()
    assert.equal(editor.destroyed, true)
    assert.equal(setup.context.preparing, false)
    const drop = new UIEvent("drop", {bubbles: true, cancelable: true})
    drop.dataTransfer = {files: [new File(["pdf"], "document.pdf", {type: "application/pdf"})]}
    setup.root.dispatchEvent(drop)
    assert.deepEqual(setup.changes, [])
    assert.equal(Editor.instances.length, 1)
  } finally { setup.cleanup() }
})

test("image and PDF replacement revokes prior URLs and preview flag changes update the same selected file", () => {
  const setup = fixture({fileEditor: "false"})
  try {
    const image = new File(["image"], "image.png", {type: "image/png"})
    setup.select(image)
    assert.equal(setup.image.hidden, false)
    assert.equal(setup.stored.hidden, true)
    const firstURL = setup.image.src
    setup.root.dataset.filePreview = "false"
    setup.context.updated()
    assert.equal(setup.region.hidden, true)
    assert.deepEqual(setup.revoked, [firstURL])
    setup.root.dataset.filePreview = "true"
    setup.context.updated()
    assert.equal(setup.image.hidden, false)
    const nextURL = setup.image.src
    setup.select(new File(["pdf"], "document.pdf", {type: "application/pdf"}))
    assert.equal(setup.pdf.hidden, false)
    assert.equal(setup.open.href, setup.pdf.src)
    assert.deepEqual(setup.revoked, [firstURL, nextURL])
    globalThis.navigator.pdfViewerEnabled = false
    setup.select(new File(["another pdf"], "other.pdf", {type: "application/pdf"}))
    assert.equal(setup.pdf.hidden, true)
    assert.equal(setup.open.hidden, false)
    assert.equal(setup.readonly.textContent, "other.pdf")
    setup.form.dispatchEvent(new UIEvent("reset"))
    assert.equal(setup.region.hidden, true)
    assert.equal(setup.stored.hidden, false)
    assert.equal(setup.name.textContent, "Choose a file")
  } finally { setup.cleanup() }
})

test("pending file links keep their URLs until removal and release them on hook destruction", () => {
  const setup = fixture({fileUploadName: "attachment", fileEditor: "false"})
  try {
    const file = new File(["data"], "data.bin")
    file._phxRef = "7"
    setup.input.files = [file]
    const link = new Element()
    link.dataset.entryRef = "7"
    setup.root.nodes.set("[data-file-open][data-entry-ref]", [link])
    setup.context.updatePreview()
    const url = link.href
    setup.context.updatePreview()
    assert.equal(setup.created.length, 1)
    assert.deepEqual(setup.revoked, [])
    setup.root.nodes.set("[data-file-open][data-entry-ref]", [])
    setup.context.updated()
    assert.deepEqual(setup.revoked, [url])
    setup.root.nodes.set("[data-file-open][data-entry-ref]", [link])
    setup.context.updatePreview()
    const secondURL = link.href
    setup.context.destroyed()
    assert.deepEqual(setup.revoked, [url, secondURL])
  } finally { setup.cleanup() }
})

test("edited size failure retains the accepted selection and reports an actionable error", async () => {
  const setup = fixture({fileMaxSize: "2"})
  try {
    const previous = new File(["a"], "old.png", {type: "image/png"})
    setup.context.acceptSelection(previous)
    setup.changes.length = 0
    setup.select(new File(["new"], "new.png", {type: "image/png"}))
    await settled()
    Editor.instances.at(-1).resolve(new File(["too large"], "edited.png", {type: "image/png"}))
    await settled()
    assert.deepEqual(setup.input.files, [previous])
    assert.deepEqual(setup.changes, [])
    assert.equal(setup.error.hidden, false)
    assert.match(setup.error.textContent, /file size limit/)
    assert.equal(setup.context.preparing, false)
  } finally { setup.cleanup() }
})

test("native tag preview shows the filename and clear restores stored media and the native FileList", () => {
  const setup = fixture({fileEditor: "false", filePreviewAs: "tag"})
  try {
    setup.readonly.dataset.fileDefaultName = "Stored file"
    const file = new File(["image"], "image.png", {type: "image/png"})
    setup.select(file)
    assert.equal(setup.image.hidden, true)
    assert.equal(setup.previewName.hidden, false)
    assert.equal(setup.previewName.textContent, "image.png")
    assert.equal(setup.open.hidden, false)
    assert.equal(setup.clear.hidden, false)
    const url = setup.open.href
    setup.clear.dispatchEvent(new UIEvent("click", {bubbles: true, cancelable: true}))
    assert.deepEqual(setup.input.files, [])
    assert.equal(setup.region.hidden, true)
    assert.equal(setup.stored.hidden, false)
    assert.equal(setup.clear.hidden, true)
    assert.equal(setup.readonly.textContent, "Stored file")
    assert.deepEqual(setup.revoked, [url])
  } finally { setup.cleanup() }
})

test("local media preview stays single-file scoped and destruction cancels a delayed editor import", async () => {
  const setup = fixture({fileSelection: "multiple", fileEditor: "false"})
  try {
    setup.select(new File(["image"], "image.png", {type: "image/png"}))
    assert.equal(setup.region.hidden, true)
    assert.deepEqual(setup.created, [])
    setup.root.dataset.fileSelection = "single"
    setup.root.dataset.fileEditor = "true"
    setup.context.updated()
    let resolveImport
    globalThis.__loadImageEditor = () => new Promise(resolve => { resolveImport = resolve })
    setup.select(new File(["new"], "new.png", {type: "image/png"}))
    setup.context.destroyed()
    resolveImport({default: Editor})
    await settled()
    assert.equal(Editor.instances.length, 0)
    assert.equal(setup.context.disposed, true)
  } finally { setup.cleanup() }
})

test("removing the native preview region releases its media URL while retaining the accepted file", () => {
  const setup = fixture({fileEditor: "false"})
  try {
    const file = new File(["image"], "image.png", {type: "image/png"})
    setup.select(file)
    const url = setup.image.src
    setup.root.nodes.delete("[data-file-preview-region]")
    setup.context.updated()
    assert.deepEqual(setup.revoked, [url])
    assert.equal(setup.image.src, undefined)
    assert.equal(setup.context.objectUrl, null)
    assert.equal(setup.context.previewRegion, null)
    assert.deepEqual(setup.input.files, [file])
  } finally { setup.cleanup() }
})

test("the server-owned preview frame updates visibility while ignored media stays cached", () => {
  const setup = fixture({fileEditor: "false"})
  try {
    const container = new Element()
    setup.root.nodes.set("[data-file-preview-container]", container)
    setup.region.hidden = false
    setup.select(new File(["image"], "image.png", {type: "image/png"}))
    assert.equal(container.hidden, false)
    const url = setup.image.src
    container.hidden = true
    setup.context.updated()
    assert.equal(container.hidden, false)
    assert.equal(setup.image.src, url)
    setup.root.dataset.filePreviewAs = "tag"
    setup.context.updated()
    assert.equal(setup.previewName.hidden, false)
    assert.equal(setup.image.hidden, true)
    setup.context.clearSelection()
    assert.equal(container.hidden, true)
    assert.equal(setup.region.hidden, false)
  } finally { setup.cleanup() }
})

test("a rejected stale editor import cannot destroy a newer selection editor", async () => {
  const setup = fixture()
  try {
    let rejectImport
    globalThis.__loadImageEditor = () => new Promise((resolve, reject) => { rejectImport = reject })
    setup.select(new File(["first"], "first.png", {type: "image/png"}))
    globalThis.__loadImageEditor = async () => ({default: Editor})
    setup.select(new File(["second"], "second.png", {type: "image/png"}))
    await settled()
    const current = Editor.instances.at(-1)
    rejectImport(new Error("old import failed"))
    await settled()
    assert.notEqual(current.destroyed, true)
    assert.equal(setup.context.preparing, true)
    assert.equal(setup.error.hidden, true)
    current.destroy()
    await settled()
  } finally { setup.cleanup() }
})

test("singles accumulates one selection at a time and hands off the whole queue without duplicate native changes", () => {
  const setup = fixture({fileSelection: "singles", fileEditor: "false", fileMaxEntries: "2", fileUploadName: "photos"})
  try {
    const first = new File(["first"], "first.pdf", {type: "application/pdf"})
    const second = new File(["second"], "second.pdf", {type: "application/pdf"})
    setup.select(first)
    setup.select(second)
    assert.deepEqual(setup.input.files, [first, second])
    assert.deepEqual(setup.changes, [[first], [first, second]])
    assert.equal(setup.name.textContent, "2 files")
    setup.select(new File(["third"], "third.pdf", {type: "application/pdf"}))
    assert.deepEqual(setup.input.files, [first, second])
    assert.equal(setup.changes.length, 2)
    assert.match(setup.error.textContent, /Cancel a selected file/)
    assert.equal(setup.error.hidden, false)
  } finally { setup.cleanup() }
})

test("singles cycles stored and native pending items and keeps the active identity across patches", () => {
  const setup = fixture({fileSelection: "singles", fileEditor: "false"})
  try {
    const firstStored = serverItem(setup, {url: "/first.png"})
    const secondStored = serverItem(setup, {url: "/second.png"})
    setup.root.nodes.set("[data-file-item]", [firstStored, secondStored])
    setup.context.updated()
    assert.equal(firstStored.hidden, false)
    assert.equal(secondStored.hidden, true)
    const first = new File(["first"], "first.png", {type: "image/png"})
    const second = new File(["second"], "second.png", {type: "image/png"})
    setup.select(first)
    setup.select(second)
    assert.equal(setup.context.items.length, 4)
    assert.equal(setup.context.previewFile, second)
    assert.equal(firstStored.hidden, true)
    assert.equal(secondStored.hidden, true)
    assert.equal(setup.next.hidden, false)
    setup.previous.dispatchEvent(new UIEvent("click", {bubbles: true, cancelable: true}))
    assert.equal(setup.context.previewFile, first)
    setup.previous.dispatchEvent(new UIEvent("click", {bubbles: true, cancelable: true}))
    assert.equal(setup.context.activeKey, "/second.png")
    assert.equal(secondStored.hidden, false)
    assert.equal(secondStored.classes.has("hidden"), false)
    assert.equal(setup.region.hidden, true)
    setup.root.nodes.set("[data-file-item]", [secondStored, firstStored])
    setup.context.updated()
    assert.equal(setup.context.activeKey, "/second.png")
    assert.equal(secondStored.hidden, false)
    setup.next.dispatchEvent(new UIEvent("click", {bubbles: true, cancelable: true}))
    assert.equal(setup.context.activeKey, "/first.png")
  } finally { setup.cleanup() }
})

test("native pending re-edit replaces its position and clears only the active singles file", async () => {
  const setup = fixture({fileSelection: "singles", fileEditor: "false"})
  try {
    const first = new File(["first"], "first.png", {type: "image/png"})
    const second = new File(["second"], "second.png", {type: "image/png"})
    setup.select(first)
    setup.select(second)
    setup.root.dataset.fileEditor = "true"
    setup.context.updated()
    setup.edit.dispatchEvent(new UIEvent("click", {bubbles: true, cancelable: true}))
    await settled()
    assert.equal(Editor.instances.at(-1).file, second)
    const edited = new File(["edited"], "edited.png", {type: "image/png"})
    Editor.instances.at(-1).resolve(edited)
    await settled()
    assert.deepEqual(setup.input.files, [first, edited])
    setup.clear.dispatchEvent(new UIEvent("click", {bubbles: true, cancelable: true}))
    assert.deepEqual(setup.input.files, [first])
    assert.equal(setup.context.previewFile, first)
    setup.form.dispatchEvent(new UIEvent("reset"))
    assert.deepEqual(setup.input.files, [])
  } finally { setup.cleanup() }
})

test("LiveView pending re-edit cancels only after approval and waits for acknowledgement before replacing the queue", async () => {
  const setup = fixture({fileSelection: "singles", fileEditor: "false", fileUploadName: "photos", fileMaxEntries: "2"})
  try {
    const first = new File(["first"], "first.png", {type: "image/png"})
    const second = new File(["second"], "second.png", {type: "image/png"})
    setup.select(first)
    setup.select(second)
    setup.root.dataset.fileEntryRefs = JSON.stringify([first._phxRef, second._phxRef])
    setup.root.nodes.set("[data-file-item]", [serverItem(setup, {ref: first._phxRef}), serverItem(setup, {ref: second._phxRef})])
    setup.context.replacements.set(first, "/saved.png")
    setup.root.dataset.fileEditor = "true"
    setup.context.updated()
    const cancellations = []
    let acknowledge
    setup.context.pushEvent = (name, payload) => { cancellations.push({name, payload}); return new Promise(resolve => { acknowledge = resolve }) }
    setup.context.editSelection(first._phxRef)
    await settled()
    assert.deepEqual(cancellations, [])
    const edited = new File(["edited"], "edited.png", {type: "image/png"})
    Editor.instances.at(-1).resolve(edited)
    await settled()
    assert.deepEqual(cancellations, [{name: "cancel_upload", payload: {ref: first._phxRef, upload: "photos"}}])
    assert.deepEqual(setup.input.files, [first, second])
    assert.equal(setup.context.preparing, true)
    setup.root.dataset.fileEntryRefs = JSON.stringify([second._phxRef])
    setup.context.updated()
    acknowledge({})
    await settled()
    assert.deepEqual(setup.input.files, [edited, second])
    assert.equal(setup.context.preparing, false)
    assert.deepEqual(setup.metadata.children.map(input => [input.name, input.value]), [[`photos_replacements[${edited._phxRef}]`, "/saved.png"], ["photos_order[]", edited._phxRef], ["photos_order[]", second._phxRef]])
    assert.equal(setup.context.replacements.has(first), false)
  } finally { setup.cleanup() }
})

test("saved re-edit is fetched locally and cancel keeps the original while approval queues replacement metadata", async () => {
  const setup = fixture({fileSelection: "singles", fileUploadName: "photos"})
  try {
    const saved = serverItem(setup, {url: "/saved.png", name: "saved.png"})
    setup.root.nodes.set("[data-file-item]", [saved])
    setup.context.updated()
    const fetched = []
    globalThis.fetch = async (url, options) => { fetched.push({url, signal: options.signal}); return {ok: true, blob: async () => new Blob(["saved bytes"], {type: "image/png"})} }
    setup.context.editSelection("/saved.png")
    await settled()
    assert.equal(fetched[0].url, "/saved.png")
    assert.equal(Editor.instances.at(-1).file.name, "saved.png")
    assert.equal(await Editor.instances.at(-1).file.text(), "saved bytes")
    Editor.instances.at(-1).destroy()
    await settled()
    assert.equal(saved.hidden, false)
    assert.deepEqual(setup.input.files, [])
    setup.context.editSelection("/saved.png")
    await settled()
    const edited = new File(["edited"], "saved.png", {type: "image/png"})
    Editor.instances.at(-1).resolve(edited)
    await settled()
    assert.deepEqual(setup.input.files, [edited])
    assert.equal(saved.hidden, true)
    assert.deepEqual(setup.metadata.children.map(input => [input.name, input.value]), [[`photos_replacements[${edited._phxRef}]`, "/saved.png"], ["photos_order[]", edited._phxRef]])
    setup.root.dataset.fileEntryRefs = JSON.stringify([edited._phxRef])
    setup.root.nodes.set("[data-file-item]", [saved, serverItem(setup, {ref: edited._phxRef})])
    setup.context.updated()
    setup.root.dataset.fileEntryRefs = "[]"
    setup.root.nodes.set("[data-file-item]", [saved])
    setup.context.updated()
    assert.equal(saved.hidden, false)
    assert.deepEqual(setup.metadata.children, [])
    assert.deepEqual(setup.context.files, [])
  } finally { setup.cleanup() }
})

test("saved-image fetch failure and disabled-mode abort leave the saved item intact", async () => {
  const setup = fixture({fileSelection: "singles"})
  try {
    const saved = serverItem(setup, {url: "/saved.png"})
    setup.root.nodes.set("[data-file-item]", [saved])
    setup.context.updated()
    globalThis.fetch = async () => ({ok: false})
    setup.context.editSelection("/saved.png")
    await settled()
    assert.equal(setup.error.hidden, false)
    assert.match(setup.error.textContent, /saved image could not be opened/)
    assert.equal(saved.hidden, false)
    let signal
    globalThis.fetch = (url, options) => new Promise((resolve, reject) => {
      signal = options.signal
      signal.addEventListener("abort", () => reject(new Error("aborted")))
    })
    setup.context.editSelection("/saved.png")
    setup.input.disabled = true
    setup.context.updated()
    await settled()
    assert.equal(signal.aborted, true)
    assert.equal(setup.context.preparing, false)
    assert.equal(saved.hidden, false)
    assert.deepEqual(setup.input.files, [])
  } finally { setup.cleanup() }
})

test("server acknowledgements retain new queued Files and discard only refs that were acknowledged then removed", () => {
  const setup = fixture({fileSelection: "singles", fileEditor: "false", fileUploadName: "photos"})
  try {
    const first = new File(["first"], "first.png", {type: "image/png"})
    const second = new File(["second"], "second.png", {type: "image/png"})
    setup.select(first)
    setup.root.dataset.fileEntryRefs = JSON.stringify([first._phxRef])
    setup.context.updated()
    setup.select(second)
    setup.context.updated()
    assert.deepEqual(setup.context.files, [first, second])
    setup.root.dataset.fileEntryRefs = "[]"
    setup.context.updated()
    assert.deepEqual(setup.context.files, [second])
    setup.root.dataset.fileEntryRefs = JSON.stringify([second._phxRef])
    setup.context.updated()
    setup.root.dataset.fileEntryRefs = "[]"
    setup.context.updated()
    assert.deepEqual(setup.context.files, [])
  } finally { setup.cleanup() }
})

test("native image edit controls follow current disabled and preview state and omit SVG", async () => {
  const setup = fixture({fileSelection: "singles", fileEditor: "false"})
  try {
    setup.select(new File(["image"], "image.png", {type: "image/png"}))
    setup.root.dataset.fileEditor = "true"
    setup.context.updated()
    assert.equal(setup.edit.hidden, false)
    assert.equal(setup.edit.disabled, false)
    setup.input.disabled = true
    setup.context.updated()
    assert.equal(setup.edit.hidden, true)
    assert.equal(setup.edit.disabled, true)
    setup.input.disabled = false
    setup.root.dataset.filePreview = "false"
    setup.context.updated()
    setup.context.editSelection(setup.context.activeKey)
    assert.equal(Editor.instances.length, 0)
    setup.root.dataset.filePreview = "true"
    setup.select(new File(["svg"], "logo.svg", {type: "image/svg+xml"}))
    await settled()
    assert.equal(setup.edit.hidden, true)
    assert.equal(Editor.instances.length, 0)
  } finally { setup.cleanup() }
})

test("oversized pending edits leave the queued original and stored association intact without cancellation", async () => {
  const setup = fixture({fileSelection: "singles", fileEditor: "false", fileUploadName: "photos", fileMaxSize: "2"})
  try {
    const original = new File(["a"], "original.png", {type: "image/png"})
    setup.select(original)
    setup.root.nodes.set("[data-file-item]", [serverItem(setup, {ref: original._phxRef})])
    setup.root.dataset.fileEntryRefs = JSON.stringify([original._phxRef])
    setup.root.dataset.fileEditor = "true"
    setup.context.replacements.set(original, "/saved.png")
    setup.context.updated()
    let cancelled = false
    setup.context.pushEvent = async () => { cancelled = true }
    setup.context.editSelection(original._phxRef)
    await settled()
    Editor.instances.at(-1).resolve(new File(["oversized"], "edited.png", {type: "image/png"}))
    await settled()
    assert.equal(cancelled, false)
    assert.deepEqual(setup.input.files, [original])
    assert.equal(setup.context.replacements.get(original), "/saved.png")
    assert.equal(setup.error.hidden, false)
  } finally { setup.cleanup() }
})

test("native singles clear restores a locally replaced saved item while keeping other pending files", async () => {
  const setup = fixture({fileSelection: "singles", fileEditor: "false"})
  try {
    const saved = serverItem(setup, {url: "/saved.png"})
    setup.root.nodes.set("[data-file-item]", [saved])
    const first = new File(["first"], "first.png", {type: "image/png"})
    setup.select(first)
    setup.root.dataset.fileEditor = "true"
    setup.context.updated()
    globalThis.fetch = async () => ({ok: true, blob: async () => new Blob(["saved"], {type: "image/png"})})
    setup.context.editSelection("/saved.png")
    await settled()
    const edited = new File(["edited"], "edited.png", {type: "image/png"})
    Editor.instances.at(-1).resolve(edited)
    await settled()
    assert.deepEqual(setup.input.files, [first, edited])
    assert.equal(saved.hidden, true)
    assert.equal(setup.metadata.children[0].name.startsWith("files_replacements[local-"), true)
    setup.clear.dispatchEvent(new UIEvent("click", {bubbles: true, cancelable: true}))
    assert.deepEqual(setup.input.files, [first])
    assert.equal(setup.context.items.some(item => item.url === "/saved.png"), true)
    assert.deepEqual(setup.metadata.children, [])
  } finally { setup.cleanup() }
})

test("canonical pending File order wins over server append order after re-editing an earlier file", () => {
  const setup = fixture({fileSelection: "singles", fileEditor: "false", fileUploadName: "photos"})
  try {
    const first = new File(["first"], "first.png", {type: "image/png"})
    const second = new File(["second"], "second.png", {type: "image/png"})
    setup.select(first)
    setup.select(second)
    const edited = new File(["edited"], "edited.png", {type: "image/png"})
    setup.context.acceptSelection(edited, {file: first, ref: first._phxRef})
    const secondElement = serverItem(setup, {ref: second._phxRef})
    const editedElement = serverItem(setup, {ref: edited._phxRef})
    setup.root.nodes.set("[data-file-item]", [secondElement, editedElement])
    setup.root.dataset.fileEntryRefs = JSON.stringify([second._phxRef, edited._phxRef])
    setup.context.updated()
    assert.deepEqual(setup.context.files, [edited, second])
    assert.deepEqual(setup.context.items.map(item => item.ref), [edited._phxRef, second._phxRef])
    assert.equal(editedElement.hidden, false)
    setup.next.dispatchEvent(new UIEvent("click", {bubbles: true, cancelable: true}))
    assert.equal(secondElement.hidden, false)
    assert.deepEqual(setup.metadata.children.map(input => [input.name, input.value]), [["photos_order[]", edited._phxRef], ["photos_order[]", second._phxRef]])
  } finally { setup.cleanup() }
})

test("changing editor configuration cancels stale preparation and the next edit uses current constraints", async () => {
  const setup = fixture({fileSelection: "singles", fileEditor: "false"})
  try {
    const accepted = new File(["accepted"], "accepted.png", {type: "image/png"})
    setup.select(accepted)
    setup.root.dataset.fileEditor = "true"
    setup.context.updated()
    setup.context.editSelection(setup.context.activeKey)
    await settled()
    const freeEditor = Editor.instances.at(-1)
    const staleResult = freeEditor.resolve
    setup.root.dataset.fileEditor = "false"
    setup.context.updated()
    assert.equal(freeEditor.destroyed, true)
    assert.equal(setup.context.preparing, false)
    staleResult(new File(["stale"], "stale.png", {type: "image/png"}))
    await settled()
    assert.deepEqual(setup.input.files, [accepted])

    setup.root.dataset.fileEditor = JSON.stringify({width: 512, height: 512})
    setup.context.updated()
    setup.context.editSelection(setup.context.activeKey)
    await settled()
    const exactEditor = Editor.instances.at(-1)
    assert.deepEqual(exactEditor.options, {width: 512, height: 512, template: setup.editorTemplate})
    const exactResult = exactEditor.resolve
    setup.root.dataset.fileEditor = JSON.stringify({ratio: 16 / 9})
    setup.context.updated()
    assert.equal(exactEditor.destroyed, true)
    exactResult(new File(["old dimensions"], "old.png", {type: "image/png"}))
    await settled()
    assert.deepEqual(setup.input.files, [accepted])
    setup.context.editSelection(setup.context.activeKey)
    await settled()
    assert.deepEqual(Editor.instances.at(-1).options, {ratio: 16 / 9, template: setup.editorTemplate})
    const edited = new File(["current"], "current.png", {type: "image/png"})
    Editor.instances.at(-1).resolve(edited)
    await settled()
    assert.deepEqual(setup.input.files, [edited])
  } finally { setup.cleanup() }
})

test("LiveView reset awaits each server cancellation and retains replacement metadata until all replies", async () => {
  const setup = fixture({fileSelection: "singles", fileEditor: "false", fileUploadName: "photos"})
  try {
    const first = new File(["first"], "first.png", {type: "image/png"})
    const second = new File(["second"], "second.png", {type: "image/png"})
    setup.select(first)
    setup.select(second)
    setup.context.replacements.set(first, "/saved.png")
    setup.root.dataset.fileEntryRefs = JSON.stringify([first._phxRef, second._phxRef])
    setup.context.updated()
    const originalMetadata = setup.metadata.children.map(input => [input.name, input.value])
    const calls = []
    const replies = []
    setup.context.pushEvent = (name, payload) => {
      calls.push({name, payload})
      return new Promise(resolve => replies.push(resolve))
    }
    const reset = new UIEvent("reset", {bubbles: true, cancelable: true})
    setup.form.dispatchEvent(reset)
    assert.equal(reset.defaultPrevented, false)
    setup.input.files = []
    assert.equal(setup.context.preparing, true)
    assert.deepEqual(calls, [{name: "cancel_upload", payload: {ref: first._phxRef, upload: "photos"}}])
    assert.deepEqual(setup.context.files, [first, second])
    assert.deepEqual(setup.metadata.children.map(input => [input.name, input.value]), originalMetadata)
    const submit = new UIEvent("submit", {bubbles: true, cancelable: true})
    setup.form.dispatchEvent(submit)
    assert.equal(submit.defaultPrevented, true)
    setup.root.dataset.fileEntryRefs = JSON.stringify([second._phxRef])
    setup.context.updated()
    replies[0]({})
    await settled()
    assert.deepEqual(calls, [
      {name: "cancel_upload", payload: {ref: first._phxRef, upload: "photos"}},
      {name: "cancel_upload", payload: {ref: second._phxRef, upload: "photos"}},
    ])
    assert.deepEqual(setup.metadata.children.map(input => [input.name, input.value]), originalMetadata)
    setup.root.dataset.fileEntryRefs = "[]"
    setup.context.updated()
    replies[1]({})
    await settled()
    assert.equal(setup.context.preparing, false)
    assert.deepEqual(setup.context.files, [])
    assert.deepEqual(setup.input.files, [])
    assert.deepEqual(setup.metadata.children, [])
    assert.equal(setup.context.replacements.size, 0)
  } finally { setup.cleanup() }
})

test("a partially failed LiveView reset re-queues confirmed cancellations and preserves replacement associations", async () => {
  const setup = fixture({fileSelection: "singles", fileEditor: "false", fileUploadName: "photos"})
  try {
    const first = new File(["first"], "first.png", {type: "image/png"})
    const second = new File(["second"], "second.png", {type: "image/png"})
    setup.select(first)
    setup.select(second)
    setup.context.replacements.set(first, "/saved.png")
    setup.root.dataset.fileEntryRefs = JSON.stringify([first._phxRef, second._phxRef])
    setup.context.updated()
    let calls = 0
    setup.context.pushEvent = async () => {
      if (++calls === 2) throw new Error("connection failed")
      setup.root.dataset.fileEntryRefs = JSON.stringify([second._phxRef])
      setup.context.updated()
    }
    setup.form.dispatchEvent(new UIEvent("reset", {bubbles: true, cancelable: true}))
    setup.input.files = []
    await settled()
    assert.equal(setup.context.preparing, false)
    assert.equal(setup.context.files.length, 2)
    const restored = setup.context.files[0]
    assert.notEqual(restored._phxRef, first._phxRef)
    assert.equal(await restored.text(), "first")
    assert.equal(restored.name, "first.png")
    assert.equal(setup.context.files[1], second)
    assert.deepEqual(setup.input.files, [restored, second])
    assert.equal(setup.context.replacements.get(restored), "/saved.png")
    assert.deepEqual(setup.metadata.children.map(input => [input.name, input.value]), [[`photos_replacements[${restored._phxRef}]`, "/saved.png"], ["photos_order[]", restored._phxRef], ["photos_order[]", second._phxRef]])
    assert.equal(setup.error.hidden, false)
    assert.match(setup.error.textContent, /could not be reset/)
  } finally { setup.cleanup() }
})

test("saved re-edit keeps its carousel slot through pending preview, cancel, and Save", async () => {
  const setup = fixture({fileSelection: "singles", fileUploadName: "photos"})
  try {
    const a = serverItem(setup, {url: "/a.png", name: "a.png"})
    const b = serverItem(setup, {url: "/b.png", name: "b.png"})
    const c = serverItem(setup, {url: "/c.png", name: "c.png"})
    setup.root.nodes.set("[data-file-item]", [a, b, c])
    setup.context.updated()
    setup.next.dispatchEvent(new UIEvent("click", {bubbles: true, cancelable: true}))
    assert.equal(setup.context.activeKey, "/b.png")
    globalThis.fetch = async () => ({ok: true, blob: async () => new Blob(["saved B"], {type: "image/png"})})
    setup.context.editSelection("/b.png")
    await settled()
    const edited = new File(["edited B"], "b.png", {type: "image/png"})
    Editor.instances.at(-1).resolve(edited)
    await settled()
    assert.deepEqual(setup.context.items.map(item => item.key), ["/a.png", edited._phxRef, "/c.png"])
    assert.equal(setup.context.items.findIndex(item => item.key === setup.context.activeKey), 1)
    const pending = serverItem(setup, {ref: edited._phxRef})
    setup.root.dataset.fileEntryRefs = JSON.stringify([edited._phxRef])
    setup.root.nodes.set("[data-file-item]", [a, b, c, pending])
    setup.context.updated()
    assert.deepEqual(setup.context.items.map(item => item.key), ["/a.png", edited._phxRef, "/c.png"])
    assert.equal(pending.hidden, false)
    assert.equal(b.hidden, true)

    setup.root.dataset.fileEntryRefs = "[]"
    setup.root.nodes.set("[data-file-item]", [a, b, c])
    setup.context.updated()
    assert.deepEqual(setup.context.items.map(item => item.key), ["/a.png", "/b.png", "/c.png"])
    assert.equal(setup.context.activeKey, "/b.png")
    assert.equal(b.hidden, false)
    setup.context.editSelection("/b.png")
    await settled()
    const savedEdit = new File(["saved edit B"], "b.png", {type: "image/png"})
    Editor.instances.at(-1).resolve(savedEdit)
    await settled()
    setup.root.dataset.fileEntryRefs = JSON.stringify([savedEdit._phxRef])
    setup.root.nodes.set("[data-file-item]", [a, b, c, serverItem(setup, {ref: savedEdit._phxRef})])
    setup.context.updated()
    const savedReplacement = serverItem(setup, {url: "/b-edited.png", name: "b.png"})
    setup.root.dataset.fileEntryRefs = "[]"
    setup.root.nodes.set("[data-file-item]", [a, savedReplacement, c])
    setup.context.updated()
    assert.deepEqual(setup.context.items.map(item => item.key), ["/a.png", "/b-edited.png", "/c.png"])
    assert.equal(setup.context.activeKey, "/b-edited.png")
    assert.equal(savedReplacement.hidden, false)
  } finally { setup.cleanup() }
})

test("fresh files append after saved replacement slots without displacing the queued replacements", () => {
  const setup = fixture({fileSelection: "singles", fileEditor: "false", fileUploadName: "photos"})
  try {
    const a = serverItem(setup, {url: "/a.png"})
    const b = serverItem(setup, {url: "/b.png"})
    const c = serverItem(setup, {url: "/c.png"})
    setup.root.nodes.set("[data-file-item]", [a, b, c])
    setup.context.updated()
    const replacement = new File(["replacement"], "b.png", {type: "image/png"})
    setup.context.acceptSelection(replacement, {url: "/b.png"})
    const fresh = new File(["fresh"], "fresh.png", {type: "image/png"})
    setup.select(fresh)
    assert.deepEqual(setup.context.items.map(item => item.key), ["/a.png", replacement._phxRef, "/c.png", fresh._phxRef])
    assert.deepEqual(setup.context.files, [replacement, fresh])
    setup.root.dataset.fileEntryRefs = JSON.stringify([replacement._phxRef, fresh._phxRef])
    setup.root.nodes.set("[data-file-item]", [a, b, c, serverItem(setup, {ref: fresh._phxRef}), serverItem(setup, {ref: replacement._phxRef})])
    setup.context.updated()
    assert.deepEqual(setup.context.items.map(item => item.key), ["/a.png", replacement._phxRef, "/c.png", fresh._phxRef])
  } finally { setup.cleanup() }
})

test("separate saved-URL and consumed-ref patches keep an edited saved image in its active slot", () => {
  const setup = fixture({fileSelection: "singles", fileEditor: "false", fileUploadName: "photos"})
  try {
    const a = serverItem(setup, {url: "/a.png"})
    const b = serverItem(setup, {url: "/b.png"})
    const c = serverItem(setup, {url: "/c.png"})
    setup.root.nodes.set("[data-file-item]", [a, b, c])
    setup.context.updated()
    const edited = new File(["edited B"], "b.png", {type: "image/png"})
    setup.context.acceptSelection(edited, {url: "/b.png"})
    const pending = serverItem(setup, {ref: edited._phxRef})
    setup.root.dataset.fileEntryRefs = JSON.stringify([edited._phxRef])
    setup.root.nodes.set("[data-file-item]", [a, b, c, pending])
    setup.context.updated()
    assert.equal(setup.context.items.findIndex(item => item.key === setup.context.activeKey), 1)
    assert.equal(setup.inputPosition.textContent, "2/3")

    const saved = serverItem(setup, {url: "/saved-b.png"})
    setup.root.nodes.set("[data-file-item]", [a, saved, c, pending])
    setup.context.updated()
    assert.deepEqual(setup.context.items.map(item => item.key), ["/a.png", edited._phxRef, "/c.png"])
    assert.equal(setup.context.activeKey, edited._phxRef)
    assert.equal(pending.hidden, false)
    assert.equal(saved.hidden, true)
    assert.equal(saved.classes.has("hidden"), true)
    assert.equal(setup.previewPosition.textContent, "2/3")

    setup.root.dataset.fileEntryRefs = "[]"
    setup.root.nodes.set("[data-file-item]", [a, saved, c])
    setup.context.updated()
    assert.deepEqual(setup.context.items.map(item => item.key), ["/a.png", "/saved-b.png", "/c.png"])
    assert.equal(setup.context.activeKey, "/saved-b.png")
    assert.equal(setup.context.items.findIndex(item => item.key === setup.context.activeKey), 1)
    assert.equal(saved.hidden, false)
    assert.equal(saved.classes.has("hidden"), false)
    assert.equal(setup.inputPosition.textContent, "2/3")
    assert.equal(setup.previewPosition.textContent, "2/3")
  } finally { setup.cleanup() }
})

test("singles count uses logical stored and queued slots once through replacement and separate Save patches", () => {
  const setup = fixture({fileSelection: "singles", fileEditor: "false", fileUploadName: "photos"})
  try {
    assert.equal(setup.name.textContent, "0 files")
    assert.equal(setup.readonly.textContent, "0 files")
    const a = serverItem(setup, {url: "/a.png"})
    const b = serverItem(setup, {url: "/b.png"})
    setup.root.nodes.set("[data-file-item]", [a])
    setup.context.updated()
    assert.equal(setup.name.textContent, "1 file")
    setup.root.nodes.set("[data-file-item]", [a, b])
    setup.context.updated()
    assert.equal(setup.name.textContent, "2 files")
    const replacement = new File(["edited B"], "b.png", {type: "image/png"})
    setup.context.acceptSelection(replacement, {url: "/b.png"})
    assert.equal(setup.name.textContent, "2 files")
    const pending = serverItem(setup, {ref: replacement._phxRef})
    setup.root.dataset.fileEntryRefs = JSON.stringify([replacement._phxRef])
    setup.root.nodes.set("[data-file-item]", [a, b, pending])
    setup.context.updated()
    assert.equal(setup.name.textContent, "2 files")
    const saved = serverItem(setup, {url: "/saved-b.png"})
    setup.root.nodes.set("[data-file-item]", [a, saved, pending])
    setup.context.updated()
    assert.equal(setup.name.textContent, "2 files")
    setup.root.dataset.fileEntryRefs = "[]"
    setup.root.nodes.set("[data-file-item]", [a, saved])
    setup.context.updated()
    assert.equal(setup.name.textContent, "2 files")
    assert.equal(setup.readonly.textContent, "2 files")
    setup.root.nodes.set("[data-file-item]", [])
    setup.context.updated()
    assert.equal(setup.name.textContent, "0 files")
  } finally { setup.cleanup() }
})

test("native single thumbnail captions follow the active file and stay hidden for tag, disabled preview, and multiple displays", () => {
  const setup = fixture({fileSelection: "single", fileEditor: "false"})
  try {
    const image = new File(["image"], "portrait.png", {type: "image/png"})
    setup.select(image)
    assert.equal(setup.caption.textContent, "portrait.png")
    assert.equal(setup.caption.hidden, false)
    setup.input.disabled = true
    setup.context.updated()
    assert.equal(setup.caption.hidden, false)
    setup.root.dataset.filePreview = "false"
    setup.context.updated()
    assert.equal(setup.caption.hidden, true)
    setup.root.dataset.filePreview = "true"
    setup.context.updated()
    assert.equal(setup.caption.hidden, false)
    setup.root.dataset.filePreviewAs = "tag"
    setup.context.updated()
    assert.equal(setup.caption.hidden, true)
    assert.equal(setup.previewName.textContent, "portrait.png")
    assert.equal(setup.previewName.hidden, false)
    setup.root.dataset.filePreviewAs = "thumbnail"
    setup.input.disabled = false
    setup.context.updated()
    setup.select(new File(["pdf"], "document.pdf", {type: "application/pdf"}))
    assert.equal(setup.caption.textContent, "document.pdf")
    assert.equal(setup.caption.hidden, false)
    setup.select(new File(["text"], "notes.txt", {type: "text/plain"}))
    assert.equal(setup.caption.hidden, true)
    assert.equal(setup.previewName.textContent, "notes.txt")
    assert.equal(setup.previewName.hidden, false)
    setup.select(image)
    setup.root.dataset.fileSelection = "multiple"
    setup.context.updated()
    assert.equal(setup.caption.hidden, true)
    setup.form.dispatchEvent(new UIEvent("reset"))
    assert.equal(setup.caption.textContent, "")
    assert.equal(setup.caption.hidden, true)
  } finally { setup.cleanup() }
})

test("native singles count stays fixed while cycling filenames and updates after clear and reset", () => {
  const setup = fixture({fileSelection: "singles", fileEditor: "false"})
  try {
    const image = new File(["image"], "portrait.png", {type: "image/png"})
    const pdf = new File(["pdf"], "document.pdf", {type: "application/pdf"})
    assert.equal(setup.name.textContent, "0 files")
    setup.select(image)
    assert.equal(setup.name.textContent, "1 file")
    assert.equal(setup.caption.textContent, "portrait.png")
    assert.equal(setup.caption.hidden, false)
    setup.select(pdf)
    assert.equal(setup.name.textContent, "2 files")
    assert.equal(setup.caption.textContent, "document.pdf")
    setup.previous.dispatchEvent(new UIEvent("click", {bubbles: true, cancelable: true}))
    assert.equal(setup.name.textContent, "2 files")
    assert.equal(setup.caption.textContent, "portrait.png")
    setup.input.disabled = true
    setup.context.updated()
    assert.equal(setup.readonly.textContent, "2 files")
    assert.equal(setup.caption.textContent, "portrait.png")
    setup.input.disabled = false
    setup.root.dataset.filePreviewAs = "tag"
    setup.context.updated()
    assert.equal(setup.caption.hidden, true)
    assert.equal(setup.previewName.textContent, "portrait.png")
    assert.equal(setup.previewName.hidden, false)
    setup.clear.dispatchEvent(new UIEvent("click", {bubbles: true, cancelable: true}))
    assert.equal(setup.name.textContent, "1 file")
    assert.equal(setup.previewName.textContent, "document.pdf")
    setup.form.dispatchEvent(new UIEvent("reset"))
    assert.equal(setup.name.textContent, "0 files")
    assert.equal(setup.caption.textContent, "")
    assert.equal(setup.caption.hidden, true)
    setup.root.dataset.fileSelection = "single"
    setup.name.dataset.fileDefaultName = "Choose a file"
    setup.context.updated()
    assert.equal(setup.name.textContent, "Choose a file")
    setup.select(image)
    assert.equal(setup.name.textContent, "portrait.png")
  } finally { setup.cleanup() }
})

test("preview-disabled singles show the active filename while multiple keeps its filename display", () => {
  const setup = fixture({fileSelection: "singles", fileEditor: "false", filePreview: "false"})
  try {
    setup.root.nodes.delete("[data-file-preview-region]")
    const image = new File(["image"], "image.png", {type: "image/png"})
    setup.select(image)
    assert.equal(setup.name.textContent, "image.png")
    assert.equal(setup.readonly.textContent, "image.png")
    assert.deepEqual(setup.created, [])
    setup.root.dataset.fileSelection = "multiple"
    setup.context.updated()
    setup.input.files = [image, new File(["pdf"], "document.pdf", {type: "application/pdf"})]
    setup.input.dispatchEvent(new UIEvent("input", {bubbles: true}))
    setup.input.dispatchEvent(new UIEvent("change", {bubbles: true}))
    assert.equal(setup.name.textContent, "image.png, document.pdf")
  } finally { setup.cleanup() }
})

test("a saved data-URI image keeps its rendered filename through re-edit and queued caption", async () => {
  const setup = fixture({fileSelection: "singles"})
  try {
    const url = "data:image/png;base64,c2F2ZWQ="
    const saved = serverItem(setup, {url, name: "Image"})
    const caption = new Element()
    caption.textContent = "  landscape.png\n "
    saved.nodes.set("[data-file-caption]", caption)
    setup.root.nodes.set("[data-file-item]", [saved])
    setup.context.updated()
    assert.equal(setup.context.items[0].name, "landscape.png")
    globalThis.fetch = async () => ({ok: true, blob: async () => new Blob(["saved bytes"], {type: "image/png"})})
    setup.context.editSelection(url)
    await settled()
    const editor = Editor.instances.at(-1)
    assert.equal(editor.file.name, "landscape.png")
    editor.resolve(new File(["edited bytes"], editor.file.name, {type: "image/png"}))
    await settled()
    assert.equal(setup.input.files[0].name, "landscape.png")
    assert.equal(setup.context.items[0].name, "landscape.png")
    assert.equal(setup.caption.textContent, "landscape.png")
    assert.equal(setup.caption.hidden, false)
    assert.equal(setup.name.textContent, "1 file")
  } finally { setup.cleanup() }
})

test("preview-off singles show active filenames and positions through both sets of controls and readonly toggles", () => {
  const setup = fixture({fileSelection: "singles", fileEditor: "true", filePreview: "false"})
  try {
    const inputPrevious = new Element(setup.root)
    Object.assign(inputPrevious.dataset, {filePrevious: "", fileCycleInput: "previous"})
    const inputNext = new Element(setup.root)
    Object.assign(inputNext.dataset, {fileNext: "", fileCycleInput: "next"})
    inputPrevious.hidden = inputNext.hidden = false
    setup.root.nodes.set("[data-file-previous], [data-file-next]", [setup.previous, setup.next, inputPrevious, inputNext])
    setup.context.updated()
    assert.equal(setup.name.textContent, "Choose a file")
    assert.equal(setup.inputPosition.textContent, "0/0")
    assert.equal(setup.previewPosition.textContent, "0/0")
    assert.equal(inputNext.hidden, false)
    assert.equal(inputNext.disabled, true)
    const image = new File(["portrait"], "portrait.png", {type: "image/png"})
    const pdf = new File(["document"], "document.pdf", {type: "application/pdf"})
    setup.select(image)
    assert.equal(setup.name.textContent, "portrait.png")
    assert.equal(setup.inputPosition.textContent, "1/1")
    assert.equal(inputNext.disabled, true)
    setup.select(pdf)
    assert.equal(setup.name.textContent, "document.pdf")
    assert.equal(setup.inputPosition.textContent, "2/2")
    assert.equal(inputNext.disabled, false)
    assert.equal(Editor.instances.length, 0)
    inputPrevious.dispatchEvent(new UIEvent("click", {bubbles: true, cancelable: true}))
    assert.equal(setup.name.textContent, "portrait.png")
    assert.equal(setup.inputPosition.textContent, "1/2")
    setup.root.dataset.filePreview = "true"
    setup.context.updated()
    assert.equal(setup.name.textContent, "2 files")
    assert.equal(setup.previewPosition.textContent, "1/2")
    setup.input.disabled = true
    setup.context.updated()
    setup.next.dispatchEvent(new UIEvent("click", {bubbles: true, cancelable: true}))
    assert.equal(setup.previewPosition.textContent, "2/2")
    assert.equal(setup.caption.textContent, "document.pdf")
    setup.root.dataset.filePreview = "false"
    setup.context.updated()
    assert.equal(setup.name.textContent, "document.pdf")
    assert.equal(setup.readonly.textContent, "document.pdf")
    inputPrevious.dispatchEvent(new UIEvent("click", {bubbles: true, cancelable: true}))
    assert.equal(setup.name.textContent, "portrait.png")
    assert.equal(setup.inputPosition.textContent, "1/2")
    assert.equal(inputPrevious.disabled, false)
    setup.input.disabled = false
    setup.context.updated()
    setup.clear.dispatchEvent(new UIEvent("click", {bubbles: true, cancelable: true}))
    assert.equal(setup.name.textContent, "document.pdf")
    assert.equal(setup.inputPosition.textContent, "1/1")
    assert.equal(inputPrevious.disabled, true)
    assert.equal(inputNext.hidden, false)
    assert.equal(setup.next.hidden, true)
    setup.form.dispatchEvent(new UIEvent("reset"))
    assert.equal(setup.name.textContent, "Choose a file")
    assert.equal(setup.inputPosition.textContent, "0/0")
    assert.equal(setup.previewPosition.textContent, "0/0")
  } finally { setup.cleanup() }
})

test("canonical saved filename stays available without hover markup and survives preview toggles and re-edit", async () => {
  const setup = fixture({fileSelection: "singles", filePreview: "false"})
  try {
    const url = "data:image/png;base64,c2F2ZWQ="
    const saved = serverItem(setup, {url, name: "Image"})
    const filename = new Element()
    filename.textContent = " landscape.png "
    saved.nodes.set("[data-file-filename]", filename)
    setup.root.nodes.set("[data-file-item]", [saved])
    setup.context.updated()
    assert.equal(setup.name.textContent, "landscape.png")
    assert.equal(setup.inputPosition.textContent, "1/1")
    setup.context.editSelection(url)
    await settled()
    assert.equal(Editor.instances.length, 0)
    setup.root.dataset.filePreview = "true"
    setup.context.updated()
    assert.equal(setup.name.textContent, "1 file")
    globalThis.fetch = async () => ({ok: true, blob: async () => new Blob(["saved"], {type: "image/png"})})
    setup.context.editSelection(url)
    await settled()
    assert.equal(Editor.instances.at(-1).file.name, "landscape.png")
    Editor.instances.at(-1).resolve(new File(["edited"], "landscape.png", {type: "image/png"}))
    await settled()
    setup.root.dataset.filePreview = "false"
    setup.context.updated()
    assert.equal(setup.name.textContent, "landscape.png")
    assert.equal(setup.readonly.textContent, "landscape.png")
    assert.equal(setup.inputPosition.textContent, "1/1")
  } finally { setup.cleanup() }
})

test("compact LiveView clear forwards existing cancel and remove buttons and reflects acknowledged collection changes", () => {
  const setup = fixture({fileSelection: "singles", fileEditor: "false", filePreview: "false", fileUploadName: "photos"})
  try {
    const a = serverItem(setup, {url: "/a.png", name: "a.png"})
    const b = serverItem(setup, {url: "/b.png", name: "b.png"})
    const clicked = []
    const remove = new Element(b)
    remove["phx-click"] = "remove_upload"
    remove.addEventListener("click", () => clicked.push({event: remove["phx-click"], url: "/b.png"}))
    b.nodes.set("button[phx-click='cancel_upload'], button[phx-click='remove_upload']", remove)
    setup.root.nodes.set("[data-file-item]", [a, b])
    setup.context.updated()
    setup.next.click()
    assert.equal(setup.name.textContent, "b.png")
    assert.equal(setup.inputPosition.textContent, "2/2")
    assert.equal(setup.clear.hidden, false)
    setup.clear.click()
    assert.deepEqual(clicked, [{event: "remove_upload", url: "/b.png"}])
    assert.equal(setup.context.items.length, 2)
    setup.root.nodes.set("[data-file-item]", [a])
    setup.context.updated()
    assert.equal(setup.name.textContent, "a.png")
    assert.equal(setup.inputPosition.textContent, "1/1")

    const file = new File(["pending"], "pending.png", {type: "image/png"})
    setup.select(file)
    const pending = serverItem(setup, {ref: file._phxRef, name: "pending.png"})
    const cancel = new Element(pending)
    cancel["phx-click"] = "cancel_upload"
    cancel.addEventListener("click", () => clicked.push({event: cancel["phx-click"], ref: file._phxRef}))
    pending.nodes.set("button[phx-click='cancel_upload'], button[phx-click='remove_upload']", cancel)
    setup.root.dataset.fileEntryRefs = JSON.stringify([file._phxRef])
    setup.root.nodes.set("[data-file-item]", [a, pending])
    setup.context.updated()
    assert.equal(setup.name.textContent, "pending.png")
    assert.equal(setup.inputPosition.textContent, "2/2")
    setup.clear.click()
    assert.deepEqual(clicked.at(-1), {event: "cancel_upload", ref: file._phxRef})
    assert.deepEqual(setup.context.files, [file])
    setup.root.dataset.fileEntryRefs = "[]"
    setup.root.nodes.set("[data-file-item]", [a])
    setup.context.updated()
    assert.deepEqual(setup.context.files, [])
    assert.equal(setup.name.textContent, "a.png")
    assert.equal(setup.inputPosition.textContent, "1/1")
    setup.input.disabled = true
    setup.context.updated()
    assert.equal(setup.clear.hidden, true)
  } finally { setup.cleanup() }
})

test("single preview-off shows a stored or picked filename and never opens an image editor", async () => {
  const setup = fixture({fileSelection: "single", fileEditor: "true", filePreview: "false"})
  try {
    const saved = serverItem(setup, {url: "/saved.png", name: "saved.png"})
    setup.root.nodes.set("[data-file-item]", [saved])
    setup.context.updated()
    assert.equal(setup.name.textContent, "saved.png")
    const picked = new File(["picked"], "picked.png", {type: "image/png"})
    setup.select(picked)
    await settled()
    assert.equal(setup.name.textContent, "picked.png")
    assert.equal(setup.readonly.textContent, "picked.png")
    assert.equal(Editor.instances.length, 0)
    assert.deepEqual(setup.input.files, [picked])
    setup.clear.click()
    assert.equal(setup.name.textContent, "saved.png")
    assert.deepEqual(setup.input.files, [])
  } finally { setup.cleanup() }
})

test("fresh Save patches keep pending files in their logical slots until consumed refs disappear", () => {
  const setup = fixture({fileSelection: "singles", fileEditor: "false", fileUploadName: "photos"})
  try {
    const logo = serverItem(setup, {url: "/logo.svg", name: "logo.svg", type: "image/svg+xml"})
    setup.root.nodes.set("[data-file-item]", [logo])
    setup.context.updated()
    const image = new File(["portrait"], "portrait.png", {type: "image/png"})
    const pdf = new File(["document"], "document.pdf", {type: "application/pdf"})
    setup.select(image)
    setup.select(pdf)
    const pendingImage = serverItem(setup, {ref: image._phxRef, name: image.name})
    const pendingPdf = serverItem(setup, {ref: pdf._phxRef, name: pdf.name, type: pdf.type})
    setup.root.dataset.fileEntryRefs = JSON.stringify([image._phxRef, pdf._phxRef])
    setup.root.nodes.set("[data-file-item]", [logo, pendingImage, pendingPdf])
    setup.context.updated()
    setup.previous.click()
    assert.equal(setup.context.activeKey, image._phxRef)
    assert.equal(setup.name.textContent, "3 files")
    assert.equal(setup.previewPosition.textContent, "2/3")

    const savedImage = serverItem(setup, {url: "/saved-portrait.png", name: image.name})
    const savedPdf = serverItem(setup, {url: "/saved-document.pdf", name: pdf.name, type: pdf.type})
    setup.root.nodes.set("[data-file-item]", [logo, savedImage, savedPdf, pendingImage, pendingPdf])
    setup.context.updated()
    assert.deepEqual(setup.context.items.map(item => item.key), ["/logo.svg", image._phxRef, pdf._phxRef])
    assert.equal(setup.context.activeKey, image._phxRef)
    assert.equal(setup.name.textContent, "3 files")
    assert.equal(setup.previewPosition.textContent, "2/3")
    assert.equal(savedImage.hidden, true)
    assert.equal(savedPdf.hidden, true)
    assert.equal(pendingImage.hidden, false)

    setup.root.dataset.fileEntryRefs = "[]"
    setup.root.nodes.set("[data-file-item]", [logo, savedImage, savedPdf])
    setup.context.updated()
    assert.deepEqual(setup.context.items.map(item => item.key), ["/logo.svg", "/saved-portrait.png", "/saved-document.pdf"])
    assert.equal(setup.context.activeKey, "/saved-portrait.png")
    assert.equal(setup.name.textContent, "3 files")
    assert.equal(setup.inputPosition.textContent, "2/3")
    assert.equal(setup.previewPosition.textContent, "2/3")
    assert.equal(savedImage.hidden, false)
    assert.equal(savedPdf.hidden, true)
    setup.root.dataset.filePreview = "false"
    setup.context.updated()
    assert.equal(setup.name.textContent, "portrait.png")
    assert.equal(setup.inputPosition.textContent, "2/3")
  } finally { setup.cleanup() }
})

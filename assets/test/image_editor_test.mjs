import test from "node:test"
import assert from "node:assert/strict"
import {readFile} from "node:fs/promises"

class Element extends EventTarget {
  constructor(tagName) {
    super()
    this.tagName = tagName
    this.dataset = {}
    this.nodes = new Map()
    this.children = []
  }
  setAttribute(name, value) { this[name] = value }
  appendChild(child) { this.children.push(child); child.parentNode = this }
  querySelector(selector) {
    if (selector === "[data-editor-action=confirm]") return this.buttons.find(button => button.dataset.editorAction === "confirm")
    return this.nodes.get(selector)
  }
  querySelectorAll() { return this.buttons }
  closest() { return this.dataset.editorAction ? this : null }
  getBoundingClientRect() {
    const {x, y, width, height} = this.rect
    return {x, y, width, height, left: x, top: y, right: x + width, bottom: y + height}
  }
  showModal() { this.open = true }
  close() { this.open = false }
  remove() { this.removed = true }
  click(action) {
    const button = this.buttons.find(button => button.dataset.editorAction === action)
    if (button.disabled) return
    const event = new Event("click")
    Object.defineProperty(event, "target", {value: button})
    this.dispatchEvent(event)
  }
}

class CropperImage extends Element {
  constructor() {
    super("cropper-image")
    this.scaleX = this.scaleY = 1
    this.rotation = 0
    this.rect = {x: 100, y: 50, width: 300, height: 150}
    this.readyPromise = new Promise((resolve, reject) => { this.resolveReady = resolve; this.rejectReady = reject })
  }
  $ready() { return this.readyPromise }
  change(rect) {
    const event = new Event("change", {cancelable: true})
    Object.defineProperty(event, "detail", {value: rect})
    if (this.dispatchEvent(event)) this.rect = rect
    return this
  }
  $rotate(angle) {
    this.rotation += parseInt(angle, 10)
    const {x, y, width, height} = this.rect
    return this.change({x: x + (width - height) / 2, y: y + (height - width) / 2, width: height, height: width})
  }
  $scale(x, y) { this.scaleX *= x; this.scaleY *= y; return this.change({...this.rect}) }
  $resetTransform() { this.resetCount = (this.resetCount || 0) + 1; this.scaleX = this.scaleY = 1; this.rotation = 0; return this.change({x: 100, y: 50, width: 300, height: 150}) }
  $center(fit) { this.fit = fit; return this.change({x: 100, y: 50, width: 300, height: 150}) }
}

class CropperSelection extends Element {
  constructor(aspectRatio) {
    super("cropper-selection")
    this.x = 130
    this.y = 65
    this.width = 240
    this.height = 120
    this.aspectRatio = aspectRatio
  }
  setAttribute(name, value) {
    super.setAttribute(name, value)
    if (name === "aspect-ratio") this.aspectRatio = Number(value)
  }
  $change(x, y, width = this.width, height = this.height) {
    const detail = {x, y, width, height}
    const event = new Event("change", {cancelable: true})
    Object.defineProperty(event, "detail", {value: detail})
    if (this.dispatchEvent(event)) Object.assign(this, detail)
    return this
  }
  $reset() { this.resetCount = (this.resetCount || 0) + 1; return this.$change(130, 65, 240, 120) }
}

class Dialog extends Element {
  constructor() {
    super("dialog")
    this.buttons = ["rotate-left", "rotate-right", "flip-horizontal", "flip-vertical", "reset", "cancel", "confirm"].map(action => {
      const button = new Element("button")
      button.dataset.editorAction = action
      return button
    })
    const container = new Element("div")
    const source = new Element("img")
    source.hidden = true
    source.alt = "Image to edit"
    const canvas = new Element("cropper-canvas")
    canvas.rect = {x: 0, y: 0, width: 600, height: 400}
    const image = new CropperImage()
    const selection = new CropperSelection(NaN)
    container.appendChild(source)
    container.appendChild(canvas)
    canvas.appendChild(image)
    canvas.appendChild(selection)
    container.nodes.set("cropper-canvas", canvas)
    container.nodes.set("cropper-image", image)
    container.nodes.set("cropper-selection", selection)
    this.nodes.set(".file-editor-canvas", container)
    this.nodes.set("[data-editor-source]", source)
    this.nodes.set("cropper-image", image)
    this.nodes.set("cropper-selection", selection)
    this.nodes.set("[data-editor-status]", new Element("p"))
    this.nodes.set("[data-editor-error]", new Element("p"))
    this.nodes.get("[data-editor-status]").textContent = "Loading image..."
    this.nodes.get("[data-editor-error]").hidden = true
  }
  cloneNode(deep) { assert.equal(deep, true); return new Dialog() }
}

class Cropper {
  static instances = []
  constructor(image, options) {
    Cropper.instances.push(this)
    this.image = image
    this.options = options
    this.cropperImage = options.container.querySelector("cropper-image")
    this.selection = options.container.querySelector("cropper-selection")
    this.canvas = options.container.querySelector("cropper-canvas")
  }
  ready() { this.cropperImage.resolveReady(this.image) }
  getCropperImage() { return this.cropperImage }
  getCropperSelection() { return this.selection }
  getCropperCanvas() { return this.canvas }
  destroy() { this.destroyed = true }
}

class SuperImageCropper {
  static instances = []
  constructor() { SuperImageCropper.instances.push(this) }
  crop(options) {
    this.options = options
    return new Promise((resolve, reject) => { this.resolve = resolve; this.reject = reject })
  }
  destroy() { this.destroyCount = (this.destroyCount || 0) + 1 }
}

const source = (await readFile(new URL("../js/image_editor.js", import.meta.url), "utf8"))
  .replace('import Cropper from "cropperjs"', "const Cropper = globalThis.__Cropper")
  .replace('import {SuperImageCropper} from "super-image-cropper"', "const SuperImageCropper = globalThis.__SuperImageCropper")
globalThis.__Cropper = Cropper
globalThis.__SuperImageCropper = SuperImageCropper
const ImageEditor = (await import(`data:text/javascript;base64,${Buffer.from(source).toString("base64")}`)).default
const settled = () => new Promise(resolve => setImmediate(resolve))

function fixture() {
  const original = {document: globalThis.document, create: URL.createObjectURL, revoke: URL.revokeObjectURL}
  const revoked = []
  const dialogs = []
  const templateDialog = new Dialog()
  const template = {content: new Element("fragment")}
  template.content.nodes.set("dialog", templateDialog)
  globalThis.document = {
    importNode(content, deep) {
      assert.equal(content, template.content)
      const fragment = new Element("fragment")
      fragment.nodes.set("dialog", content.querySelector("dialog").cloneNode(deep))
      return fragment
    },
    body: {appendChild: dialog => dialogs.push(dialog)},
  }
  let nextUrl = 0
  URL.createObjectURL = () => `blob:editor-${++nextUrl}`
  URL.revokeObjectURL = url => revoked.push(url)
  Cropper.instances = []
  SuperImageCropper.instances = []
  const editor = new ImageEditor()
  return {
    editor, dialogs, revoked, template, templateDialog,
    cleanup() {
      editor.destroy()
      globalThis.document = original.document
      URL.createObjectURL = original.create
      URL.revokeObjectURL = original.revoke
    },
  }
}

test("exact dimensions and source-resolution ratio crops use the fork with the original source", async () => {
  const setup = fixture()
  try {
    const file = new File(["image"], "profile.png", {type: "image/png"})
    const pending = setup.editor.edit(file, {width: 300, height: 150, template: setup.template})
    const cropper = Cropper.instances.at(-1)
    const dialog = setup.dialogs.at(-1)
    assert.equal(cropper.selection.aspectRatio, 2)
    assert.equal(cropper.options.template, null)
    assert.equal(cropper.options.container, dialog.querySelector(".file-editor-canvas"))
    assert.equal(cropper.cropperImage.src, "blob:editor-1")
    assert.notEqual(dialog, setup.templateDialog)
    assert.equal(setup.templateDialog.querySelector("[data-editor-source]").src, undefined)
    assert.equal(Number.isNaN(setup.templateDialog.querySelector("cropper-selection").aspectRatio), true)
    assert.equal(dialog.querySelector(".file-editor-canvas").children[0], cropper.image)
    assert.equal(cropper.image.src, "blob:editor-1")
    cropper.ready()
    await settled()
    dialog.click("confirm")
    dialog.click("confirm")
    assert.equal(SuperImageCropper.instances.length, 1)
    const processor = SuperImageCropper.instances.at(-1)
    assert.equal(processor.options.src, "blob:editor-1")
    assert.equal(processor.options.cropperInstance, cropper)
    assert.equal(processor.options.outputWidth, 300)
    assert.equal(processor.options.outputHeight, 150)
    assert.equal(processor.options.outputType, "blob")
    assert.equal(cropper.canvas.disabled, true)
    processor.resolve(new Blob(["prepared"], {type: "image/png"}))
    const prepared = await pending
    assert.equal(prepared.name, "profile.png")
    assert.equal(await prepared.text(), "prepared")
    assert.equal(processor.destroyCount, 1)
    assert.equal(cropper.destroyed, true)

    const ratioPending = setup.editor.edit(file, {ratio: 2, template: setup.template})
    const ratioCropper = Cropper.instances.at(-1)
    assert.equal(ratioCropper.selection.aspectRatio, 2)
    ratioCropper.ready()
    await settled()
    setup.dialogs.at(-1).click("confirm")
    const ratioProcessor = SuperImageCropper.instances.at(-1)
    assert.equal(ratioProcessor.options.outputWidth, undefined)
    assert.equal(ratioProcessor.options.outputHeight, undefined)
    assert.equal(ratioProcessor.options.cropperInstance.getCropperSelection().width, 240)
    assert.equal(ratioProcessor.options.cropperInstance.getCropperSelection().height, 120)
    setup.editor.destroy()
    ratioProcessor.reject(new DOMException("Aborted", "AbortError"))
    assert.equal(await ratioPending, null)
    await settled()
  } finally { setup.cleanup() }
})

test("cancel aborts GIF processing, destroys both engines, and releases the caller-owned source URL", async () => {
  const setup = fixture()
  try {
    const pending = setup.editor.edit(new File(["gif"], "avatar.gif", {type: "image/gif"}), {template: setup.template})
    const cropper = Cropper.instances.at(-1)
    assert.equal(Number.isNaN(cropper.selection.aspectRatio), true)
    cropper.ready()
    await settled()
    const dialog = setup.dialogs.at(-1)
    dialog.click("confirm")
    const processor = SuperImageCropper.instances.at(-1)
    assert.equal(dialog.querySelector("[data-editor-status]").textContent, "Preparing image...")
    assert.equal(dialog.buttons.find(button => button.dataset.editorAction === "cancel").disabled, false)
    const cancel = new Event("cancel", {cancelable: true})
    dialog.dispatchEvent(cancel)
    assert.equal(cancel.defaultPrevented, true)
    assert.equal(await pending, null)
    assert.equal(processor.options.signal.aborted, true)
    assert.equal(processor.destroyCount, 1)
    assert.equal(cropper.destroyed, true)
    assert.equal(dialog.removed, true)
    assert.deepEqual(setup.revoked, ["blob:editor-1"])
    processor.resolve(new Blob(["late GIF"], {type: "image/gif"}))
    await settled()
    assert.equal(setup.editor.dialog, null)
  } finally { setup.cleanup() }
})

test("late crop and image readiness callbacks cannot modify a replacement editor", async () => {
  const setup = fixture()
  try {
    const first = setup.editor.edit(new File(["first"], "first.png", {type: "image/png"}), {template: setup.template})
    const firstCropper = Cropper.instances.at(-1)
    firstCropper.ready()
    await settled()
    setup.dialogs.at(-1).click("confirm")
    const firstProcessor = SuperImageCropper.instances.at(-1)
    const second = setup.editor.edit(new File(["second"], "second.png", {type: "image/png"}), {template: setup.template})
    assert.equal(await first, null)
    const secondDialog = setup.dialogs.at(-1)
    firstCropper.ready()
    firstProcessor.resolve(new Blob(["stale"], {type: "image/png"}))
    await settled()
    assert.equal(secondDialog.querySelector("[data-editor-action=confirm]").disabled, true)
    const secondCropper = Cropper.instances.at(-1)
    secondCropper.ready()
    await settled()
    secondDialog.click("confirm")
    const secondProcessor = SuperImageCropper.instances.at(-1)
    secondProcessor.resolve(new Blob(["current"], {type: "image/webp"}))
    const accepted = await second
    assert.equal(accepted.name, "second.webp")
    assert.equal(accepted.type, "image/webp")
    assert.equal(await accepted.text(), "current")
    assert.equal(firstProcessor.destroyCount, 1)
    assert.equal(secondProcessor.destroyCount, 1)

    const loading = setup.editor.edit(new File(["loading"], "loading.png", {type: "image/png"}), {template: setup.template})
    const loadingCropper = Cropper.instances.at(-1)
    const current = setup.editor.edit(new File(["current"], "current.png", {type: "image/png"}), {template: setup.template})
    assert.equal(await loading, null)
    loadingCropper.ready()
    await settled()
    assert.equal(setup.dialogs.at(-1).querySelector("[data-editor-action=confirm]").disabled, true)
    assert.equal(setup.dialogs.at(-1).querySelector("[data-editor-status]").textContent, "Loading image...")
    setup.editor.destroy()
    assert.equal(await current, null)
  } finally { setup.cleanup() }
})

test("native Cropper rotate, flip, and reset actions remain available when processing fails", async () => {
  const setup = fixture()
  try {
    const pending = setup.editor.edit(new File(["image"], "picture.bmp", {type: "image/bmp"}), {template: setup.template})
    const cropper = Cropper.instances.at(-1)
    cropper.ready()
    await settled()
    const dialog = setup.dialogs.at(-1)
    dialog.click("rotate-left")
    assert.equal(cropper.cropperImage.rotation, -90)
    dialog.click("rotate-right")
    assert.equal(cropper.cropperImage.rotation, 0)
    dialog.click("flip-horizontal")
    assert.equal(cropper.cropperImage.scaleX, -1)
    dialog.click("flip-horizontal")
    assert.equal(cropper.cropperImage.scaleX, 1)
    dialog.click("flip-vertical")
    assert.equal(cropper.cropperImage.scaleY, -1)
    dialog.click("reset")
    assert.equal(cropper.cropperImage.resetCount, 1)
    assert.equal(cropper.cropperImage.scaleY, 1)
    assert.equal(cropper.cropperImage.fit, "contain")
    assert.equal(cropper.selection.resetCount, 1)
    dialog.click("confirm")
    const failed = SuperImageCropper.instances.at(-1)
    failed.reject(new Error("Unsupported image"))
    await settled()
    assert.equal(failed.destroyCount, 1)
    assert.equal(dialog.querySelector("[data-editor-error]").textContent, "Unsupported image")
    assert.equal(dialog.querySelector("[data-editor-error]").hidden, false)
    assert.equal(dialog.buttons.every(button => !button.disabled), true)
    assert.equal(cropper.canvas.disabled, false)
    assert.notEqual(cropper.destroyed, true)
    assert.deepEqual(setup.revoked, [])
    dialog.click("confirm")
    const retry = SuperImageCropper.instances.at(-1)
    assert.notEqual(retry.options.signal, failed.options.signal)
    assert.equal(retry.options.src, failed.options.src)
    retry.resolve(new Blob(["encoded"], {type: "image/png"}))
    const file = await pending
    assert.equal(file.name, "picture.png")
    assert.equal(file.type, "image/png")
    assert.equal(dialog.removed, true)
  } finally { setup.cleanup() }
})

test("image loading failures leave cancel available and late errors do not reach another dialog", async () => {
  const setup = fixture()
  try {
    const first = setup.editor.edit(new File(["invalid"], "broken.png", {type: "image/png"}), {template: setup.template})
    const failedCropper = Cropper.instances.at(-1)
    const failedDialog = setup.dialogs.at(-1)
    failedCropper.cropperImage.rejectReady(new Error("Failed to load the image source"))
    await settled()
    assert.equal(failedDialog.querySelector("[data-editor-error]").textContent, "The image could not be opened.")
    assert.equal(failedDialog.querySelector("[data-editor-action=confirm]").disabled, true)
    assert.equal(failedDialog.buttons.find(button => button.dataset.editorAction === "cancel").disabled, false)
    const second = setup.editor.edit(new File(["current"], "current.png", {type: "image/png"}), {template: setup.template})
    assert.equal(await first, null)
    const loadingCropper = Cropper.instances.at(-1)
    const current = setup.editor.edit(new File(["latest"], "latest.png", {type: "image/png"}), {template: setup.template})
    assert.equal(await second, null)
    loadingCropper.cropperImage.rejectReady(new Error("Failed to load the image source"))
    await settled()
    assert.notEqual(setup.dialogs.at(-1).querySelector("[data-editor-error]").hidden, false)
    setup.editor.destroy()
    assert.equal(await current, null)
  } finally { setup.cleanup() }
})

test("selection changes stay inside a letterboxed image and image pan or zoom keeps the crop covered", async () => {
  const setup = fixture()
  try {
    const pending = setup.editor.edit(new File(["image"], "portrait.png", {type: "image/png"}), {template: setup.template})
    const cropper = Cropper.instances.at(-1)
    cropper.ready()
    await settled()
    const selection = cropper.selection
    selection.$change(80, 65, 240, 120)
    assert.equal(selection.x, 130)
    selection.$change(130, 65, 350, 120)
    assert.equal(selection.width, 240)
    selection.$change(150, 70, 120, 80)
    assert.deepEqual([selection.x, selection.y, selection.width, selection.height], [150, 70, 120, 80])

    const image = cropper.cropperImage
    image.change({x: 160, y: 50, width: 300, height: 150})
    assert.equal(image.rect.x, 100)
    image.change({x: 100, y: 50, width: 100, height: 60})
    assert.equal(image.rect.width, 300)
    image.change({x: 80, y: 40, width: 400, height: 200})
    assert.deepEqual(image.rect, {x: 80, y: 40, width: 400, height: 200})
    selection.$change(85, 45, 160, 90)
    assert.equal(selection.x, 85)
    setup.editor.destroy()
    assert.equal(await pending, null)
  } finally { setup.cleanup() }
})

test("rotation and reset refit free and constrained selections without blocking the native image actions", async () => {
  const setup = fixture()
  try {
    for (const options of [true, {ratio: 2}, {width: 200, height: 200}]) {
      const pending = setup.editor.edit(new File(["image"], "profile.png", {type: "image/png"}), {...(options === true ? {} : options), template: setup.template})
      const cropper = Cropper.instances.at(-1)
      cropper.ready()
      await settled()
      const dialog = setup.dialogs.at(-1)
      dialog.click("rotate-right")
      assert.equal(cropper.cropperImage.rotation, 90)
      const selection = cropper.selection
      const image = cropper.cropperImage.getBoundingClientRect()
      assert.ok(selection.x >= image.left && selection.x + selection.width <= image.right)
      assert.ok(selection.y >= image.top && selection.y + selection.height <= image.bottom)
      assert.ok(selection.y >= 0 && selection.y + selection.height <= cropper.canvas.rect.height)
      if (options !== true) assert.equal(selection.width / selection.height, options.ratio ?? options.width / options.height)
      dialog.click("reset")
      assert.equal(cropper.cropperImage.rotation, 0)
      assert.equal(cropper.cropperImage.fit, "contain")
      assert.equal(selection.x, 130)
      assert.equal(selection.y, 65)
      if (options !== true) assert.equal(selection.width / selection.height, options.ratio ?? options.width / options.height)
      setup.editor.destroy()
      assert.equal(await pending, null)
    }
  } finally { setup.cleanup() }
})

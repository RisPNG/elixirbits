import test from "node:test"
import assert from "node:assert/strict"
import {readFile} from "node:fs/promises"

const source = (await readFile(new URL("../js/color_input.js", import.meta.url), "utf8"))
  .replace('import("vanilla-colorful/rgba-color-picker.js")', "globalThis.colorInputTestLoad()")
const ColorInput = (await import(`data:text/javascript;base64,${Buffer.from(source).toString("base64")}`)).default

const originalGlobals = Object.fromEntries(["document", "customElements", "colorInputTestLoad"].map(name => [name, globalThis[name]]))
const fields = new Set()
let fieldId = 0

test.afterEach(() => {
  for (const field of fields) if (!field.context.destroyedInput) field.context.destroyed()
  fields.clear()
})
test.after(() => {
  for (const [name, value] of Object.entries(originalGlobals)) {
    if (value === undefined) delete globalThis[name]
    else globalThis[name] = value
  }
})

class Element extends EventTarget {
  constructor() {
    super()
    this.attributes = new Map()
    this.dataset = {}
    this.style = new Map()
    this.style.setProperty = (name, value) => this.style.set(name, value)
    this.style.removeProperty = name => this.style.delete(name)
    this.value = ""
    this.disabled = false
    this.readOnly = false
    this.required = false
    this.customValidity = ""
    this.textContent = ""
    this.hidden = false
    this.parentElement = null
    this.captureListeners = new Map()
    this.popoverOpen = false
    this.submissions = []
  }
  addEventListener(name, callback, options) {
    super.addEventListener(name, callback, options)
    if (options === true || options?.capture) {
      if (!this.captureListeners.has(name)) this.captureListeners.set(name, new Set())
      this.captureListeners.get(name).add(callback)
    }
  }
  removeEventListener(name, callback, options) {
    super.removeEventListener(name, callback, options)
    if (options === true || options?.capture) this.captureListeners.get(name)?.delete(callback)
  }
  get color() { return this.pickerColor }
  set color(value) {
    this.pickerColor = {...value}
    if (this.emitOnSet) this.dispatchEvent(new CustomEvent("color-changed", {bubbles: true, detail: {value}}))
  }
  matches(selector) { return selector === ":popover-open" && this.popoverOpen }
  showPopover(options) {
    const before = Object.assign(new Event("beforetoggle", {cancelable: true}), {newState: "open"})
    this.dispatchEvent(before)
    if (!before.defaultPrevented) {
      this.popoverOpen = true
      this.popoverSource = options?.source
      this.dispatchEvent(Object.assign(new Event("toggle"), {newState: "open"}))
    }
  }
  hidePopover() {
    this.popoverOpen = false
    this.dispatchEvent(Object.assign(new Event("toggle"), {newState: "closed"}))
  }
  setAttribute(name, value) { this.attributes.set(name, String(value)) }
  getAttribute(name) { return this.attributes.get(name) ?? null }
  hasAttribute(name) { return this.attributes.has(name) }
  setCustomValidity(message) { this.customValidity = message }
  get validity() { return {valid: !this.customValidity && (!this.required || !!this.value)} }
  contains(node) {
    for (let element = node; element; element = element.parentElement) if (element === this) return true
    return false
  }
  focus() { this.focused = true }
  requestSubmit(submitter) {
    const event = Object.assign(new Event("submit", {bubbles: true, cancelable: true}), {submitter})
    this.dispatchEvent(event)
    if (!event.defaultPrevented) this.submissions.push(submitter)
  }
  dispatchEvent(event) {
    if (!event.target) {
      Object.defineProperty(event, "target", {value: this, configurable: true})
      const ancestors = []
      for (let element = this.parentElement; element; element = element.parentElement) ancestors.unshift(element)
      for (const ancestor of ancestors) {
        for (const callback of ancestor.captureListeners.get(event.type) || []) callback.call(ancestor, event)
        if (event.cancelBubble) return !event.defaultPrevented
      }
    }
    const result = super.dispatchEvent(event)
    if (event.bubbles && !event.cancelBubble) this.parentElement?.dispatchEvent(event)
    return result
  }
}

globalThis.document = new Element()
globalThis.customElements = {get: () => Element}

function nativeColor(value = "#c9822b", format = "hex", extra = {}) {
  return {valid: true, value, format, label: format === "oklab" ? "OKLab" : format === "lab" ? "Lab" : format.toUpperCase(), swatch: value ? "rgb(201 130 43)" : null, rgba: value ? {r: 201, g: 130, b: 43, a: 1} : null, ...extra}
}

function openInput(state = nativeColor(), options = {}) {
  const wrapper = new Element()
  const form = options.form || new Element()
  wrapper.id = `test_color_${++fieldId}`
  wrapper.dataset.colorEditable = String(options.editable !== false)
  wrapper.dataset.colorSpaceName = `test[color_${fieldId}_color_space]`
  wrapper.dataset.colorSpaceId = `${wrapper.id}_color_space_select`
  wrapper.dataset.colorState = JSON.stringify(state)
  wrapper.parentElement = form
  const controls = Object.fromEntries(["input", "picker", "trigger", "popover", "swatch", "format", "error", "spaceInput", "spaceText", "spaceSelect", "option"].map(name => [name, new Element()]))
  const selectors = {
    "[data-color-value]": "input",
    "[data-color-picker]": "picker",
    "[data-color-trigger]": "trigger",
    "[data-color-popover]": "popover",
    "[data-color-swatch]": "swatch",
    "[data-color-format]": "format",
    "[data-color-error]": "error",
    [`select[name='${wrapper.dataset.colorSpaceName}']`]: "spaceInput",
    "[data-color-space-select]": "spaceSelect",
  }
  controls.input.value = state.value
  controls.input.textContent = state.value
  controls.picker.emitOnSet = options.emitOnSet
  controls.input.form = form
  Object.assign(controls.input, options)
  controls.spaceInput.name = wrapper.dataset.colorSpaceName
  controls.spaceInput.value = state.format
  controls.spaceText.value = state.format.toUpperCase()
  for (const control of Object.values(controls)) control.parentElement = wrapper
  controls.picker.parentElement = controls.popover
  controls.spaceText.parentElement = controls.spaceSelect
  controls.option.parentElement = controls.spaceSelect
  controls.spaceSelect.querySelector = selector => selector === "input[type=text]" ? controls.spaceText : null
  wrapper.querySelector = selector => {
    const control = selectors[selector]
    if ((wrapper.dataset.colorEditable === "false" && ["picker", "trigger", "popover", "spaceInput", "spaceSelect"].includes(control)) || (wrapper.dataset.colorEditable !== "false" && control === "format")) return null
    return controls[control]
  }
  const requests = []
  const context = {...ColorInput, el: wrapper, pushEvent: (event, payload, callback) => {
    const promise = new Promise((resolve, reject) => requests.push({event, payload, resolve, reject}))
    if (callback) promise.then(callback, () => {})
    else return promise
  }}
  const notifications = []
  wrapper.addEventListener("input", event => notifications.push({type: event.type, value: event.target.value, color: controls.input.value, format: controls.spaceInput.value}))
  controls.input.addEventListener("blur", event => notifications.push({type: event.type, value: event.target.value}))
  context.mounted()
  const field = {
    wrapper, form, controls, context, notifications, requests,
    reply(index, value) { requests[index].resolve(value); return finishReplies() },
    reject(index, error) { requests[index].reject(error); return finishReplies() },
    echoSpace(value) {
      controls.spaceInput.value = value
      controls.spaceText.value = value.toUpperCase()
    },
    selectSpace(value) {
      this.echoSpace(value)
      controls.spaceInput.dispatchEvent(new Event("input", {bubbles: true}))
      controls.spaceInput.dispatchEvent(new Event("change", {bubbles: true}))
    },
    type(value) {
      controls.input.value = value
      controls.input.dispatchEvent(new Event("input", {bubbles: true}))
    },
    blur() { controls.input.dispatchEvent(new Event("blur")) },
    pick(value, part) {
      if (part) {
        const slider = new Element()
        slider.setAttribute("part", part)
        const interaction = new Event("mousedown", {bubbles: true})
        Object.defineProperty(interaction, "composedPath", {value: () => [slider, controls.picker, wrapper]})
        controls.picker.dispatchEvent(interaction)
      }
      controls.picker.dispatchEvent(new CustomEvent("color-changed", {bubbles: true, detail: {value}}))
    },
    open() { controls.popover.showPopover() },
    submit(submitter) {
      const event = Object.assign(new Event("submit", {bubbles: true, cancelable: true}), {submitter})
      form.dispatchEvent(event)
      if (!event.defaultPrevented) form.submissions.push(submitter)
      return event
    },
  }
  fields.add(field)
  return field
}

async function finishReplies() {
  await new Promise(resolve => setImmediate(resolve))
}

test("native rendered metadata opens unchanged without browser parsing or server requests", () => {
  const state = nativeColor("  OKLCH(65% .14 65 / .375)  ", "oklch", {swatch: "rgb(201 130 43 / .375)", rgba: {r: 201, g: 130, b: 43, a: .375}})
  const field = openInput(state, {emitOnSet: true})
  assert.equal(field.controls.input.value, state.value)
  assert.deepEqual(field.controls.picker.color, state.rgba)
  assert.equal(field.controls.swatch.style.get("--input-color"), state.swatch)
  assert.equal(field.requests.length, 0)
  assert.equal(field.notifications.length, 0)
  field.context.updated()
  assert.equal(field.requests.length, 0)
})

test("picker loading preserves drafts and updates the upgraded picker from the latest native reply", async () => {
  const originalRegistry = globalThis.customElements
  let registered = false
  let resolveLibrary
  let loads = 0
  globalThis.customElements = {get: () => registered ? Element : undefined}
  globalThis.colorInputTestLoad = () => {
    loads++
    return new Promise(resolve => { resolveLibrary = resolve })
  }

  try {
    const field = openInput()
    assert.equal(loads, 1)
    assert.deepEqual(field.controls.picker.color, nativeColor().rgba)
    field.type("rgb(12 34 56 / .25)")
    field.context.updated()
    assert.equal(loads, 1)
    field.blur()
    const state = nativeColor("rgb(12 34 56 / .25)", "rgb", {rgba: {r: 12, g: 34, b: 56, a: .25}})
    await field.reply(0, state)
    assert.deepEqual(field.controls.picker.color, state.rgba)
    registered = true
    resolveLibrary()
    await field.context.pickerLoading
    assert.deepEqual(field.controls.picker.color, state.rgba)
    assert.equal(field.controls.input.value, state.value)
    assert.equal(field.requests.length, 1)

    registered = false
    const removed = openInput()
    removed.context.destroyed()
    let removedSynchronizations = 0
    removed.context.synchronize = () => { removedSynchronizations++ }
    registered = true
    resolveLibrary()
    await removed.context.pickerLoading
    assert.equal(removedSynchronizations, 0)
    assert.equal(removed.context.destroyedInput, true)
  } finally {
    globalThis.customElements = originalRegistry
    delete globalThis.colorInputTestLoad
  }
})

test("manual drafts validate on capture blur and use the native detected format without rewriting raw text", async () => {
  const field = openInput()
  const value = "  OKLCH(65% .14 65 / .5)  "
  field.type(value)
  assert.equal(field.requests.length, 0)
  field.blur()
  assert.deepEqual(field.requests[0].payload, {id: field.wrapper.id, selector_id: field.wrapper.dataset.colorSpaceId, value, format: "hex", operation: "validate"})
  field.echoSpace("oklch")
  assert.equal(field.requests.length, 1)
  await field.reply(0, nativeColor(value, "oklch"))
  assert.equal(field.controls.input.value, value)
  assert.equal(field.controls.spaceInput.value, "oklch")
  assert.equal(field.controls.spaceText.value, "OKLCH")
  assert.equal(field.controls.input.validity.valid, true)
  assert.equal(field.requests.length, 1)
  assert.deepEqual(field.notifications.slice(-2).map(event => event.type), ["input", "blur"])
})

test("server conversion updates both named fields before dispatching input and blur", async () => {
  const field = openInput()
  field.selectSpace("hsl")
  assert.equal(field.controls.input.value, "#c9822b")
  assert.equal(field.notifications.length, 0)
  assert.equal(field.requests[0].payload.operation, "convert")
  assert.equal(field.requests[0].payload.format, "hsl")
  field.echoSpace("hsl")
  assert.equal(field.requests.length, 1)
  await field.reply(0, nativeColor("hsl(33 65% 48%)", "hsl"))
  assert.deepEqual(field.notifications.map(event => event.type), ["input", "blur"])
  assert.equal(field.notifications[0].color, "hsl(33 65% 48%)")
  assert.equal(field.notifications[0].format, "hsl")
  field.selectSpace("lab")
  assert.equal(field.requests[1].payload.format, "lab")
})

test("a real selection during pending blur validation converts the raw pasted value", async () => {
  const field = openInput()
  field.type("oklch(.65 .14 65)")
  field.blur()
  field.selectSpace("rgb")
  assert.equal(field.requests.length, 2)
  assert.equal(field.requests[1].payload.value, "oklch(.65 .14 65)")
  assert.equal(field.requests[1].payload.format, "rgb")
  await field.reply(0, nativeColor("oklch(.65 .14 65)", "oklch"))
  assert.equal(field.controls.input.value, "oklch(.65 .14 65)")
  await field.reply(1, nativeColor("rgb(201 130 43)", "rgb"))
  assert.equal(field.controls.input.value, "rgb(201 130 43)")
})

test("stale replies and parent selector echoes preserve newer unblurred drafts", async () => {
  const field = openInput()
  field.selectSpace("hsl")
  field.type("lab(60 10 30)")
  field.controls.input.value = "#c9822b"
  field.context.updated()
  assert.equal(field.controls.input.value, "lab(60 10 30)")
  field.echoSpace("hsl")
  await field.reply(0, nativeColor("hsl(33 65% 48%)", "hsl"))
  assert.equal(field.controls.input.value, "lab(60 10 30)")
  assert.equal(field.requests.length, 1)
  field.blur()
  await field.reply(1, nativeColor("lab(60 10 30)", "lab"))
  field.echoSpace("hsl")
  assert.equal(field.requests.length, 2)
  assert.equal(field.controls.input.value, "lab(60 10 30)")
  assert.equal(field.context.format, "lab")
})

test("latest conversion wins when replies arrive out of order", async () => {
  const field = openInput()
  field.selectSpace("hsl")
  field.selectSpace("oklch")
  await field.reply(1, nativeColor("oklch(.65 .14 65)", "oklch"))
  await field.reply(0, nativeColor("hsl(33 65% 48%)", "hsl"))
  assert.equal(field.controls.input.value, "oklch(.65 .14 65)")
  assert.equal(field.controls.spaceInput.value, "oklch")
  assert.equal(field.notifications.length, 2)
})

test("matching parent patches retain authoritative reply metadata and precise source", async () => {
  const field = openInput()
  const state = nativeColor("rgb(201 130 43 / .375)", "rgb", {rgba: {r: 201, g: 130, b: 43, a: .375}})
  field.selectSpace("rgb")
  await field.reply(0, state)
  field.context.updated()
  assert.deepEqual(field.context.state, state)
  assert.equal(field.controls.input.value, state.value)
  assert.equal(field.controls.spaceInput.value, "rgb")
})

test("replaced input nodes invalidate old replies and require fresh validation", async () => {
  const field = openInput()
  field.type("lab(60 10 30)")
  field.blur()
  const replacement = new Element()
  replacement.value = field.controls.input.value
  field.context.input = replacement
  await field.reply(0, nativeColor("lab(60 10 30)", "lab"))
  assert.equal(field.context.pending, null)
  assert.equal(field.context.draft, true)
  assert.equal(replacement.value, "lab(60 10 30)")
  assert.equal(field.notifications.length, 2)
})

test("invalid native replies show validation and typing clears errors until the next blur", async () => {
  const field = openInput()
  field.type("unsupported color")
  field.blur()
  await field.reply(0, {valid: false, error: "Enter a supported color value."})
  assert.equal(field.controls.input.validity.valid, false)
  assert.equal(field.controls.error.hidden, false)
  assert.equal(field.controls.input.getAttribute("aria-invalid"), "true")
  assert.equal(field.controls.swatch.style.get("--input-color"), undefined)
  assert.equal(field.submit().defaultPrevented, true)
  assert.equal(field.controls.input.focused, true)
  field.type("rgb(201 130 43)")
  assert.equal(field.controls.error.hidden, true)
  assert.equal(field.controls.input.validity.valid, true)
  assert.equal(field.requests.length, 1)
})

test("novalidate submission waits for the latest draft and preserves its submitter", async () => {
  const field = openInput()
  const submitter = new Element()
  submitter.form = field.form
  field.type("rgba(201, 130, 43, .5)")
  const event = field.submit(submitter)
  assert.equal(event.defaultPrevented, true)
  assert.equal(field.form.submissions.length, 0)
  assert.equal(field.requests[0].payload.operation, "validate")
  await field.reply(0, nativeColor("rgba(201, 130, 43, .5)", "rgb"))
  await finishReplies()
  assert.deepEqual(field.form.submissions, [submitter])
  assert.equal(field.controls.spaceInput.value, "rgb")
})

test("submission waits for conversion and never submits invalid native results", async () => {
  const field = openInput()
  field.selectSpace("lab")
  field.submit()
  assert.equal(field.requests.length, 1)
  await field.reply(0, nativeColor("lab(60 10 30)", "lab"))
  await finishReplies()
  assert.equal(field.form.submissions.length, 1)
  field.type("bad value")
  field.submit()
  await field.reply(1, {valid: false, error: "Enter a supported color value."})
  await finishReplies()
  assert.equal(field.form.submissions.length, 1)
  assert.equal(field.controls.input.focused, true)
})

test("multiple colour hooks coordinate one submission and wait for every native validation", async () => {
  const first = openInput()
  const second = openInput(nativeColor("hsl(33 65% 48%)", "hsl"), {form: first.form})
  first.type("rgb(1 2 3)")
  second.type("oklch(.5 .1 20)")
  first.submit()
  second.submit()
  assert.equal(first.requests.length, 1)
  assert.equal(second.requests.length, 1)
  await first.reply(0, nativeColor("rgb(1 2 3)", "rgb"))
  await finishReplies()
  assert.equal(first.form.submissions.length, 0)
  await second.reply(0, nativeColor("oklch(.5 .1 20)", "oklch"))
  await finishReplies()
  assert.equal(first.form.submissions.length, 1)
})

test("a new draft while submission awaits a reply is validated before submission resumes", async () => {
  const field = openInput()
  field.type("rgb(1 2 3)")
  field.submit()
  field.type("lab(60 10 30)")
  await field.reply(0, nativeColor("rgb(1 2 3)", "rgb"))
  await finishReplies()
  assert.equal(field.requests.length, 2)
  assert.equal(field.requests[1].payload.value, "lab(60 10 30)")
  assert.equal(field.form.submissions.length, 0)
  await field.reply(1, nativeColor("lab(60 10 30)", "lab"))
  await finishReplies()
  assert.equal(field.form.submissions.length, 1)
})

test("failed validation settles and stops submission until an intentional retry succeeds", async () => {
  const field = openInput()
  const submitter = new Element()
  submitter.form = field.form
  const value = "  OKLCH(65% .14 65 / .5)  "
  field.type(value)
  field.submit(submitter)
  const pending = field.context.pending.promise
  await field.reject(0, new Error("Failed to push hook event"))
  assert.deepEqual(await pending, {failed: true})
  assert.equal(field.context.pending, null)
  assert.equal(field.context.draft, true)
  assert.equal(field.controls.input.value, value)
  assert.equal(field.controls.error.textContent, "The color could not be checked. Try again.")
  assert.equal(field.controls.error.hidden, false)
  assert.equal(field.requests.length, 1)
  assert.equal(field.form.submissions.length, 0)

  field.context.updated()
  assert.equal(field.controls.input.value, value)
  assert.equal(field.submit(submitter).defaultPrevented, true)
  assert.equal(field.requests.length, 2)
  assert.equal(field.requests[1].payload.value, value)
  await field.reply(1, nativeColor(value, "oklch"))
  assert.equal(field.context.pending, null)
  assert.equal(field.context.draft, false)
  assert.equal(field.controls.error.hidden, true)
  assert.equal(field.controls.input.validity.valid, true)
  assert.deepEqual(field.form.submissions, [submitter])
})

test("a disconnected picker request releases its opening state and can be retried after reconnecting", async () => {
  const field = openInput()
  const pushEvent = field.context.pushEvent
  field.context.pushEvent = () => Promise.reject(new Error("unable to push hook event. LiveView not connected"))
  const value = "lab(60 10 30)"
  field.type(value)
  field.open()
  const pending = field.context.pending.promise
  await finishReplies()
  assert.deepEqual(await pending, {failed: true})
  assert.equal(field.context.pending, null)
  assert.equal(field.context.opening, false)
  assert.equal(field.controls.popover.popoverOpen, false)
  assert.equal(field.controls.input.value, value)
  assert.equal(field.controls.input.focused, true)

  field.context.pushEvent = pushEvent
  field.open()
  assert.equal(field.requests[0].payload.value, value)
  await field.reply(0, nativeColor(value, "lab"))
  assert.equal(field.controls.popover.popoverOpen, true)
  assert.equal(field.controls.input.validity.valid, true)
  assert.equal(field.controls.error.hidden, true)
})

test("a superseded request failure leaves the latest draft and submission intact", async () => {
  const field = openInput()
  field.type("rgb(1 2 3)")
  field.submit()
  const superseded = field.context.pending.promise
  field.type("lab(60 10 30)")
  field.blur()
  const latest = field.context.pending
  await field.reject(0, new Error("Failed to push hook event"))
  assert.equal(await superseded, null)
  assert.equal(field.context.pending, latest)
  assert.equal(field.controls.input.value, "lab(60 10 30)")
  assert.equal(field.controls.error.hidden, true)
  assert.equal(field.requests.length, 2)
  assert.equal(field.form.submissions.length, 0)

  await field.reply(1, nativeColor("lab(60 10 30)", "lab"))
  assert.equal(field.controls.input.value, "lab(60 10 30)")
  assert.equal(field.form.submissions.length, 1)
})

test("blank fields keep the selected native format and required validation still blocks submission", async () => {
  const field = openInput(nativeColor("", "hex"))
  field.selectSpace("cmyk")
  await field.reply(0, nativeColor("", "cmyk"))
  field.context.updated()
  assert.equal(field.context.format, "cmyk")
  assert.equal(field.controls.spaceInput.value, "cmyk")
  assert.equal(field.controls.input.value, "")
  assert.equal(field.controls.swatch.style.get("--input-color"), undefined)
  const required = openInput(nativeColor("", "hex"), {required: true})
  assert.equal(required.submit().defaultPrevented, true)
  assert.equal(required.controls.error.textContent, "Enter a color.")
})

test("picker opening awaits native validation and lets a valid pick recover an invalid draft", async () => {
  const field = openInput()
  field.type("oklch(.65 .14 65)")
  field.open()
  assert.equal(field.controls.popover.popoverOpen, false)
  await field.reply(0, nativeColor("oklch(.65 .14 65)", "oklch"))
  await finishReplies()
  assert.equal(field.controls.popover.popoverOpen, true)
  assert.equal(field.controls.popover.popoverSource, field.controls.trigger)
  field.controls.popover.hidePopover()
  field.type("bad")
  field.open()
  await field.reply(1, {valid: false, error: "Enter a supported color value."})
  await finishReplies()
  assert.equal(field.controls.popover.popoverOpen, true)
  assert.equal(field.controls.input.value, "bad")
  assert.equal(field.controls.input.validity.valid, false)
  field.pick({r: 180, g: 30, b: 90, a: 1}, "hue")
  await field.reply(2, nativeColor("oklch(.7 .1 20)", "oklch"))
  assert.equal(field.controls.input.value, "oklch(.7 .1 20)")
  assert.equal(field.controls.input.validity.valid, true)
  assert.equal(field.controls.error.hidden, true)
})

test("picker drag previews immediately and ignores responses from earlier drag positions", async () => {
  const field = openInput()
  field.open()
  const first = {r: 240, g: 50, b: 20, a: 1}
  const last = {r: 180, g: 30, b: 90, a: 1}
  field.pick(first, "hue")
  assert.equal(field.controls.swatch.style.get("--input-color"), "rgb(240 50 20 / 1)")
  assert.equal(field.controls.input.value, "#c9822b")
  field.pick(last, "saturation")
  await field.reply(0, nativeColor("#f03214", "hex", {rgba: first}))
  assert.deepEqual(field.controls.picker.color, last)
  await field.reply(1, nativeColor("#b41e5a", "hex", {rgba: last}))
  assert.equal(field.controls.input.value, "#b41e5a")
  assert.deepEqual(field.controls.picker.color, last)
  assert.deepEqual(field.notifications.map(event => event.type), ["input", "blur"])
})

test("hue edits preserve precise alpha while explicit or changed alpha requests replace it", async () => {
  const field = openInput(nativeColor("rgb(201 130 43 / .375)", "rgb", {rgba: {r: 201, g: 130, b: 43, a: .375}}))
  field.pick({r: 180, g: 30, b: 90, a: .38}, "hue")
  assert.equal(field.requests[0].payload.alpha_changed, false)
  await field.reply(0, nativeColor("rgb(180 30 90 / .375)", "rgb", {rgba: {r: 180, g: 30, b: 90, a: .375}}))
  field.pick({r: 180, g: 30, b: 90, a: .38}, "alpha")
  assert.equal(field.requests[1].payload.alpha_changed, true)
  await field.reply(1, nativeColor("rgb(180 30 90 / .38)", "rgb", {rgba: {r: 180, g: 30, b: 90, a: .38}}))
  field.context.editingAlpha = false
  field.pick({r: 180, g: 30, b: 90, a: .5})
  assert.equal(field.requests[2].payload.alpha_changed, true)
})

test("disabled, read-only and text-only displays neither request conversion nor open the picker", () => {
  for (const options of [{disabled: true}, {readOnly: true}]) {
    const field = openInput(nativeColor(), options)
    field.selectSpace("hsl")
    field.pick({r: 0, g: 0, b: 0, a: 1})
    field.open()
    assert.equal(field.requests.length, 0)
    assert.equal(field.controls.popover.popoverOpen, false)
    assert.equal(field.controls.trigger.disabled, true)
    assert.equal(field.controls.spaceText.disabled, true)
    assert.equal(field.controls.spaceInput.disabled, true)
  }
  const display = openInput(nativeColor("cmyk(.1 .2 .3 .4)", "cmyk"), {editable: false})
  assert.equal(display.controls.format.textContent, "CMYK")
  assert.equal(display.requests.length, 0)
})

test("closing the native popover clears alpha interaction and destruction dismisses it", () => {
  const field = openInput()
  field.open()
  field.context.editingAlpha = true
  field.controls.popover.hidePopover()
  assert.equal(field.context.editingAlpha, false)
  field.open()
  field.context.destroyed()
  assert.equal(field.controls.popover.popoverOpen, false)
})

test("form rebinding and destruction release shared submission handling and ignore pending replies", async () => {
  const field = openInput()
  const oldForm = field.form
  const newForm = new Element()
  field.controls.input.form = newForm
  field.context.updated()
  assert.equal(oldForm.captureListeners.get("submit").size, 0)
  assert.equal(newForm.captureListeners.get("submit").size, 1)
  field.type("lab(60 10 30)")
  field.blur()
  field.context.destroyed()
  await field.reply(0, nativeColor("lab(60 10 30)", "lab"))
  assert.equal(newForm.captureListeners.get("submit").size, 0)
  assert.equal(field.controls.input.value, "lab(60 10 30)")
  assert.equal(field.controls.spaceInput.value, "hex")
})


test("switching to display mode replaces drafts with native rendered state and invalidates pending replies", async () => {
  const field = openInput()
  field.type("lab(60 10 30)")
  field.blur()
  const incoming = nativeColor("device-cmyk(.1 .2 .3 .4)", "cmyk")
  field.wrapper.dataset.colorEditable = "false"
  field.wrapper.dataset.colorState = JSON.stringify(incoming)
  field.controls.input.textContent = incoming.value
  field.context.updated()
  assert.equal(field.context.pending, null)
  assert.equal(field.context.draft, false)
  assert.equal(field.context.value, incoming.value)
  assert.equal(field.controls.format.textContent, "CMYK")
  await field.reply(0, nativeColor("lab(60 10 30)", "lab"))
  assert.equal(field.context.value, incoming.value)
  assert.equal(field.controls.format.textContent, "CMYK")
  assert.equal(field.form.captureListeners.get("submit").size, 0)
})

test("destruction releases cached native source only while the LiveSocket is connected", () => {
  const field = openInput()
  field.context.liveSocket = {isConnected: () => true}
  field.context.destroyed()
  assert.deepEqual(field.requests[0].payload, {id: field.wrapper.id, selector_id: field.wrapper.dataset.colorSpaceId, operation: "release"})
  const disconnected = openInput()
  disconnected.context.liveSocket = {isConnected: () => false}
  disconnected.context.destroyed()
  assert.equal(disconnected.requests.length, 0)
})


test("submission follows a newer conversion without waiting for a superseded response", async () => {
  const field = openInput()
  field.selectSpace("hsl")
  field.submit()
  field.selectSpace("lab")
  await field.reply(1, nativeColor("lab(60 10 30)", "lab"))
  await finishReplies()
  assert.equal(field.form.submissions.length, 1)
  assert.equal(field.controls.input.value, "lab(60 10 30)")
  await field.reply(0, nativeColor("hsl(33 65% 48%)", "hsl"))
  assert.equal(field.form.submissions.length, 1)
  assert.equal(field.controls.input.value, "lab(60 10 30)")
})

test("removing one pending colour field does not block the remaining form fields", async () => {
  const first = openInput()
  const second = openInput(nativeColor(), {form: first.form})
  first.type("rgb(1 2 3)")
  second.type("lab(60 10 30)")
  first.submit()
  first.context.destroyed()
  await second.reply(0, nativeColor("lab(60 10 30)", "lab"))
  await finishReplies()
  assert.equal(first.form.submissions.length, 1)
  await first.reply(0, nativeColor("rgb(1 2 3)", "rgb"))
  assert.equal(first.form.submissions.length, 1)
})

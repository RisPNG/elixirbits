import test from "node:test"
import assert from "node:assert/strict"
import {readFile} from "node:fs/promises"

const source = await readFile(new URL("../js/input_controls.js", import.meta.url), "utf8")
const {default: initInputControls} = await import(`data:text/javascript;base64,${Buffer.from(source).toString("base64")}`)

class Element {
  constructor(tagName = "div", parent = null) {
    this.tagName = tagName.toUpperCase()
    this.parentElement = parent
    this.children = []
    this.dataset = {}
    this.listeners = []
    this.nodeType = 1
    this.value = ""
    this.type = "text"
    this.hidden = false
    this.className = ""
    parent?.children.push(this)
  }
  matches(selector) {
    if (selector.includes(",")) return selector.split(",").some(value => this.matches(value.trim()))
    if (selector === ":disabled") {
      if (this.disabled) return true
      for (let ancestor = this.parentElement; ancestor; ancestor = ancestor.parentElement) {
        if (ancestor.tagName !== "FIELDSET" || !ancestor.disabled) continue
        const legend = ancestor.children.find(child => child.tagName === "LEGEND")
        if (!legend?.contains(this)) return true
      }
      return false
    }
    if (selector.includes(" > ")) {
      const [parent, child] = selector.split(" > ")
      return this.matches(child) && !!this.parentElement?.matches(parent)
    }
    if (selector.includes(" ")) {
      const separator = selector.lastIndexOf(" ")
      return this.matches(selector.slice(separator + 1)) && !!this.parentElement?.closest(selector.slice(0, separator))
    }
    const tag = selector.match(/^[a-z]+/i)?.[0]
    if (tag && this.tagName !== tag.toUpperCase()) return false
    for (const [, key, value] of selector.matchAll(/\[([^=\]]+)(?:=([^\]]+))?\]/g)) {
      const actual = key.startsWith("data-") ? this.dataset[key.slice(5).replace(/-([a-z])/g, (_, letter) => letter.toUpperCase())] : this[key]
      if (actual === undefined || value !== undefined && String(actual) !== value) return false
    }
    return [...selector.matchAll(/\.([\w-]+)/g)].every(([, value]) => this.className.split(/\s+/).includes(value))
  }
  closest(selector) {
    for (let element = this; element; element = element.parentElement) if (element.matches(selector)) return element
    return null
  }
  querySelectorAll(selector) {
    return this.children.flatMap(child => [child, ...child.querySelectorAll("*")]).filter(child => child.matches(selector))
  }
  querySelector(selector) { return this.querySelectorAll(selector)[0] || null }
  contains(node) {
    for (let element = node; element; element = element.parentElement) if (element === this) return true
    return false
  }
  reset() {
    const event = new Event("reset", {bubbles: true, cancelable: true})
    if (!this.dispatchEvent(event)) return
    for (const input of this.elements.filter(input => input.matches("input, select, textarea"))) {
      if (["radio", "checkbox"].includes(input.type)) input.checked = !!input.defaultChecked
      else if (input.tagName === "SELECT") for (const option of input.options) option.selected = !!option.defaultSelected
      else input.value = input.defaultValue ?? ""
    }
  }
  addEventListener(type, callback, capture = false) { this.listeners.push({type, callback, capture}) }
  removeEventListener(type, callback, capture = false) { this.listeners = this.listeners.filter(listener => listener.type !== type || listener.callback !== callback || listener.capture !== capture) }
  dispatchEvent(event) {
    if (!event.target) Object.defineProperty(event, "target", {value: this})
    const path = []
    for (let element = this; element; element = element.parentElement) path.push(element)
    for (const element of path.toReversed()) for (const listener of element.listeners) if (listener.capture && listener.type === event.type) listener.callback(event)
    for (const element of event.bubbles ? path : [this]) for (const listener of element.listeners) if (!listener.capture && listener.type === event.type) listener.callback(event)
    return !event.defaultPrevented
  }
  focus() { document.activeElement = this }
  get elements() {
    let root = this
    while (root.parentElement) root = root.parentElement
    return root.querySelectorAll("input, select, textarea, button, fieldset")
      .filter(input => input.form === this || !input.form && input.closest("form") === this)
  }
  get selectedOptions() { return this.options.filter(option => option.selected) }
}

function fixture(type = "text", value = "Entered value", clearable = true, configure = () => {}) {
  const saved = {document: globalThis.document, MutationObserver: globalThis.MutationObserver}
  const doc = new Element("document")
  doc.documentElement = doc
  const form = new Element("form", doc)
  const fieldset = new Element("fieldset", form)
  const field = new Element("div", fieldset)
  Object.assign(field.dataset, {coreInput: "", inputType: type, inputClearable: String(clearable)})
  const input = new Element(type === "select" ? "select" : type === "textarea" ? "textarea" : "input", field)
  input.type = type
  input.dataset.inputValue = ""
  input.value = value
  input.defaultValue = value
  const button = new Element("button", field)
  button.dataset.inputClear = ""
  const events = []
  for (const name of ["input", "change", "blur"]) input.addEventListener(name, () => events.push([name, input.value]))
  globalThis.document = doc
  globalThis.MutationObserver = class {
    constructor(callback) { this.callback = callback; fixture.observer = this }
    observe() { this.observing = true }
    disconnect() { this.observing = false }
  }
  if (type === "select") input.options = [{value: "", selected: false}, {value, selected: true}]
  configure({form, fieldset, field, input, button})
  const controls = initInputControls()
  return {doc, form, fieldset, field, input, button, events, controls,
    click() { return button.dispatchEvent(new Event("click", {bubbles: true, cancelable: true})) },
    cleanup() { controls.destroyed(); globalThis.document = saved.document; globalThis.MutationObserver = saved.MutationObserver },
  }
}

test("native text clearing submits the empty value and flushes blur debounce without needing an ID", () => {
  const setup = fixture()
  try {
    assert.equal(setup.button.hidden, false)
    setup.click()
    assert.equal(setup.input.value, "")
    assert.deepEqual(setup.events, [["input", ""], ["change", ""], ["blur", ""]])
    assert.equal(document.activeElement, setup.input)
    assert.equal(setup.button.hidden, true)
  } finally { setup.cleanup() }
})

test("empty, disabled, and explicitly nonclearable fields do not expose active clear actions", () => {
  for (const [value, clearable, disabled] of [["", true, false], ["Saved", false, false], ["Saved", true, true]]) {
    const setup = fixture("text", value, clearable)
    try {
      setup.input.disabled = disabled
      setup.controls.refresh(setup.field)
      assert.equal(setup.button.hidden, true)
      if (value) setup.click()
      assert.equal(setup.input.value, value)
      assert.deepEqual(setup.events, [])
    } finally { setup.cleanup() }
  }
})

test("ordinary editing and server patches refresh clear availability", () => {
  const setup = fixture("textarea", "")
  try {
    assert.equal(setup.button.hidden, true)
    setup.input.value = "A note"
    setup.input.dispatchEvent(new Event("input", {bubbles: true}))
    assert.equal(setup.field.dataset.inputHasValue, "true")
    assert.equal(setup.button.hidden, false)
    setup.input.value = ""
    fixture.observer.callback([{target: setup.input, addedNodes: []}])
    assert.equal(setup.field.dataset.inputHasValue, "false")
    assert.equal(setup.button.hidden, true)
  } finally { setup.cleanup() }
})

test("joining or patching a live form restores derived clear state from the retained native value", () => {
  const setup = fixture("text", "A retained value")
  try {
    assert.equal(setup.field.dataset.inputHasValue, "true")
    delete setup.field.dataset.inputHasValue
    fixture.observer.callback([{type: "attributes", target: setup.field, addedNodes: []}])
    assert.equal(setup.field.dataset.inputHasValue, "true")
    assert.equal(setup.button.hidden, false)
    setup.controls.refresh(setup.field)
    assert.equal(setup.field.dataset.inputHasValue, "true")
  } finally { setup.cleanup() }
})

test("single and multiple selects clear their real native choices before notifying the form", () => {
  for (const multiple of [false, true]) {
    const setup = fixture("select", "chosen")
    try {
      setup.input.multiple = multiple
      setup.click()
      assert.deepEqual(setup.input.selectedOptions.map(option => option.value), multiple ? [] : [""])
      assert.deepEqual(setup.events.map(([name]) => name), ["input", "change", "blur"])
    } finally { setup.cleanup() }
  }
})

test("specialized owners handle their clear event before generic native mutation", () => {
  const setup = fixture("color", "#123456")
  try {
    let clearEvents = 0
    setup.field.addEventListener("input:clear", event => {
      event.preventDefault()
      clearEvents++
      setup.input.value = "owned value"
    })
    setup.button.focus()
    setup.click()
    assert.equal(clearEvents, 1)
    assert.equal(setup.input.value, "owned value")
    assert.deepEqual(setup.events, [])
    assert.equal(document.activeElement, setup.input)
  } finally { setup.cleanup() }
})

test("native form reset refreshes availability after the browser restores default values", async () => {
  for (const [value, defaultValue] of [["Edited", ""], ["", "Saved default"]]) {
    const setup = fixture("text", value)
    try {
      setup.input.defaultValue = defaultValue
      assert.equal(setup.button.hidden, value === "")
      setup.form.reset()
      assert.equal(setup.input.value, defaultValue)
      assert.equal(setup.button.hidden, value === "")
      await Promise.resolve()
      assert.equal(setup.button.hidden, value === "")
      await new Promise(resolve => setTimeout(resolve, 0))
      assert.equal(setup.button.hidden, defaultValue === "")
      assert.equal(setup.field.dataset.inputHasValue, String(defaultValue !== ""))
      assert.deepEqual(setup.events, [])
    } finally { setup.cleanup() }
  }
})

test("form reset refreshes associated inputs outside the form's DOM subtree", async () => {
  const setup = fixture("text", "Edited")
  try {
    setup.fieldset.children = []
    setup.field.parentElement = setup.doc
    setup.doc.children.push(setup.field)
    setup.input.form = setup.form
    setup.input.defaultValue = ""
    assert.equal(setup.form.contains(setup.input), false)
    assert.ok(setup.form.elements.includes(setup.input))
    setup.form.reset()
    await new Promise(resolve => setTimeout(resolve, 0))
    assert.equal(setup.input.value, "")
    assert.equal(setup.button.hidden, true)
    assert.equal(setup.field.dataset.inputHasValue, "false")
  } finally { setup.cleanup() }
})

test("disabled fieldset patches refresh every enclosed field's clear availability", () => {
  let second
  const setup = fixture("text", "Entered value", true, ({fieldset}) => {
    const field = new Element("div", fieldset)
    Object.assign(field.dataset, {coreInput: "", inputType: "textarea", inputClearable: "true"})
    const input = new Element("textarea", field)
    input.dataset.inputValue = ""
    input.value = "Another field"
    const button = new Element("button", field)
    button.dataset.inputClear = ""
    second = {input, button}
  })
  try {
    assert.equal(setup.button.hidden, false)
    assert.equal(second.button.hidden, false)
    setup.fieldset.disabled = true
    fixture.observer.callback([{type: "attributes", target: setup.fieldset, attributeName: "disabled", addedNodes: []}])
    assert.equal(setup.input.matches(":disabled"), true)
    assert.equal(second.input.matches(":disabled"), true)
    assert.equal(setup.button.hidden, true)
    assert.equal(second.button.hidden, true)
    setup.click()
    assert.equal(setup.input.value, "Entered value")
    assert.deepEqual(setup.events, [])
    setup.fieldset.disabled = false
    fixture.observer.callback([{type: "attributes", target: setup.fieldset, attributeName: "disabled", addedNodes: []}])
    assert.equal(setup.button.hidden, false)
    assert.equal(second.button.hidden, false)
  } finally { setup.cleanup() }
})

test("a selected color format keeps whole-control clearing available when its value is blank", () => {
  let format
  const setup = fixture("color", "", true, ({field, input}) => {
    input.type = "text"
    const wrapper = new Element("div", field)
    wrapper.dataset.colorSpaceSelect = ""
    const combo = new Element("div", wrapper)
    combo.className = "core-selection-input pc-combo-box"
    format = new Element("select", combo)
    format.className = "pc-combo-box__select"
    format.value = "hex"
  })
  try {
    assert.equal(setup.field.dataset.inputHasValue, "true")
    assert.equal(setup.button.hidden, false)
    format.value = ""
    format.dispatchEvent(new Event("change", {bubbles: true}))
    assert.equal(setup.field.dataset.inputHasValue, "false")
    assert.equal(setup.button.hidden, true)
    assert.deepEqual(setup.events, [])
  } finally { setup.cleanup() }
})

test("specialized telephone clearing restores focus to its visible number instead of the composite", () => {
  let number
  const setup = fixture("tel", "+60", true, ({field, input}) => {
    input.type = "hidden"
    const wrapper = new Element("div", field)
    number = new Element("input", wrapper)
    number.type = "tel"
    number.dataset.telNumber = ""
    number.dataset.inputValue = ""
  })
  try {
    setup.field.addEventListener("input:clear", event => {
      event.preventDefault()
      setup.input.value = ""
      number.value = ""
    })
    setup.button.focus()
    setup.click()
    assert.equal(document.activeElement, number)
    assert.equal(setup.button.hidden, true)
    assert.deepEqual(setup.events, [])
  } finally { setup.cleanup() }
})

test("structural calendar readonly does not prevent clearing an editable picker", () => {
  const setup = fixture("date", "2026-04-23")
  try {
    setup.input.readOnly = true
    setup.click()
    assert.equal(setup.input.value, "")
  } finally { setup.cleanup() }
})

test("reclicking the selected radio clears after native activation rollback", async () => {
  const setup = fixture("radio", "email")
  try {
    setup.input.checked = true
    setup.controls.refresh(setup.field)
    const event = new Event("click", {bubbles: true, cancelable: true})
    setup.input.dispatchEvent(event)
    assert.equal(event.defaultPrevented, true)
    setup.input.checked = true
    await Promise.resolve()
    assert.equal(setup.input.checked, true)
    await new Promise(resolve => setTimeout(resolve, 0))
    assert.equal(setup.input.checked, false)
    assert.deepEqual(setup.events.map(([name]) => name), ["input", "change", "blur"])
    assert.equal(setup.field.dataset.inputHasValue, "false")
  } finally { setup.cleanup() }
})

test("choosing a different radio and nonclearable radios preserve native selection", () => {
  for (const clearable of [true, false]) {
    const setup = fixture("radio", "email", clearable)
    try {
      setup.input.checked = false
      setup.controls.refresh(setup.field)
      setup.input.checked = true
      const event = new Event("click", {bubbles: true, cancelable: true})
      setup.input.dispatchEvent(event)
      assert.equal(event.defaultPrevented, false)
      assert.equal(setup.input.checked, true)
    } finally { setup.cleanup() }
  }
})

test("Space clears the checked radio while arrows and unchecked radios keep native keyboard behavior", async () => {
  const setup = fixture("radio", "email")
  try {
    setup.input.checked = true
    setup.controls.refresh(setup.field)
    const arrow = Object.assign(new Event("keydown", {bubbles: true, cancelable: true}), {key: "ArrowDown"})
    setup.input.dispatchEvent(arrow)
    assert.equal(arrow.defaultPrevented, false)
    const space = Object.assign(new Event("keydown", {bubbles: true, cancelable: true}), {key: " "})
    setup.input.dispatchEvent(space)
    assert.equal(space.defaultPrevented, true)
    await new Promise(resolve => setTimeout(resolve, 0))
    assert.equal(setup.input.checked, false)
    const repeat = Object.assign(new Event("keydown", {bubbles: true, cancelable: true}), {key: " ", repeat: true})
    setup.input.dispatchEvent(repeat)
    assert.equal(repeat.defaultPrevented, true)
    const choose = Object.assign(new Event("keydown", {bubbles: true, cancelable: true}), {key: " "})
    setup.input.dispatchEvent(choose)
    assert.equal(choose.defaultPrevented, false)
  } finally { setup.cleanup() }
})

test("teardown removes document listeners and disconnects patch observation", () => {
  const setup = fixture()
  try {
    setup.controls.destroyed()
    assert.equal(setup.doc.listeners.length, 0)
    assert.equal(fixture.observer.observing, false)
  } finally { setup.cleanup() }
})

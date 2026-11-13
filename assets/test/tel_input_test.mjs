import test from "node:test"
import assert from "node:assert/strict"
import {getEventListeners} from "node:events"
import {readFile} from "node:fs/promises"

const source = await readFile(new URL("../js/tel_input.js", import.meta.url), "utf8")
const TelInput = (await import(`data:text/javascript;base64,${Buffer.from(source).toString("base64")}`)).default
const fields = new Set()

class Element extends EventTarget {
  constructor() {
    super()
    this.dataset = {}
    this.value = ""
    this.attributes = new Map()
    this.captureListeners = new Map()
  }
  addEventListener(name, callback, options) {
    super.addEventListener(name, callback, options)
    if (options === true) {
      if (!this.captureListeners.has(name)) this.captureListeners.set(name, new Set())
      this.captureListeners.get(name).add(callback)
    }
  }
  removeEventListener(name, callback, options) {
    super.removeEventListener(name, callback, options)
    if (options === true) this.captureListeners.get(name)?.delete(callback)
  }
  hasAttribute(name) { return this.attributes.has(name) }
  matches(selector) { return selector === ":disabled" && !!(this.disabled || this.inheritedDisabled) }
  closest() { return this.parentElement }
  dispatchEvent(event) {
    if (!event.target) {
      Object.defineProperty(event, "target", {value: this})
      const ancestors = []
      for (let element = this.parentElement; element; element = element.parentElement) ancestors.unshift(element)
      for (const ancestor of ancestors) {
        for (const callback of ancestor.captureListeners.get(event.type) || []) callback(event)
        if (event.cancelBubble) return !event.defaultPrevented
      }
    }
    const result = super.dispatchEvent(event)
    if (event.bubbles && !event.cancelBubble) this.parentElement?.dispatchEvent(event)
    return result
  }
}

test.afterEach(() => {
  for (const field of fields) if (!field.destroyed) field.context.destroyed()
  fields.clear()
})

function openInput(options = {}) {
  const root = new Element()
  root.dataset.inputClearable = String(options.clearable !== false)
  const wrapper = new Element()
  wrapper.parentElement = root
  wrapper.dataset = {countryName: "profile[phone_country_code]", countries: JSON.stringify({MY: "+60", US: "+1"})}
  const country = new Element()
  country.name = wrapper.dataset.countryName
  country.value = "MY"
  const number = new Element()
  number.attributes.set("data-tel-number", "")
  number.value = "123456789"
  Object.assign(number, options)
  const composite = new Element()
  composite.name = "profile[phone]"
  composite.value = "+60123456789"
  for (const control of [country, number, composite]) control.parentElement = wrapper
  const selectors = {[`select[name='${country.name}']`]: country, "[data-tel-number]": number, "[data-tel-composite]": composite}
  wrapper.querySelector = selector => selectors[selector]
  const context = {...TelInput, el: wrapper}
  const notifications = []
  for (const type of ["input", "change"]) root.addEventListener(type, event => notifications.push({type, name: event.target.name, country: country.value, number: number.value, composite: composite.value}))
  const field = {
    root, wrapper, country, number, composite, context, notifications, countryLabel: "+60",
    clear() {
      const event = new CustomEvent("input:clear", {bubbles: true, cancelable: true})
      root.dispatchEvent(event)
      return event
    },
  }
  country.addEventListener("change", () => { field.countryLabel = JSON.parse(wrapper.dataset.countries)[country.value] ?? "" })
  context.mounted()
  fields.add(field)
  return field
}

test("telephone clear resets both visible parts and sends only the final empty composite to the form", () => {
  const field = openInput()
  assert.equal(field.clear().defaultPrevented, true)
  assert.equal(field.country.value, "")
  assert.equal(field.number.value, "")
  assert.equal(field.composite.value, "")
  assert.equal(field.countryLabel, "")
  assert.deepEqual(field.notifications, [
    {type: "input", name: "profile[phone]", country: "", number: "", composite: ""},
    {type: "change", name: "profile[phone]", country: "", number: "", composite: ""},
  ])
  field.country.value = "US"
  field.country.dispatchEvent(new Event("change", {bubbles: true}))
  field.number.value = " 5551234 "
  field.number.dispatchEvent(new Event("input", {bubbles: true}))
  assert.equal(field.composite.value, "+15551234")
})

test("telephone editing keeps its existing composition and ignores unrelated input", () => {
  const field = openInput()
  field.number.value = "456"
  field.number.dispatchEvent(new Event("input", {bubbles: true}))
  assert.equal(field.composite.value, "+60456")
  field.country.value = "US"
  field.country.dispatchEvent(new Event("change", {bubbles: true}))
  assert.equal(field.composite.value, "+1456")
  field.composite.value = "unchanged"
  field.composite.dispatchEvent(new Event("input", {bubbles: true}))
  assert.equal(field.composite.value, "unchanged")
})

test("unavailable telephone controls cannot clear and destruction removes the clear listener", () => {
  for (const options of [{clearable: false}, {readOnly: true}, {disabled: true}, {inheritedDisabled: true}]) {
    const field = openInput(options)
    field.clear()
    assert.equal(field.country.value, "MY")
    assert.equal(field.number.value, "123456789")
    assert.equal(field.composite.value, "+60123456789")
    assert.deepEqual(field.notifications, [])
  }
  const field = openInput()
  field.context.destroyed()
  field.destroyed = true
  assert.equal(getEventListeners(field.root, "input:clear").length, 0)
  assert.equal(getEventListeners(field.wrapper, "input").length, 0)
  assert.equal(getEventListeners(field.wrapper, "change").length, 0)
  assert.equal(field.clear().defaultPrevented, false)
})

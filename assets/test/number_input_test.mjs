import test from "node:test"
import assert from "node:assert/strict"
import {readFile} from "node:fs/promises"

const source = await readFile(new URL("../js/number_input.js", import.meta.url), "utf8")
const NumberInput = (await import(`data:text/javascript;base64,${Buffer.from(source).toString("base64")}`)).default

class Element extends EventTarget {
  constructor() {
    super()
    this.parentElement = null
    this.dataset = {}
    this.disabled = false
    this.readOnly = false
    this.value = ""
    this.step = ""
  }
  closest() {
    for (let element = this; element; element = element.parentElement) {
      if (element.dataset.numberStep !== undefined) return element
    }
    return null
  }
  contains(node) {
    for (let element = node; element; element = element.parentElement) if (element === this) return true
    return false
  }
  dispatchEvent(event) {
    if (!event.target) Object.defineProperty(event, "target", {value: this})
    const result = super.dispatchEvent(event)
    if (event.bubbles && !event.cancelBubble) this.parentElement?.dispatchEvent(event)
    return result
  }
}

function openInput(options = {}) {
  const wrapper = new Element()
  const controls = {input: new Element(), up: new Element(), down: new Element()}
  const calls = []
  const notifications = []
  Object.assign(controls.input, options)
  controls.up.dataset.numberStep = "1"
  controls.down.dataset.numberStep = "-1"
  controls.input.stepUp = function() { calls.push({method: "up", input: this}) }
  controls.input.stepDown = function() { calls.push({method: "down", input: this}) }
  for (const control of Object.values(controls)) control.parentElement = wrapper
  wrapper.querySelector = () => controls.input
  controls.input.addEventListener("input", event => notifications.push({type: event.type, value: event.target.value, bubbles: event.bubbles}))
  controls.input.addEventListener("blur", event => notifications.push({type: event.type, value: event.target.value, bubbles: event.bubbles}))
  const context = {...NumberInput, el: wrapper}
  context.mounted()
  return {
    wrapper, controls, calls, notifications, context,
    click(direction = "up", target = controls[direction]) {
      const event = new Event("click", {bubbles: true, cancelable: true})
      target.dispatchEvent(event)
      return event
    },
  }
}

test("step buttons delegate to native methods and flush the changed value through input then blur", () => {
  const field = openInput({value: "24000", step: "0.5"})
  field.controls.input.stepUp = function() {
    field.calls.push({method: "up", input: this, value: this.value})
    this.value = "24000.5"
  }
  field.controls.input.stepDown = function() {
    field.calls.push({method: "down", input: this, value: this.value})
    this.value = "24000"
  }
  const icon = new Element()
  icon.parentElement = field.controls.up
  assert.equal(field.click("up", icon).defaultPrevented, true)
  field.click("down")
  assert.deepEqual(field.calls.map(call => [call.method, call.value]), [["up", "24000"], ["down", "24000.5"]])
  assert.ok(field.calls.every(call => call.input === field.controls.input))
  assert.deepEqual(field.notifications, [
    {type: "input", value: "24000.5", bubbles: true},
    {type: "blur", value: "24000.5", bubbles: false},
    {type: "input", value: "24000", bubbles: true},
    {type: "blur", value: "24000", bubbles: false},
  ])
  field.context.destroyed()
})

test("native limits that leave the value unchanged do not trigger form updates", () => {
  const field = openInput({value: "100"})
  field.click("up")
  field.click("down")
  assert.deepEqual(field.calls.map(call => call.method), ["up", "down"])
  assert.deepEqual(field.notifications, [])
  field.context.destroyed()
})

test("disabled, readonly, and any-step fields never invoke invalid native stepping", () => {
  for (const options of [{disabled: true}, {readOnly: true}, {step: "any"}, {step: "ANY"}]) {
    const field = openInput(options)
    field.controls.input.stepUp = () => { throw new Error("This field must not invoke native stepping") }
    field.controls.input.stepDown = () => { throw new Error("This field must not invoke native stepping") }
    field.click("up")
    field.click("down")
    assert.deepEqual(field.notifications, [])
    field.controls.input.disabled = false
    field.controls.input.readOnly = false
    field.controls.input.step = "0.25"
    field.context.updated()
    field.context.destroyed()
  }
})

test("pointer presses preserve input focus without preventing keyboard button activation", () => {
  const field = openInput()
  const press = new Event("pointerdown", {bubbles: true, cancelable: true})
  field.controls.up.dispatchEvent(press)
  assert.equal(press.defaultPrevented, true)
  const keyboard = new Event("keydown", {bubbles: true, cancelable: true})
  field.controls.up.dispatchEvent(keyboard)
  assert.equal(keyboard.defaultPrevented, false)
  field.click("up")
  assert.equal(field.calls.length, 1)
  field.context.destroyed()
})

test("patches use the current native input and destruction removes delegated listeners", () => {
  const field = openInput({disabled: true})
  const original = field.controls.input
  const replacement = new Element()
  replacement.parentElement = field.wrapper
  replacement.stepUp = function() { field.calls.push({method: "up", input: this}) }
  replacement.stepDown = function() { field.calls.push({method: "down", input: this}) }
  field.controls.input = replacement
  field.context.updated()
  field.click("up")
  assert.equal(field.calls[0].input, replacement)
  assert.notEqual(field.calls[0].input, original)
  field.context.destroyed()
  field.click("down")
  assert.equal(field.calls.length, 1)
  const press = new Event("pointerdown", {bubbles: true, cancelable: true})
  field.controls.down.dispatchEvent(press)
  assert.equal(press.defaultPrevented, false)
})

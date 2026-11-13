import test from "node:test"
import assert from "node:assert/strict"
import {getEventListeners} from "node:events"
import {readFile} from "node:fs/promises"

const source = (await readFile(new URL("../js/vcalendar.js", import.meta.url), "utf8"))
  .replace('import("vanilla-calendar-pro")', "globalThis.calendarTestLoad()")
const VCalendar = (await import(`data:text/javascript;base64,${Buffer.from(source).toString("base64")}`)).default
const originalGlobals = Object.fromEntries(["document", "HTMLElement", "MutationObserver", "calendarTestLoad", "window", "getComputedStyle"].map(name => [name, globalThis[name]]))
const fields = new Set()
const elements = new Map()

class Element extends EventTarget {
  constructor() {
    super()
    this.dataset = {}
    this.attributes = new Map()
    this.value = ""
    this.parentElement = null
    this.popoverOpen = false
    this.weekCells = []
    this.style = {maxHeight: ""}
    this.rect = {top: 100, bottom: 144, left: 20, right: 300, width: 280, height: 44}
    this.scrollHeight = 198
    this.borderHeight = 2
    this.rectReads = 0
  }
  setAttribute(name, value) { this.attributes.set(name, String(value)) }
  getAttribute(name) { return this.attributes.get(name) ?? null }
  removeAttribute(name) { this.attributes.delete(name) }
  hasAttribute(name) { return this.attributes.has(name) }
  toggleAttribute(name, force = !this.hasAttribute(name)) {
    if (force) this.setAttribute(name, "")
    else this.removeAttribute(name)
    return force
  }
  getBoundingClientRect() { this.rectReads++; return this.rect }
  get offsetHeight() {
    const limit = parseFloat(this.style.maxHeight)
    return Math.max(this.borderHeight, Math.min(this.scrollHeight + this.borderHeight, Number.isNaN(limit) ? Infinity : limit))
  }
  get clientHeight() { return this.offsetHeight - this.borderHeight }
  matches(selector) { return selector === ":disabled" ? !!(this.disabled || this.inheritedDisabled) : selector === ":popover-open" && this.popoverOpen }
  closest() { return this.parentElement }
  querySelectorAll(selector) { return selector === "[data-vc-week-number]" ? this.weekCells : [] }
  showPopover() {
    const event = Object.assign(new Event("beforetoggle", {cancelable: true}), {newState: "open"})
    this.dispatchEvent(event)
    if (!event.defaultPrevented) this.popoverOpen = true
  }
  hidePopover() {
    this.dispatchEvent(Object.assign(new Event("beforetoggle"), {newState: "closed"}))
    this.popoverOpen = false
  }
  dispatchEvent(event) {
    if (!event.target) Object.defineProperty(event, "target", {value: this})
    const result = super.dispatchEvent(event)
    if (event.bubbles && !event.cancelBubble) this.parentElement?.dispatchEvent(event)
    return result
  }
}

class Calendar {
  constructor(element, options) {
    this.options = options
    this.context = {mainElement: element, selectedDates: options.selectedDates ?? [], selectedTime: options.selectedTime ?? "", selectedYear: options.selectedYear, selectedMonth: options.selectedMonth}
    this.updates = []
  }
  init() { this.options.onInit(this) }
  set(values, options) { this.updates.push({values, options}); Object.assign(this.context, values); this.options.onUpdate(this) }
  destroy() { this.destroyed = true }
}

const library = {Calendar, time: {}, weeks: {}}
const viewport = Object.assign(new EventTarget(), {height: 800, offsetTop: 0})
const browser = Object.assign(new EventTarget(), {innerHeight: 800, visualViewport: viewport})
globalThis.window = browser
globalThis.getComputedStyle = element => ({marginTop: "4px", marginBottom: "4px", ...element.computedStyle})
globalThis.document = {getElementById: id => elements.get(id)}
globalThis.HTMLElement = Element
globalThis.MutationObserver = class { observe() {}; disconnect() {} }
globalThis.calendarTestLoad = async () => library

test.afterEach(() => {
  for (const field of fields) field.context.destroyed()
  fields.clear()
  elements.clear()
  globalThis.calendarTestLoad = async () => library
  Object.assign(viewport, {height: 800, offsetTop: 0})
  browser.innerHeight = 800
  browser.visualViewport = viewport
})
test.after(() => {
  for (const [name, value] of Object.entries(originalGlobals)) {
    if (value === undefined) delete globalThis[name]
    else globalThis[name] = value
  }
})

function openInput(mode = "date", value = "2026-04-23", options = {}) {
  const root = new Element()
  root.dataset.inputClearable = String(options.clearable !== false)
  const input = new Element()
  input.id = `calendar-${fields.size}`
  input.dataset = {vcMode: mode, vcValue: value, vcToday: "2026-11-13", vcTimezone: "Asia/Singapore"}
  input.parentElement = root
  input.readOnly = true
  Object.assign(input, options)
  const popover = new Element()
  popover.dataset = {vc: "calendar", vcTheme: "elixirbits"}
  if (mode === "week") {
    const cell = new Element()
    cell.dataset = {vcWeekNumber: "17", vcWeekYear: "2026"}
    popover.weekCells.push(cell)
  }
  popover.setAttribute("aria-label", "Choose date")
  elements.set(`${input.id}-calendar`, popover)
  const notifications = []
  for (const name of ["input", "change"]) root.addEventListener(name, () => notifications.push({name, value: input.value}))
  const context = {...VCalendar, el: input}
  const field = {
    root, input, popover, context, notifications,
    clear() {
      const event = new CustomEvent("input:clear", {cancelable: true, bubbles: true})
      root.dispatchEvent(event)
      return event
    },
  }
  fields.add(field)
  field.ready = context.mounted()
  return field
}

test("clearing each calendar mode resets its selection and preserves subsequent picker callbacks", async () => {
  for (const [mode, initial, selected] of [
    ["date", "2026-04-23", "2026-11-14"],
    ["datetime-local", "2026-04-23T09:30", "2026-11-14T12:45"],
    ["time", "09:30", "12:45"],
    ["week", "2026-W17", "2026-W46"],
    ["month", "2026-04", "2026-11"],
  ]) {
    const field = openInput(mode, initial)
    await field.ready
    if (mode === "week") assert.equal(field.popover.weekCells[0].getAttribute("data-vc-week-selected"), "")
    field.input.dispatchEvent(new Event("click"))
    assert.equal(field.popover.popoverOpen, true)
    assert.equal(field.clear().defaultPrevented, true)
    assert.equal(field.input.value, "")
    assert.deepEqual(field.context.calendar.context.selectedDates, [])
    assert.equal(field.context.calendar.context.selectedTime, "00:00")
    assert.equal(field.context.selectedWeek, null)
    if (mode === "week") assert.equal(field.popover.weekCells[0].getAttribute("data-vc-week-selected"), null)
    assert.equal(field.popover.popoverOpen, false)
    assert.deepEqual(field.notifications, [{name: "input", value: ""}, {name: "change", value: ""}])
    assert.equal(field.context.calendar.updates.length, 1)
    field.input.dataset.vcValue = ""
    field.context.updated()
    assert.equal(field.input.value, "")
    assert.equal(field.popover.popoverOpen, false)
    const calendar = field.context.calendar
    Object.assign(calendar.context, {selectedDates: ["2026-11-14"], selectedTime: "12:45", selectedYear: 2026, selectedMonth: 10})
    if (mode === "date" || mode === "datetime-local") calendar.options.onClickDate(calendar)
    else if (mode === "time") calendar.options.onChangeTime(calendar)
    else if (mode === "week") calendar.options.onClickWeekNumber(calendar, 46, 2026)
    else calendar.options.onClickMonth(calendar)
    assert.equal(field.input.value, selected)
  }
})

test("ordinary empty input or change events reset the calendar without reopening it", async () => {
  for (const name of ["input", "change"]) {
    const field = openInput("datetime-local", "2026-04-23T09:30")
    await field.ready
    field.input.dispatchEvent(new Event("click"))
    field.input.value = ""
    field.input.dispatchEvent(new Event(name, {bubbles: true}))
    assert.deepEqual(field.context.calendar.context.selectedDates, [])
    assert.equal(field.context.calendar.context.selectedTime, "00:00")
    assert.equal(field.popover.popoverOpen, false)
  }
})

test("calendar clear honors authored eligibility and disabled fields while structural readonly remains editable", async () => {
  for (const options of [{clearable: false}, {disabled: true}, {inheritedDisabled: true}]) {
    const field = openInput("date", "2026-04-23", options)
    await field.ready
    field.clear()
    assert.equal(field.input.value, "2026-04-23")
    assert.deepEqual(field.notifications, [])
  }
})

test("clearing while the calendar library loads cannot restore the previous selection", async () => {
  let resolve
  globalThis.calendarTestLoad = () => new Promise(ready => { resolve = ready })
  const field = openInput("date", "2026-04-23")
  field.clear()
  resolve(library)
  await field.ready
  assert.equal(field.input.value, "")
  assert.deepEqual(field.context.calendar.context.selectedDates, [])
  assert.equal(field.popover.popoverOpen, false)
})

test("all calendar modes prefer a full panel below, then above, then scroll on the roomier side", async () => {
  const values = {date: "2026-04-23", "datetime-local": "2026-04-23T09:30", time: "09:30", week: "2026-W17", month: "2026-04"}
  const scenarios = [
    {top: 450, bottom: 494, height: 200, flip: false, room: 298},
    {top: 600, bottom: 644, height: 200, flip: true, room: 592},
    {top: 450, bottom: 494, height: 500, flip: true, room: 442},
    {top: 300, bottom: 344, height: 500, flip: false, room: 448},
  ]
  for (const [mode, value] of Object.entries(values)) for (const scenario of scenarios) {
    const field = openInput(mode, value)
    await field.ready
    Object.assign(field.input.rect, {top: scenario.top, bottom: scenario.bottom})
    field.popover.scrollHeight = scenario.height - field.popover.borderHeight
    field.input.dispatchEvent(new Event("click"))
    assert.equal(field.popover.popoverOpen, true, mode)
    assert.equal(field.popover.hasAttribute("data-flip"), scenario.flip, `${mode}: ${JSON.stringify(scenario)}`)
    assert.equal(field.popover.style.maxHeight, `${scenario.room}px`)
    assert.equal(field.popover.offsetHeight, Math.min(scenario.height, scenario.room))
    assert.deepEqual(field.notifications, [])
    field.popover.hidePopover()
  }
})

test("cropped panels reserve both block margins between the anchor and viewport edge", async () => {
  viewport.height = 500
  for (const [marginTop, marginBottom] of [[4, 4], [3, 7]]) {
    for (const [top, bottom, flip] of [[300, 344, true], [100, 144, false]]) {
      const field = openInput()
      await field.ready
      Object.assign(field.input.rect, {top, bottom})
      field.popover.scrollHeight = 598
      field.popover.computedStyle = {marginTop: `${marginTop}px`, marginBottom: `${marginBottom}px`}
      field.input.dispatchEvent(new Event("click"))
      assert.equal(field.popover.hasAttribute("data-flip"), flip)
      const available = flip ? top : viewport.height - bottom
      assert.equal(field.popover.offsetHeight + marginTop + marginBottom, available)
      assert.ok(field.popover.offsetHeight < field.popover.scrollHeight)
      field.popover.hidePopover()
    }
  }
})

test("open calendars reposition on scrolling, window resizing, and visual viewport changes", async () => {
  const field = openInput()
  await field.ready
  Object.assign(field.input.rect, {top: 450, bottom: 494})
  field.popover.scrollHeight = 498
  field.input.dispatchEvent(new Event("click"))
  assert.equal(field.popover.hasAttribute("data-flip"), true)
  assert.equal(field.popover.style.maxHeight, "442px")

  Object.assign(field.input.rect, {top: 200, bottom: 244})
  browser.dispatchEvent(new Event("scroll"))
  assert.equal(field.popover.hasAttribute("data-flip"), false)
  assert.equal(field.popover.style.maxHeight, "548px")

  Object.assign(field.input.rect, {top: 250, bottom: 294})
  viewport.height = 400
  browser.dispatchEvent(new Event("resize"))
  assert.equal(field.popover.hasAttribute("data-flip"), true)
  assert.equal(field.popover.style.maxHeight, "242px")

  viewport.offsetTop = 120
  viewport.dispatchEvent(new Event("scroll"))
  assert.equal(field.popover.hasAttribute("data-flip"), false)
  assert.equal(field.popover.style.maxHeight, "218px")

  viewport.height = 600
  viewport.dispatchEvent(new Event("resize"))
  assert.equal(field.popover.style.maxHeight, "418px")
  assert.deepEqual(field.notifications, [])
})

test("calendar rendering remeasures changed content without closing or submitting the field", async () => {
  const field = openInput("datetime-local", "2026-04-23T09:30")
  await field.ready
  Object.assign(field.input.rect, {top: 450, bottom: 494})
  field.popover.scrollHeight = 198
  field.input.dispatchEvent(new Event("click"))
  assert.equal(field.popover.hasAttribute("data-flip"), false)
  assert.equal(field.popover.offsetHeight, 200)

  field.popover.scrollHeight = 498
  field.context.calendar.options.onUpdate(field.context.calendar)
  assert.equal(field.popover.hasAttribute("data-flip"), true)
  assert.equal(field.popover.offsetHeight, 442)

  field.popover.scrollHeight = 198
  field.context.calendar.options.onUpdate(field.context.calendar)
  assert.equal(field.popover.hasAttribute("data-flip"), false)
  assert.equal(field.popover.offsetHeight, 200)
  assert.equal(field.popover.popoverOpen, true)
  assert.deepEqual(field.notifications, [])
})

test("cropping retains the natural panel height including borders for later placement decisions", async () => {
  viewport.height = 500
  const field = openInput()
  await field.ready
  Object.assign(field.input.rect, {top: 200, bottom: 244})
  field.popover.scrollHeight = 498
  field.input.dispatchEvent(new Event("click"))
  assert.equal(field.popover.offsetHeight, 248)
  assert.equal(field.popover.clientHeight, 246)

  viewport.height = 900
  Object.assign(field.input.rect, {top: 450, bottom: 494})
  viewport.dispatchEvent(new Event("resize"))
  assert.equal(field.popover.hasAttribute("data-flip"), true)
  assert.equal(field.popover.style.maxHeight, "442px")

  viewport.height = 1200
  viewport.dispatchEvent(new Event("resize"))
  assert.equal(field.popover.hasAttribute("data-flip"), false)
  assert.equal(field.popover.offsetHeight, 500)
  assert.equal(field.popover.style.maxHeight, "698px")
})

test("window geometry remains usable when the browser has no visual viewport API", async () => {
  browser.visualViewport = undefined
  browser.innerHeight = 500
  const field = openInput()
  await field.ready
  Object.assign(field.input.rect, {top: 200, bottom: 244})
  field.popover.scrollHeight = 498
  field.input.dispatchEvent(new Event("click"))
  assert.equal(field.popover.style.maxHeight, "248px")
  browser.innerHeight = 1000
  browser.dispatchEvent(new Event("resize"))
  assert.equal(field.popover.offsetHeight, 500)
  assert.equal(field.popover.style.maxHeight, "748px")
  assert.equal(getEventListeners(viewport, "resize").length, 0)
})

test("closing and destroying calendars remove reposition listeners and stop geometry work", async () => {
  const field = openInput()
  await field.ready
  assert.equal(field.input.rectReads, 0)
  field.input.dispatchEvent(new Event("click"))
  field.input.dispatchEvent(new Event("click"))
  for (const target of [browser, viewport]) for (const name of ["scroll", "resize"]) {
    assert.equal(getEventListeners(target, name).length, 1)
  }
  field.popover.hidePopover()
  assert.equal(field.popover.style.maxHeight, "")
  assert.equal(field.popover.hasAttribute("data-flip"), false)
  for (const target of [browser, viewport]) for (const name of ["scroll", "resize"]) {
    assert.equal(getEventListeners(target, name).length, 0)
  }
  const closedReads = field.input.rectReads
  browser.dispatchEvent(new Event("scroll"))
  viewport.dispatchEvent(new Event("resize"))
  field.context.calendar.options.onUpdate(field.context.calendar)
  assert.equal(field.input.rectReads, closedReads)

  field.input.dispatchEvent(new Event("click"))
  field.context.destroyed()
  assert.equal(field.popover.popoverOpen, false)
  for (const target of [browser, viewport]) for (const name of ["scroll", "resize"]) {
    assert.equal(getEventListeners(target, name).length, 0)
  }
  const destroyedReads = field.input.rectReads
  browser.dispatchEvent(new Event("resize"))
  viewport.dispatchEvent(new Event("scroll"))
  assert.equal(field.input.rectReads, destroyedReads)
})

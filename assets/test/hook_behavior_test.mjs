import test from "node:test"
import assert from "node:assert/strict"
import {getEventListeners} from "node:events"
import {readFile} from "node:fs/promises"

const loadHook = async name => {
  const source = await readFile(new URL(`../js/${name}.js`, import.meta.url), "utf8")
  return (await import(`data:text/javascript;base64,${Buffer.from(source).toString("base64")}`)).default
}

class Element extends EventTarget {
  constructor() {
    super()
    this.attributes = new Map()
    this.dataset = {}
    this.style = {}
    this.textContent = ""
    this.isConnected = true
    this.offsetWidth = 80
    this.offsetHeight = 24
    this.clientWidth = 80
    this.clientHeight = 24
    this.scrollWidth = 80
    this.scrollHeight = 24
    this.tagName = "DIV"
    this.type = ""
    this.value = ""
    this.parentElement = null
    this.children = []
    this.computedStyle = {overflowX: "visible", overflowY: "visible", webkitLineClamp: "none", textTransform: "none"}
  }
  setAttribute(name, value) { this.attributes.set(name, String(value)) }
  getAttribute(name) { return this.attributes.get(name) ?? null }
  removeAttribute(name) { this.attributes.delete(name) }
  get innerText() { return this.renderedText ?? this.textContent }
  closest() {
    for (let el = this; el; el = el.parentElement) {
      if (el.dataset.tooltip !== undefined || el.getAttribute("title") !== null) return el
    }
    return null
  }
  matches(selector) {
    const input = this.tagName === "INPUT"
    if (selector === "input, textarea") return input || this.tagName === "TEXTAREA"
    if (selector === "input[type=password], input[type=file]") return input && ["password", "file"].includes(this.type)
    return false
  }
  querySelectorAll() { return this.children.flatMap(child => [child, ...child.querySelectorAll()]) }
  contains(node) {
    for (let el = node; el; el = el.parentElement) if (el === this) return true
    return false
  }
  getBoundingClientRect() { return {left: 20, bottom: 40} }
  remove() { this.isConnected = false }
  focus() { this.focused = true }
}

const event = (name, values = {}) => Object.assign(new Event(name, {cancelable: true}), values)

// The browser globals are deterministic so patching and elapsed-time behavior can be exercised without a running Phoenix server.
test("password visibility survives patches and cleans up replaced controls", async () => {
  const hook = await loadHook("password_visibility")
  let input = new Element()
  let button = new Element()
  const show = new Element()
  const hide = new Element()
  const context = {...hook, el: {querySelector: selector => ({input, "[data-password-toggle]": button, "[data-password-show-icon]": show, "[data-password-hide-icon]": hide})[selector]}}

  context.mounted()
  button.dispatchEvent(event("click"))
  assert.equal(input.type, "text")
  assert.equal(button.getAttribute("aria-pressed"), "true")
  assert.equal(input.focused, true)

  const oldButton = button
  input = new Element()
  button = new Element()
  context.updated()
  assert.equal(input.type, "text")
  oldButton.dispatchEvent(event("click"))
  assert.equal(input.type, "text")

  button.dispatchEvent(event("click"))
  assert.equal(input.type, "password")
  input.disabled = true
  button.disabled = true
  context.updated()
  assert.equal(button.disabled, true)
  button.dispatchEvent(event("click"))
  assert.equal(input.type, "password")
  assert.equal(button.getAttribute("aria-pressed"), "false")
  input.disabled = false
  button.disabled = false
  context.updated()
  assert.equal(button.disabled, false)
  button.dispatchEvent(event("click"))
  assert.equal(input.type, "text")
  context.destroyed()
  button.dispatchEvent(event("click"))
  assert.equal(input.type, "text")
})

test("timers share a one-second interval, resume immediately, and clean up after patches", async () => {
  const originalNow = Date.now
  const originalInterval = globalThis.setInterval
  const originalClear = globalThis.clearInterval
  const originalDocument = globalThis.document
  let now = Date.parse("2026-10-09T00:00:00Z")
  const intervals = new Map()
  const document = new EventTarget()
  document.hidden = false
  let sequence = 0
  Date.now = () => now
  globalThis.setInterval = (callback, delay) => { intervals.set(++sequence, {callback, delay}); return sequence }
  globalThis.clearInterval = id => intervals.delete(id)
  globalThis.document = document

  try {
    const hook = await loadHook("live_timer")
    const elapsed = new Element()
    elapsed.dataset.target = "2026-10-09T00:00:00Z"
    const countdown = new Element()
    countdown.dataset.target = "2026-10-09T00:01:00Z"
    countdown.dataset.mode = "countdown"
    const first = {...hook, el: elapsed}
    const second = {...hook, el: countdown}
    first.mounted()
    second.mounted()
    assert.equal(intervals.size, 1)
    assert.equal(getEventListeners(document, "visibilitychange").length, 1)
    assert.equal(elapsed.textContent, "0:00")
    assert.equal(countdown.textContent, "in 1:00")

    const [{callback, delay}] = intervals.values()
    assert.equal(delay, 1000)
    now += 2000
    callback()
    assert.equal(elapsed.textContent, "0:02")
    assert.equal(countdown.textContent, "in 0:58")

    document.hidden = true
    now += 123_000
    callback()
    assert.equal(elapsed.textContent, "0:02")
    assert.equal(countdown.textContent, "in 0:58")
    document.hidden = false
    document.dispatchEvent(event("visibilitychange"))
    assert.equal(elapsed.textContent, "2:05")
    assert.equal(countdown.textContent, "+1:05")
    countdown.dataset.mode = "elapsed"
    second.updated()
    assert.equal(countdown.textContent, "1:05")
    first.destroyed()
    assert.equal(intervals.size, 1)
    second.destroyed()
    assert.equal(intervals.size, 0)
    assert.equal(getEventListeners(document, "visibilitychange").length, 0)

    first.mounted()
    elapsed.isConnected = false
    const [detachedTick] = intervals.values()
    detachedTick.callback()
    assert.equal(intervals.size, 0)
    assert.equal(getEventListeners(document, "visibilitychange").length, 0)
  } finally {
    Date.now = originalNow
    globalThis.setInterval = originalInterval
    globalThis.clearInterval = originalClear
    globalThis.document = originalDocument
  }
})

test("delegated tooltip describes focused controls across patches and restores native titles", async () => {
  const originalDocument = globalThis.document
  const originalWindow = globalThis.window
  const originalObserver = globalThis.MutationObserver
  const originalResizeObserver = globalThis.ResizeObserver
  const document = new EventTarget()
  const window = new EventTarget()
  const tip = new Element()
  document.createElement = () => tip
  document.body = {appendChild() {}}
  window.innerWidth = 500
  window.innerHeight = 500
  let observerCallback
  let disconnected = false
  globalThis.document = document
  globalThis.window = window
  globalThis.MutationObserver = class {
    constructor(callback) { observerCallback = callback }
    observe() {}
    disconnect() { disconnected = true }
  }
  globalThis.ResizeObserver = class {
    observe() {}
    disconnect() {}
  }

  try {
    const initialize = await loadHook("tooltip")
    const dispose = initialize()
    const control = new Element()
    control.dataset.tooltip = "Save changes"
    control.setAttribute("aria-describedby", "validation-help")
    const focus = event("focusin")
    Object.defineProperty(focus, "target", {value: control})
    document.dispatchEvent(focus)
    assert.equal(tip.hidden, false)
    assert.equal(tip.getAttribute("role"), "tooltip")
    assert.equal(control.getAttribute("aria-describedby"), "validation-help elixirbits-tooltip")
    control.dataset.tooltip = "Updated description"
    observerCallback([])
    assert.equal(tip.textContent, "Updated description")
    control.dataset.tooltip = ""
    observerCallback([])
    assert.equal(tip.hidden, true)
    control.dataset.tooltip = "Save changes"
    document.dispatchEvent(event("focusout"))
    document.dispatchEvent(focus)
    document.dispatchEvent(event("keydown", {key: "Escape"}))
    assert.equal(tip.hidden, true)
    assert.equal(control.getAttribute("aria-describedby"), "validation-help")

    document.dispatchEvent(event("focusout"))
    document.dispatchEvent(focus)
    control.isConnected = false
    observerCallback([])
    assert.equal(tip.hidden, true)

    const wrapper = new Element()
    wrapper.dataset.tooltip = "Use your work email"
    const input = new Element()
    input.closest = () => wrapper
    input.setAttribute("aria-describedby", "email-help")
    const fieldFocus = event("focusin")
    Object.defineProperty(fieldFocus, "target", {value: input})
    document.dispatchEvent(fieldFocus)
    assert.equal(wrapper.getAttribute("aria-describedby"), null)
    assert.equal(input.getAttribute("aria-describedby"), "email-help elixirbits-tooltip")

    input.setAttribute("aria-describedby", "updated-email-help")
    wrapper.dataset.tooltip = "Updated email description"
    observerCallback([])
    assert.equal(input.getAttribute("aria-describedby"), "updated-email-help elixirbits-tooltip")
    assert.equal(tip.textContent, "Updated email description")
    input.removeAttribute("aria-describedby")
    observerCallback([])
    assert.equal(input.getAttribute("aria-describedby"), "elixirbits-tooltip")
    document.dispatchEvent(event("keydown", {key: "Escape"}))
    input.isConnected = false
    observerCallback([])

    const native = new Element()
    native.setAttribute("title", "Open details")
    native.setAttribute("aria-describedby", "native-help")
    const nativeFocus = event("focusin")
    Object.defineProperty(nativeFocus, "target", {value: native})
    document.dispatchEvent(nativeFocus)
    assert.equal(tip.textContent, "Open details")
    assert.equal(native.getAttribute("title"), null)
    assert.equal(native.getAttribute("aria-label"), "Open details")
    native.setAttribute("title", "Close details")
    native.removeAttribute("aria-describedby")
    observerCallback([])
    assert.equal(tip.textContent, "Close details")
    assert.equal(native.getAttribute("title"), null)
    assert.equal(native.getAttribute("aria-label"), "Close details")
    assert.equal(native.getAttribute("aria-describedby"), "elixirbits-tooltip")

    dispose()
    assert.equal(disconnected, true)
    assert.equal(tip.isConnected, false)
    assert.equal(native.getAttribute("title"), "Close details")
    assert.equal(native.getAttribute("aria-label"), null)
    assert.equal(native.getAttribute("aria-describedby"), null)
    assert.equal(native.dataset.tooltip, undefined)
    document.dispatchEvent(focus)
    assert.equal(tip.hidden, true)
  } finally {
    globalThis.document = originalDocument
    globalThis.window = originalWindow
    globalThis.MutationObserver = originalObserver
    globalThis.ResizeObserver = originalResizeObserver
  }
})

test("clipped text tooltips follow rendered text, input values, patches, and element resizing", async () => {
  const originals = {
    document: globalThis.document,
    window: globalThis.window,
    MutationObserver: globalThis.MutationObserver,
    ResizeObserver: globalThis.ResizeObserver,
    getComputedStyle: globalThis.getComputedStyle,
  }
  const document = new EventTarget()
  const window = new EventTarget()
  const tip = new Element()
  document.createElement = () => tip
  document.body = new Element()
  document.body.appendChild = () => {}
  window.innerWidth = 500
  window.innerHeight = 500
  let mutationCallback
  let resizeCallback
  const observed = new Set()
  let resizeDisconnected = false
  globalThis.document = document
  globalThis.window = window
  globalThis.getComputedStyle = el => el.computedStyle
  globalThis.MutationObserver = class {
    constructor(callback) { mutationCallback = callback }
    observe() {}
    disconnect() {}
  }
  globalThis.ResizeObserver = class {
    constructor(callback) { resizeCallback = callback }
    observe(el) { observed.add(el) }
    disconnect() { observed.clear(); resizeDisconnected = true }
  }
  const dispatch = (name, target, values = {}) => {
    const next = event(name, values)
    Object.defineProperty(next, "target", {value: target})
    document.dispatchEvent(next)
  }

  try {
    const initialize = await loadHook("tooltip")
    const dispose = initialize()
    const navigation = new Element()
    navigation.textContent = "admin@elixirbits.dev"
    navigation.renderedText = "ADMIN@ELIXIRBITS.DEV"
    navigation.computedStyle.overflowX = "hidden"
    navigation.scrollWidth = 240
    navigation.setAttribute("aria-describedby", "account-help")
    dispatch("mousemove", navigation, {clientX: 30, clientY: 50})
    assert.equal(tip.hidden, false)
    assert.equal(tip.textContent, "ADMIN@ELIXIRBITS.DEV")
    assert.equal(navigation.getAttribute("aria-describedby"), "account-help elixirbits-tooltip")
    assert.equal(navigation.dataset.tooltip, undefined)
    assert.equal(navigation.getAttribute("title"), null)
    assert.equal(observed.has(navigation), true)

    navigation.clientWidth = 300
    resizeCallback()
    assert.equal(tip.hidden, true)
    assert.equal(navigation.getAttribute("aria-describedby"), "account-help")
    navigation.clientWidth = 80
    resizeCallback()
    assert.equal(tip.hidden, false)
    navigation.renderedText = "OTHER@ELIXIRBITS.DEV"
    mutationCallback([{target: navigation}])
    assert.equal(tip.textContent, "OTHER@ELIXIRBITS.DEV")
    navigation.computedStyle.overflowX = "visible"
    mutationCallback([{target: navigation}])
    assert.equal(tip.hidden, true)
    navigation.computedStyle.overflowX = "clip"
    mutationCallback([{target: navigation}])
    assert.equal(tip.hidden, false)
    document.dispatchEvent(event("keydown", {key: "Escape"}))
    resizeCallback()
    mutationCallback([{target: navigation}])
    assert.equal(tip.hidden, true)
    assert.equal(navigation.getAttribute("aria-describedby"), "account-help")
    document.dispatchEvent(event("mouseleave"))
    dispatch("mousemove", navigation, {clientX: 30, clientY: 50})
    assert.equal(tip.hidden, false)

    const button = new Element()
    const label = new Element()
    label.parentElement = button
    button.children = [label]
    label.textContent = "A long action label"
    label.computedStyle.overflowX = "hidden"
    label.scrollWidth = 200
    dispatch("focusin", button)
    assert.equal(tip.textContent, label.textContent)
    assert.equal(button.getAttribute("aria-describedby"), "elixirbits-tooltip")
    assert.equal(label.getAttribute("aria-describedby"), null)
    assert.equal(observed.has(label), true)
    document.dispatchEvent(event("focusout"))

    const input = new Element()
    input.tagName = "INPUT"
    input.type = "text"
    input.value = "long field value"
    input.computedStyle.overflowX = "hidden"
    input.computedStyle.textTransform = "uppercase"
    input.scrollWidth = 240
    dispatch("focusin", input)
    assert.equal(tip.textContent, "LONG FIELD VALUE")
    input.value = "patched value"
    dispatch("input", input)
    assert.equal(tip.textContent, "PATCHED VALUE")
    input.value = "changed value"
    dispatch("change", input)
    assert.equal(tip.textContent, "CHANGED VALUE")
    input.scrollWidth = input.clientWidth
    window.dispatchEvent(event("resize"))
    assert.equal(tip.hidden, true)
    input.scrollWidth = 240
    resizeCallback()
    assert.equal(tip.hidden, false)
    input.isConnected = false
    mutationCallback([{target: document.body}])
    assert.equal(tip.hidden, true)
    assert.equal(input.getAttribute("aria-describedby"), null)

    dispose()
    assert.equal(resizeDisconnected, true)
    assert.equal(observed.size, 0)
    dispatch("mousemove", navigation, {clientX: 30, clientY: 50})
    assert.equal(tip.hidden, true)
  } finally {
    Object.assign(globalThis, originals)
  }
})

test("automatic tooltips require actual clipping and preserve explicit descriptions", async () => {
  const originals = {
    document: globalThis.document,
    window: globalThis.window,
    MutationObserver: globalThis.MutationObserver,
    ResizeObserver: globalThis.ResizeObserver,
    getComputedStyle: globalThis.getComputedStyle,
  }
  const document = new EventTarget()
  const window = new EventTarget()
  const tip = new Element()
  document.createElement = () => tip
  document.body = new Element()
  document.body.appendChild = () => {}
  window.innerWidth = 500
  window.innerHeight = 500
  let mutationCallback
  globalThis.document = document
  globalThis.window = window
  globalThis.getComputedStyle = el => el.computedStyle
  globalThis.MutationObserver = class {
    constructor(callback) { mutationCallback = callback }
    observe() {}
    disconnect() {}
  }
  globalThis.ResizeObserver = class {
    observe() {}
    disconnect() {}
  }
  const hover = target => {
    const move = event("mousemove", {clientX: 30, clientY: 50})
    Object.defineProperty(move, "target", {value: target})
    document.dispatchEvent(move)
  }

  try {
    const initialize = await loadHook("tooltip")
    const dispose = initialize()
    const fitting = new Element()
    fitting.textContent = "Fits"
    fitting.computedStyle.overflowX = "hidden"
    hover(fitting)
    assert.equal(tip.hidden, true)
    fitting.scrollWidth = 240
    fitting.computedStyle.overflowX = "visible"
    hover(fitting)
    assert.equal(tip.hidden, true)
    fitting.computedStyle.overflowX = "hidden"
    fitting.computedStyle.overflowY = "auto"
    hover(fitting)
    assert.equal(tip.hidden, true)

    for (const type of ["password", "file"]) {
      const input = new Element()
      input.tagName = "INPUT"
      input.type = type
      input.value = "private field value"
      input.computedStyle.overflowX = "hidden"
      input.scrollWidth = 240
      hover(input)
      assert.equal(tip.hidden, true)
    }

    const clamped = new Element()
    clamped.textContent = "A longer paragraph extending past the last visible line."
    clamped.computedStyle.webkitLineClamp = "2"
    clamped.scrollHeight = 96
    hover(clamped)
    assert.equal(tip.textContent, clamped.textContent)
    assert.equal(tip.hidden, false)
    clamped.scrollHeight = clamped.clientHeight
    mutationCallback([{target: clamped}])
    assert.equal(tip.hidden, true)
    clamped.scrollHeight = 96
    clamped.dataset.tooltip = "A separate help description"
    hover(clamped)
    assert.equal(tip.textContent, "A separate help description")
    clamped.scrollHeight = clamped.clientHeight
    mutationCallback([{target: clamped}])
    assert.equal(tip.textContent, "A separate help description")
    assert.equal(tip.hidden, false)
    clamped.dataset.tooltip = ""
    mutationCallback([{target: clamped}])
    assert.equal(tip.hidden, true)

    const describedButton = new Element()
    const icon = new Element()
    icon.parentElement = describedButton
    describedButton.dataset.tooltip = "Open details"
    hover(icon)
    assert.equal(tip.textContent, "Open details")
    assert.equal(describedButton.getAttribute("aria-describedby"), "elixirbits-tooltip")
    assert.equal(icon.getAttribute("aria-describedby"), null)

    hover(tip)
    assert.equal(tip.hidden, true)
    dispose()
  } finally {
    Object.assign(globalThis, originals)
  }
})

test("ISO week input preserves year identity through boundaries and calendar navigation", async () => {
  const originalElement = globalThis.HTMLElement
  const originalDocument = globalThis.document
  const originalObserver = globalThis.MutationObserver
  const originalDependencies = globalThis.vcalendarTestDependencies
  class CalendarElement extends Element {
    matches(selector) { return selector === ":popover-open" ? this.open : super.matches(selector) }
    hidePopover() { this.open = false }
  }
  const weeks = {name: "weeks"}
  const contexts = []
  let popover
  globalThis.HTMLElement = CalendarElement
  globalThis.document = {getElementById: () => popover}
  globalThis.MutationObserver = class {
    constructor(callback) { this.callback = callback }
    observe() {}
    disconnect() { this.disconnected = true }
  }
  globalThis.vcalendarTestDependencies = {
    time: {name: "time"},
    weeks,
    Calendar: class {
      constructor(main, options) {
        this.options = options
        main.dataset.vc = "calendar"
        main.classList = {add() {}}
        main.querySelectorAll = () => main.weekButtons
        this.context = {mainElement: main}
      }
      init() { this.options.onInit(this) }
      destroy() { this.destroyed = true }
    },
  }

  try {
    const source = (await readFile(new URL("../js/vcalendar.js", import.meta.url), "utf8"))
      .replace('import {Calendar, time, weeks} from "vanilla-calendar-pro"',
        "const {Calendar, time, weeks} = globalThis.vcalendarTestDependencies")
    const hook = (await import(`data:text/javascript;base64,${Buffer.from(source).toString("base64")}`)).default
    const scenarios = [
      {value: "2020-W01", displayYear: 2019, displayMonth: 11, year: 2020, week: 1, neighborYear: 2019, neighborWeek: 52},
      {value: "2021-W01", displayYear: 2021, displayMonth: 0, year: 2021, week: 1, neighborYear: 2020, neighborWeek: 53},
      {value: "2020-W53", displayYear: 2020, displayMonth: 11, year: 2020, week: 53, neighborYear: 2021, neighborWeek: 1},
      {value: "2026-W01", displayYear: 2025, displayMonth: 11, year: 2026, week: 1, neighborYear: 2025, neighborWeek: 52},
      {value: "2021-W05", displayYear: 2021, displayMonth: 1, year: 2021, week: 5, neighborYear: 2021, neighborWeek: 4},
    ]

    for (const scenario of scenarios) {
      const input = new CalendarElement()
      input.dataset.vcMode = "week"
      input.value = scenario.value
      const selected = new CalendarElement()
      selected.dataset.vcWeekYear = String(scenario.year)
      selected.dataset.vcWeekNumber = String(scenario.week)
      selected.textContent = "Localized week label"
      const neighbor = new CalendarElement()
      neighbor.dataset.vcWeekYear = String(scenario.neighborYear)
      neighbor.dataset.vcWeekNumber = String(scenario.neighborWeek)
      popover = new CalendarElement()
      popover.dataset.vcTheme = "elixirbits"
      popover.setAttribute("aria-label", "Week")
      popover.weekButtons = [neighbor, selected]
      const context = {...hook, el: input}
      contexts.push(context)
      context.mounted()
      const calendar = context.calendar
      assert.equal(calendar.options.inputMode, false)
      assert.equal(calendar.options.selectedTheme, "elixirbits")
      assert.equal(calendar.options.labels.application, "Week")
      assert.equal(calendar.context.mainElement, popover)
      assert.deepEqual(calendar.options.extensions, [weeks])
      assert.equal(calendar.options.selectedYear, scenario.displayYear, scenario.value)
      assert.equal(calendar.options.selectedMonth, scenario.displayMonth, scenario.value)
      assert.equal(selected.getAttribute("data-vc-week-selected"), "", scenario.value)
      assert.equal(neighbor.getAttribute("data-vc-week-selected"), null, scenario.value)

      if (scenario.value === "2020-W01") {
        const otherYear = new CalendarElement()
        otherYear.dataset.vcWeekYear = "2021"
        otherYear.dataset.vcWeekNumber = "1"
        calendar.context.mainElement.weekButtons = [otherYear]
        calendar.options.onUpdate(calendar)
        context.weekObserver.callback()
        assert.equal(otherYear.getAttribute("data-vc-week-selected"), null)

        const changes = []
        for (const name of ["input", "change"]) input.addEventListener(name, event => changes.push(event.type))
        calendar.options.onClickWeekNumber(calendar, 1, 2021)
        assert.equal(input.value, "2021-W01")
        assert.equal(popover.open, false)
        assert.deepEqual(changes, ["input", "change"])
        assert.equal(otherYear.getAttribute("data-vc-week-selected"), "")

        calendar.context.mainElement.weekButtons = [selected]
        calendar.options.onUpdate(calendar)
        assert.equal(selected.getAttribute("data-vc-week-selected"), null)
        calendar.context.mainElement.weekButtons = [neighbor, otherYear]
        calendar.options.onClickWeekNumber(calendar, 52, 2019)
        assert.equal(input.value, "2019-W52")
        assert.equal(neighbor.getAttribute("data-vc-week-selected"), "")
        assert.equal(otherYear.getAttribute("data-vc-week-selected"), null)
      }

      context.destroyed()
      assert.equal(context.weekObserver.disconnected, true)
      assert.equal(calendar.destroyed, true)
    }
  } finally {
    for (const context of contexts) {
      if (context.calendar && !context.calendar.destroyed) context.destroyed()
    }
    globalThis.HTMLElement = originalElement
    globalThis.document = originalDocument
    globalThis.MutationObserver = originalObserver
    globalThis.vcalendarTestDependencies = originalDependencies
  }
})

test("calendar patches refresh native selections and preserve edits when server values are unchanged", async () => {
  const originalElement = globalThis.HTMLElement
  const originalDocument = globalThis.document
  const originalObserver = globalThis.MutationObserver
  const originalDependencies = globalThis.vcalendarTestDependencies
  class CalendarElement extends Element {
    constructor() {
      super()
      this.classList = {add() {}}
      this.querySelectorAll = () => this.controls ?? []
    }
    getClientRects() { return this.visible === false ? [] : [{}] }
    focus(options) { super.focus(); this.focusOptions = options }
    matches(selector) { return selector === ":popover-open" ? this.open : super.matches(selector) }
    showPopover(options) {
      this.dispatchEvent(event("beforetoggle", {newState: "open"}))
      this.open = true
      this.source = options.source
    }
    hidePopover() {
      this.dispatchEvent(event("beforetoggle", {newState: "closed"}))
      this.open = false
    }
  }
  const originalFocus = CalendarElement.prototype.focus
  const contexts = []
  let popover = new CalendarElement()
  popover.dataset.vcMode = "datetime-local"
  popover.setAttribute("aria-label", "Appointment")
  globalThis.HTMLElement = CalendarElement
  globalThis.document = {getElementById: () => popover}
  globalThis.MutationObserver = class {
    observe() {}
    disconnect() { this.disconnected = true }
  }
  globalThis.vcalendarTestDependencies = {
    time: {name: "time"},
    weeks: {name: "weeks"},
    Calendar: class {
      constructor(main, options) {
        this.options = options
        this.updates = []
        main.dataset.vc = "calendar"
        this.context = {mainElement: main, selectedDates: options.selectedDates, selectedTime: options.selectedTime}
      }
      init() { this.options.onInit(this) }
      set(options, reset) {
        this.updates.push({options, reset})
        Object.assign(this.options, options)
        Object.assign(this.context, options)
        this.options.onUpdate(this)
      }
      destroy() { this.destroyed = true }
    },
  }

  try {
    const source = (await readFile(new URL("../js/vcalendar.js", import.meta.url), "utf8"))
      .replace('import {Calendar, time, weeks} from "vanilla-calendar-pro"',
        "const {Calendar, time, weeks} = globalThis.vcalendarTestDependencies")
    const hook = (await import(`data:text/javascript;base64,${Buffer.from(source).toString("base64")}#patches`)).default
    const input = new CalendarElement()
    input.value = "2026-04-23T13:30:00"
    input.dataset = {
      vcMode: "datetime-local",
      vcValue: "2026-04-23T09:30:00",
      vcTimezone: "America/New_York",
      vcToday: "2026-04-23",
    }
    let changes = 0
    input.addEventListener("change", () => changes++)
    const context = {...hook, el: input}
    contexts.push(context)
    context.mounted()
    const calendar = context.calendar
    assert.equal(CalendarElement.prototype.focus, originalFocus)
    assert.equal(calendar.options.labels.application, "Appointment")
    assert.equal(input.value, "2026-04-23T09:30:00")
    assert.equal(input.getAttribute("value"), "2026-04-23T09:30:00")
    assert.deepEqual(calendar.options.selectedDates, ["2026-04-23"])
    assert.equal(calendar.options.selectedTime, "09:30")
    assert.equal(calendar.options.selectedYear, 2026)
    assert.equal(calendar.options.selectedMonth, 3)
    assert.equal(calendar.options.dateToday, "2026-04-23")

    input.value = "2026-04-24T10:45"
    context.updated()
    assert.equal(input.value, "2026-04-24T10:45")
    assert.equal(calendar.updates.length, 0)

    input.dataset.vcValue = "2026-04-24T10:45"
    context.updated()
    assert.equal(input.value, "2026-04-24T10:45")
    assert.deepEqual(calendar.updates.at(-1).options.selectedDates, ["2026-04-24"])
    assert.equal(calendar.updates.at(-1).options.selectedTime, "10:45")
    assert.equal(calendar.context.mainElement, popover)
    assert.equal(input.style.minWidth, undefined)

    input.dispatchEvent(event("click"))
    assert.equal(popover.open, true)
    assert.equal(popover.source, input)
    assert.equal(input.getAttribute("aria-expanded"), "true")
    assert.equal(calendar.context.mainElement.style.minWidth, undefined)
    assert.equal(calendar.context.mainElement.dataset.vcMode, "datetime-local")

    popover.hidePopover()
    const disabledControl = new CalendarElement()
    disabledControl.tabIndex = 0
    disabledControl.disabled = true
    const hiddenControl = new CalendarElement()
    hiddenControl.tabIndex = 0
    hiddenControl.visible = false
    const visibleControl = new CalendarElement()
    visibleControl.tabIndex = 0
    popover.controls = [disabledControl, hiddenControl, visibleControl]
    const enterCalendar = event("keydown", {key: "ArrowDown"})
    input.dispatchEvent(enterCalendar)
    assert.equal(popover.open, true)
    assert.equal(enterCalendar.defaultPrevented, true)
    assert.equal(visibleControl.focused, true)
    assert.deepEqual(visibleControl.focusOptions, {preventScroll: true})
    assert.equal(disabledControl.focused, undefined)
    assert.equal(hiddenControl.focused, undefined)
    const tab = event("keydown", {key: "Tab"})
    input.dispatchEvent(tab)
    assert.equal(tab.defaultPrevented, false)
    assert.equal(getEventListeners(input, "focus").length, 0)
    const escape = event("keydown", {key: "Escape"})
    input.dispatchEvent(escape)
    assert.equal(escape.defaultPrevented, false)
    popover.hidePopover()
    assert.equal(input.getAttribute("aria-expanded"), "false")
    input.dispatchEvent(event("click"))
    popover.controls = []

    input.disabled = true
    context.updated()
    assert.equal(popover.open, false)
    assert.equal(input.getAttribute("aria-expanded"), "false")
    calendar.options.onChangeTime(calendar)
    assert.equal(input.value, "2026-04-24T10:45")
    assert.equal(changes, 0)
    input.disabled = false
    calendar.options.onChangeTime(calendar)
    assert.equal(changes, 1)
    assert.equal(input.getAttribute("value"), "2026-04-24T10:45")

    input.dataset.vcTimezone = "Asia/Kuala_Lumpur"
    input.dataset.vcValue = "2026-04-24T22:45:00"
    context.updated()
    assert.equal(input.value, "2026-04-24T22:45:00")
    assert.equal(input.getAttribute("value"), "2026-04-24T22:45:00")
    assert.equal(calendar.updates.at(-1).options.selectedTime, "22:45")
    assert.equal(input.style.minWidth, undefined)
    assert.equal(calendar.context.mainElement.style.minWidth, undefined)

    input.value = "2026-04-25T11:15"
    input.dataset.vcToday = "2026-04-25"
    context.updated()
    assert.equal(input.value, "2026-04-25T11:15")
    assert.deepEqual(calendar.updates.at(-1), {
      options: {dateToday: "2026-04-25"},
      reset: {year: false, month: false, dates: false, time: false, locale: false},
    })

    input.dataset.vcValue = ""
    context.updated()
    assert.equal(input.value, "")
    assert.deepEqual(calendar.updates.at(-1).options.selectedDates, [])
    assert.equal(calendar.updates.at(-1).options.selectedTime, "00:00")
    input.dataset.vcValue = "invalid local value"
    context.updated()
    assert.equal(input.value, "invalid local value")
    assert.deepEqual(calendar.updates.at(-1).options.selectedDates, [])
    for (const invalid of ["2026-02-30T09:30", "2026-13-01T09:30", "2026-04-23T25:30"]) {
      input.dataset.vcValue = invalid
      context.updated()
      assert.equal(input.value, invalid)
      assert.deepEqual(calendar.updates.at(-1).options.selectedDates, [])
    }
    assert.equal(changes, 1)

    for (const scenario of [
      {mode: "date", initial: "2026-04-23", value: "2027-01-24", dates: ["2027-01-24"], year: 2027, month: 0},
      {mode: "time", initial: "09:30:25", value: "16:10:45", time: "16:10"},
      {mode: "week", initial: "2020-W01", value: "2020-W53", year: 2020, month: 11, week: 53},
      {mode: "month", initial: "2026-01", value: "2027-03", year: 2027, month: 2},
    ]) {
      const control = new CalendarElement()
      control.value = scenario.initial
      control.dataset = {vcMode: scenario.mode, vcValue: scenario.initial, vcTimezone: "Etc/UTC"}
      popover = new CalendarElement()
      popover.dataset.vcMode = scenario.mode
      popover.setAttribute("aria-label", "Calendar")
      const instance = {...hook, el: control}
      contexts.push(instance)
      instance.mounted()
      control.dataset.vcValue = scenario.value
      instance.updated()
      const update = instance.calendar.updates.at(-1).options
      assert.equal(control.value, scenario.value)
      assert.deepEqual(update.selectedDates, scenario.dates ?? [])
      if (scenario.time) assert.equal(update.selectedTime, scenario.time)
      if (scenario.year) assert.equal(update.selectedYear, scenario.year)
      if (scenario.month !== undefined) assert.equal(update.selectedMonth, scenario.month)
      if (scenario.week) assert.deepEqual(instance.selectedWeek, {year: scenario.year, week: scenario.week})
    }
    context.popover.showPopover({source: input})
    context.destroyed()
    assert.equal(context.popover.open, false)
    assert.equal(getEventListeners(input, "click").length, 0)
    assert.equal(getEventListeners(input, "keydown").length, 0)
    assert.equal(getEventListeners(context.popover, "beforetoggle").length, 0)
  } finally {
    for (const context of contexts) if (!context.calendar.destroyed) context.destroyed()
    globalThis.HTMLElement = originalElement
    globalThis.document = originalDocument
    globalThis.MutationObserver = originalObserver
    globalThis.vcalendarTestDependencies = originalDependencies
  }
})

async function withSelectDropdownHarness(run) {
  const names = ["document", "MutationObserver"]
  const originals = new Map(names.map(name => [name, Object.getOwnPropertyDescriptor(globalThis, name)]))
  const document = new EventTarget()
  const mutations = []
  const contexts = new Set()

  class SelectElement extends Element {
    constructor() {
      super()
      this.open = false
      this.promotions = []
    }
    get popover() { return this.getAttribute("popover") }
    set popover(value) { this.setAttribute("popover", value) }
    removeAttribute(name) {
      super.removeAttribute(name)
      if (name === "popover") this.open = false
    }
    matches(selector) { return selector === ":popover-open" && this.open }
    showPopover(options) { this.open = true; this.promotions.push(options) }
    hidePopover() { this.open = false }
  }

  Object.assign(globalThis, {
    document,
    MutationObserver: class {
      constructor(callback) { this.callback = callback; this.connected = false; mutations.push(this) }
      observe(target, options) { this.connected = true; this.target = target; this.options = options }
      disconnect() { this.connected = false }
    },
  })

  try {
    const hook = await loadHook("select_dropdown")
    const input = new SelectElement()
    const wrapper = new SelectElement()
    let dropdown = new SelectElement()
    input.parentElement = wrapper
    dropdown.parentElement = wrapper
    wrapper.querySelector = selector => ({"input[type=text]": input, "ul.select-dropdown": dropdown})[selector] ?? null
    document.activeElement = input
    const context = {...hook, el: wrapper}
    contexts.add(context)
    const destroy = () => { context.destroyed(); contexts.delete(context) }
    await run({
      context, input, wrapper, document, mutations, SelectElement, destroy,
      getDropdown: () => dropdown,
      replaceDropdown: replacement => { dropdown = replacement; if (replacement) replacement.parentElement = wrapper },
    })
  } finally {
    for (const context of contexts) context.destroyed()
    for (const [name, descriptor] of originals) {
      if (descriptor) Object.defineProperty(globalThis, name, descriptor)
      else delete globalThis[name]
    }
  }
}

test("select overlays preserve the input and native anchor across filtering and component patches", async () => {
  await withSelectDropdownHarness(async ({context, input, wrapper, document, mutations, SelectElement, getDropdown, replaceDropdown}) => {
    context.mounted()
    const first = getDropdown()
    assert.equal(first.popover, "manual")
    assert.equal(first.open, true)
    assert.deepEqual(first.promotions, [{source: input}])
    assert.equal(first.parentElement, wrapper)
    assert.equal(wrapper.querySelector("ul.select-dropdown"), first)
    assert.equal(document.activeElement, input)

    first.scrollTop = 90
    context.updated()
    assert.equal(first.promotions.length, 1)
    first.removeAttribute("popover")
    mutations[0].callback([{type: "attributes", attributeName: "popover"}])
    assert.equal(first.popover, "manual")
    assert.equal(first.open, true)
    assert.equal(first.scrollTop, 90)
    assert.equal(document.activeElement, input)

    replaceDropdown(null)
    mutations[0].callback([{type: "childList"}])
    assert.equal(mutations[0].connected, true)

    const replacement = new SelectElement()
    replaceDropdown(replacement)
    mutations[0].callback([{type: "childList"}])
    assert.equal(replacement.popover, "manual")
    assert.equal(replacement.open, true)
    assert.equal(replacement.parentElement, wrapper)
    assert.deepEqual(replacement.promotions, [{source: input}])
    assert.equal(document.activeElement, input)
  })
})

test("select overlay destruction closes the popover and releases its patch observer", async () => {
  await withSelectDropdownHarness(async ({context, mutations, destroy, getDropdown}) => {
    context.mounted()
    const dropdown = getDropdown()
    assert.equal(mutations[0].connected, true)
    destroy()
    assert.equal(dropdown.open, false)
    assert.equal(mutations[0].connected, false)
  })
})

test("telephone composition follows country and number edits while LiveSelect owns its label", async () => {
  const hook = await loadHook("tel_input")
  const wrapper = new Element()
  wrapper.dataset.countries = JSON.stringify({MY: "+60", US: "+1"})
  wrapper.dataset.countryName = "form[phone_country_code]"
  const country = new Element()
  country.name = wrapper.dataset.countryName
  country.value = "MY"
  const composite = new Element()
  composite.value = "+60123456789"
  let number = new Element()
  number.setAttribute("data-tel-number", "")
  number.hasAttribute = name => number.getAttribute(name) !== null
  number.value = "123456789"
  const label = new Element()
  label.name = "form[phone_country_code_text_input]"
  label.value = "+60"
  label.hasAttribute = name => label.getAttribute(name) !== null
  wrapper.querySelector = selector => selector.startsWith("input[name=") ? country : ({"[data-tel-number]": number, "[data-tel-composite]": composite})[selector] ?? null
  const context = {...hook, el: wrapper}
  const emit = (type, target) => wrapper.dispatchEvent(Object.defineProperty(event(type), "target", {value: target}))

  context.mounted()
  try {
    assert.equal(label.value, "+60")
    number.value = " 987654321 "
    emit("input", number)
    assert.equal(composite.value, "+60987654321")
    country.value = "us"
    emit("input", country)
    assert.equal(composite.value, "+1987654321")
    label.value = "Canada"
    emit("input", label)
    assert.equal(label.value, "Canada")
    assert.equal(composite.value, "+1987654321")

    number = new Element()
    number.setAttribute("data-tel-number", "")
    number.hasAttribute = name => number.getAttribute(name) !== null
    number.value = "5551234"
    emit("change", number)
    assert.equal(composite.value, "+15551234")
    country.value = ""
    emit("input", country)
    assert.equal(composite.value, "5551234")
    number.value = ""
    emit("input", number)
    assert.equal(composite.value, "")
  } finally {
    context.destroyed()
  }
  assert.equal(getEventListeners(wrapper, "input").length, 0)
  assert.equal(getEventListeners(wrapper, "change").length, 0)
  country.value = "MY"
  emit("input", country)
  assert.equal(composite.value, "")
})

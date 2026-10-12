import test from "node:test"
import assert from "node:assert/strict"
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
  }
  setAttribute(name, value) { this.attributes.set(name, String(value)) }
  getAttribute(name) { return this.attributes.get(name) ?? null }
  removeAttribute(name) { this.attributes.delete(name) }
  closest() { return this }
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
  context.updated()
  assert.equal(button.disabled, true)
  button.dispatchEvent(event("click"))
  assert.equal(input.type, "password")
  assert.equal(button.getAttribute("aria-pressed"), "false")
  input.disabled = false
  context.updated()
  assert.equal(button.disabled, false)
  button.dispatchEvent(event("click"))
  assert.equal(input.type, "text")
  context.destroyed()
  button.dispatchEvent(event("click"))
  assert.equal(input.type, "text")
})

test("timers recompute absolute time after suspension and share a cleaned loop", async () => {
  const originalNow = Date.now
  const originalFrame = globalThis.requestAnimationFrame
  const originalCancel = globalThis.cancelAnimationFrame
  let now = Date.parse("2026-10-09T00:00:00Z")
  let frames = new Map()
  let sequence = 0
  Date.now = () => now
  globalThis.requestAnimationFrame = callback => { frames.set(++sequence, callback); return sequence }
  globalThis.cancelAnimationFrame = id => frames.delete(id)

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
    assert.equal(frames.size, 1)
    assert.equal(countdown.textContent, "in 1:00")

    now += 125_000
    const [[id, callback]] = frames
    frames.delete(id)
    callback(performance.now() + 125_000)
    assert.equal(elapsed.textContent, "2:05")
    assert.equal(countdown.textContent, "+1:05")
    assert.equal(countdown.getAttribute("data-overdue"), "")
    countdown.dataset.mode = "elapsed"
    second.updated()
    assert.equal(countdown.textContent, "1:05")
    assert.equal(countdown.getAttribute("data-overdue"), null)
    first.destroyed()
    second.destroyed()
    assert.equal(frames.size, 0)
  } finally {
    Date.now = originalNow
    globalThis.requestAnimationFrame = originalFrame
    globalThis.cancelAnimationFrame = originalCancel
  }
})

test("delegated tooltip describes focused controls across patches and restores native titles", async () => {
  const originalDocument = globalThis.document
  const originalWindow = globalThis.window
  const originalObserver = globalThis.MutationObserver
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
    observerCallback()
    assert.equal(tip.textContent, "Updated description")
    control.dataset.tooltip = ""
    observerCallback()
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
    observerCallback()
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
    observerCallback()
    assert.equal(input.getAttribute("aria-describedby"), "updated-email-help elixirbits-tooltip")
    assert.equal(tip.textContent, "Updated email description")
    input.removeAttribute("aria-describedby")
    observerCallback()
    assert.equal(input.getAttribute("aria-describedby"), "elixirbits-tooltip")
    document.dispatchEvent(event("keydown", {key: "Escape"}))
    input.isConnected = false
    observerCallback()

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
    observerCallback()
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
  }
})

test("ISO week input preserves year identity through boundaries and calendar navigation", async () => {
  const originalElement = globalThis.HTMLElement
  const originalObserver = globalThis.MutationObserver
  const originalDependencies = globalThis.vcalendarTestDependencies
  class CalendarElement extends Element {}
  const weeks = {name: "weeks"}
  const contexts = []
  globalThis.HTMLElement = CalendarElement
  globalThis.MutationObserver = class {
    constructor(callback) { this.callback = callback }
    observe() {}
    disconnect() { this.disconnected = true }
  }
  globalThis.vcalendarTestDependencies = {
    time: {name: "time"},
    weeks,
    Calendar: class {
      constructor(input, options) {
        this.options = options
        const main = new CalendarElement()
        main.dataset.vc = "calendar"
        main.classList = {add() {}}
        main.weekButtons = input.weekButtons
        main.querySelectorAll = () => main.weekButtons
        this.context = {mainElement: main}
      }
      init() { this.options.onInit(this) }
      hide() { this.hidden = true }
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
      input.weekButtons = [neighbor, selected]
      const context = {...hook, el: input}
      contexts.push(context)
      context.mounted()
      const calendar = context.calendar
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
        calendar.options.onShow(calendar)
        context.weekObserver.callback()
        assert.equal(otherYear.getAttribute("data-vc-week-selected"), null)

        const changes = []
        for (const name of ["input", "change"]) input.addEventListener(name, event => changes.push(event.type))
        calendar.options.onClickWeekNumber(calendar, 1, 2021)
        assert.equal(input.value, "2021-W01")
        assert.equal(calendar.hidden, true)
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
    globalThis.MutationObserver = originalObserver
    globalThis.vcalendarTestDependencies = originalDependencies
  }
})

test("calendar patches refresh native selections and preserve edits when server values are unchanged", async () => {
  const originalElement = globalThis.HTMLElement
  const originalObserver = globalThis.MutationObserver
  const originalDependencies = globalThis.vcalendarTestDependencies
  class CalendarElement extends Element {
    constructor() {
      super()
      this.classList = {add() {}}
      this.querySelectorAll = () => []
    }
  }
  const contexts = []
  globalThis.HTMLElement = CalendarElement
  globalThis.MutationObserver = class {
    observe() {}
    disconnect() { this.disconnected = true }
  }
  globalThis.vcalendarTestDependencies = {
    time: {name: "time"},
    weeks: {name: "weeks"},
    Calendar: class {
      constructor(input, options) {
        this.options = options
        this.updates = []
        this.context = {mainElement: input, selectedDates: options.selectedDates, selectedTime: options.selectedTime}
      }
      init() {}
      show() {
        const main = new CalendarElement()
        main.dataset.vc = "calendar"
        main.classList = {add() {}}
        main.querySelectorAll = () => []
        this.context.mainElement = main
        this.options.onInit(this)
        this.options.onShow(this)
      }
      set(options, reset) {
        this.updates.push({options, reset})
        Object.assign(this.options, options)
        Object.assign(this.context, options)
        this.options.onUpdate(this)
      }
      hide() { this.hidden = true }
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
    assert.equal(calendar.context.mainElement, input)
    assert.equal(input.style.minWidth, undefined)

    calendar.show()
    assert.equal(calendar.context.mainElement.style.minWidth, "280px")
    assert.equal(calendar.context.mainElement.getAttribute("data-vc-mode"), "datetime-local")

    input.disabled = true
    context.updated()
    assert.equal(calendar.hidden, true)
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
    assert.equal(calendar.context.mainElement.style.minWidth, "280px")

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
  } finally {
    for (const context of contexts) context.destroyed()
    globalThis.HTMLElement = originalElement
    globalThis.MutationObserver = originalObserver
    globalThis.vcalendarTestDependencies = originalDependencies
  }
})

async function withSelectDropdownHarness(run) {
  const names = ["document", "window", "MutationObserver", "ResizeObserver", "requestAnimationFrame", "cancelAnimationFrame", "getComputedStyle"]
  const originals = new Map(names.map(name => [name, Object.getOwnPropertyDescriptor(globalThis, name)]))
  const document = new EventTarget()
  const window = new EventTarget()
  document.documentElement = {computedStyle: {fontSize: "16px"}, style: {}}
  window.innerWidth = 500
  window.innerHeight = 500
  const frames = new Map()
  const mutations = []
  const resizes = []
  const contexts = new Set()
  let sequence = 0

  class SelectElement extends Element {
    constructor() {
      super()
      this.bounds = {left: 20, top: 100, bottom: 144, width: 280}
      this.computedStyle = {maxHeight: "240px", borderTopWidth: "1px", borderBottomWidth: "1px"}
      this.scrollHeight = 350
      this.descendants = new Set()
      this.open = false
      this.promotions = []
    }
    get popover() { return this.getAttribute("popover") }
    set popover(value) { this.setAttribute("popover", value) }
    removeAttribute(name) {
      super.removeAttribute(name)
      if (name === "popover") this.open = false
    }
    getBoundingClientRect() { return this.bounds }
    contains(target) { return target === this || this.descendants.has(target) }
    matches(selector) { return selector === ":popover-open" && this.open }
    showPopover(options) { this.open = true; this.promotions.push(options) }
    hidePopover() { this.open = false }
  }

  class Observer {
    constructor(callback) {
      this.callback = callback
      this.connected = false
      this.targets = new Set()
    }
    observe(target) { this.connected = true; this.targets.add(target) }
    disconnect() { this.connected = false; this.targets.clear() }
  }

  Object.assign(globalThis, {
    document,
    window,
    MutationObserver: class extends Observer {
      constructor(callback) { super(callback); mutations.push(this) }
    },
    ResizeObserver: class extends Observer {
      constructor(callback) { super(callback); resizes.push(this) }
    },
    requestAnimationFrame: callback => { frames.set(++sequence, callback); return sequence },
    cancelAnimationFrame: id => frames.delete(id),
    getComputedStyle: element => ({...element.computedStyle, maxHeight: element.style.maxHeight || element.computedStyle.maxHeight}),
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
    const flush = () => {
      for (const [id, callback] of [...frames]) {
        frames.delete(id)
        callback()
      }
    }
    const destroy = () => { context.destroyed(); contexts.delete(context) }
    await run({
      context, input, wrapper, document, window, frames, mutations, resizes, SelectElement, flush, destroy,
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

test("select overlays preserve the input and list across filtering and component patches", async () => {
  await withSelectDropdownHarness(async ({context, input, wrapper, document, mutations, frames, SelectElement, flush, getDropdown, replaceDropdown}) => {
    context.mounted()
    const first = getDropdown()
    assert.equal(first.popover, "manual")
    assert.equal(first.open, true)
    assert.deepEqual(first.promotions, [{source: input}])
    assert.equal(first.parentElement, wrapper)
    assert.equal(wrapper.querySelector("ul.select-dropdown"), first)
    assert.equal(document.activeElement, input)

    first.scrollTop = 90
    first.removeAttribute("popover")
    first.style = {}
    context.updated()
    assert.equal(first.popover, "manual")
    assert.equal(first.open, true)
    assert.equal(first.scrollTop, 90)
    assert.equal(first.style.width, "280px")
    assert.equal(document.activeElement, input)

    replaceDropdown(null)
    mutations[0].callback([{type: "childList"}])
    flush()
    assert.equal(frames.size, 0)
    assert.equal(mutations[0].connected, true)

    const replacement = new SelectElement()
    replacement.scrollHeight = 80
    replaceDropdown(replacement)
    mutations[0].callback([{type: "childList"}])
    flush()
    assert.equal(replacement.popover, "manual")
    assert.equal(replacement.open, true)
    assert.equal(replacement.parentElement, wrapper)
    assert.deepEqual(replacement.promotions, [{source: input}])
    assert.equal(replacement.style.top, "148px")
    assert.equal(document.activeElement, input)
  })
})

test("select overlays flip above the control and fit the available viewport", async () => {
  await withSelectDropdownHarness(async ({context, input, wrapper, window, getDropdown}) => {
    context.mounted()
    const dropdown = getDropdown()
    assert.equal(dropdown.style.top, "148px")
    assert.equal(dropdown.style.maxHeight, "240px")

    input.bounds = {left: 450, top: 420, bottom: 464, width: 280}
    context.updated()
    assert.equal(dropdown.style.left, "212px")
    assert.equal(dropdown.style.top, "176px")
    assert.equal(dropdown.style.maxHeight, "240px")

    input.bounds = {left: 20, top: 100, bottom: 144, width: 64}
    wrapper.dataset.dropdownMinWidth = "18"
    context.updated()
    assert.equal(dropdown.style.width, "288px")

    window.innerWidth = 240
    window.innerHeight = 220
    context.updated()
    assert.equal(dropdown.style.width, "224px")
    assert.equal(dropdown.style.left, "8px")
    assert.equal(dropdown.style.top, "8px")
    assert.equal(dropdown.style.maxHeight, "88px")
  })
})

test("select overlays track surrounding movement and release all lifecycle resources", async () => {
  await withSelectDropdownHarness(async ({context, input, document, window, frames, mutations, resizes, SelectElement, flush, destroy, getDropdown}) => {
    context.mounted()
    const dropdown = getDropdown()
    const option = new SelectElement()
    dropdown.descendants.add(option)
    const popupScroll = event("scroll")
    Object.defineProperty(popupScroll, "target", {value: option})
    document.dispatchEvent(popupScroll)
    assert.equal(frames.size, 0)

    input.bounds = {left: 30, top: 200, bottom: 244, width: 280}
    document.dispatchEvent(event("scroll"))
    window.dispatchEvent(event("resize"))
    resizes[0].callback([])
    assert.equal(frames.size, 1)
    flush()
    assert.equal(dropdown.style.left, "30px")
    assert.equal(dropdown.style.top, "248px")

    mutations[0].callback([{type: "attributes"}])
    assert.equal(frames.size, 1)
    destroy()
    assert.equal(frames.size, 0)
    assert.equal(dropdown.open, false)
    assert.equal(mutations[0].connected, false)
    assert.equal(resizes[0].connected, false)
    document.dispatchEvent(event("scroll"))
    window.dispatchEvent(event("resize"))
    assert.equal(frames.size, 0)
  })
})

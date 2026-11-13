import test from "node:test"
import assert from "node:assert/strict"
import {getEventListeners} from "node:events"
import {readFile} from "node:fs/promises"

const nativeSource = await readFile(new URL("../../deps/petal_components/assets/js/petal_components.js", import.meta.url), "utf8")
const nativeUrl = `data:text/javascript;base64,${Buffer.from(nativeSource).toString("base64")}`
const source = (await readFile(new URL("../js/combo_box.js", import.meta.url), "utf8"))
  .replace('"../../deps/petal_components/assets/js/petal_components"', JSON.stringify(nativeUrl))
const ComboBox = (await import(`data:text/javascript;base64,${Buffer.from(source).toString("base64")}`)).default
const controlsSource = await readFile(new URL("../js/input_controls.js", import.meta.url), "utf8")
const initInputControls = (await import(`data:text/javascript;base64,${Buffer.from(controlsSource).toString("base64")}`)).default
const originalGlobals = Object.fromEntries(["window", "document", "getComputedStyle", "MutationObserver"].map(name => [name, globalThis[name]]))
const fixtures = new Set()
let sequence = 0

class Element extends EventTarget {
  constructor(tagName = "div") {
    super()
    this.tagName = tagName.toUpperCase()
    this.attributes = new Map()
    this.childNodes = []
    this.parentElement = null
    this.content = ""
    this.inputValue = ""
    this.height = 36
    this.scrollTop = 0
    this.style = {}
    let maxHeight = ""
    Object.defineProperty(this.style, "maxHeight", {
      get: () => maxHeight,
      set: value => { maxHeight = value; if (value === "none" && this.layoutList) this.scrollTop = 0 },
    })
    this.dataset = new Proxy({}, {
      get: (_target, key) => this.getAttribute(`data-${key.replace(/[A-Z]/g, letter => `-${letter.toLowerCase()}`)}`) ?? undefined,
      set: (_target, key, value) => { this.setAttribute(`data-${key.replace(/[A-Z]/g, letter => `-${letter.toLowerCase()}`)}`, value); return true },
      deleteProperty: (_target, key) => { this.removeAttribute(`data-${key.replace(/[A-Z]/g, letter => `-${letter.toLowerCase()}`)}`); return true },
    })
    this.classList = {
      contains: value => this.className.split(/\s+/).includes(value),
      remove: value => { this.className = this.className.split(/\s+/).filter(item => item !== value).join(" ") },
      add: value => { if (!this.classList.contains(value)) this.className = `${this.className} ${value}`.trim() },
    }
  }
  get children() { return this.childNodes.filter(child => child instanceof Element) }
  get firstElementChild() { return this.children[0] ?? null }
  get textContent() { return this.content + this.childNodes.map(child => typeof child === "string" ? child : child.textContent).join("") }
  set textContent(value) { this.replaceChildren(); this.content = String(value) }
  get value() {
    if (this.tagName === "SELECT") return this.selectedOptions[0]?.value ?? ""
    if (this.tagName === "OPTION") return this.getAttribute("value") ?? this.textContent
    return this.inputValue
  }
  set value(value) {
    if (this.tagName === "SELECT") for (const option of this.options) option.selected = option.value === String(value)
    else if (this.tagName === "OPTION") this.setAttribute("value", value)
    else this.inputValue = String(value)
  }
  get options() { return this.querySelectorAll("option") }
  get selectedOptions() { return this.options.filter(option => option.selected) }
  get selected() { return this.selectedState ?? this.hasAttribute("selected") }
  set selected(value) { this.selectedState = !!value }
  get hidden() { return this.hasAttribute("hidden") }
  set hidden(value) { this.toggleAttribute("hidden", value) }
  get disabled() { return this.hasAttribute("disabled") }
  set disabled(value) { this.toggleAttribute("disabled", value) }
  setAttribute(name, value) { this.attributes.set(name, String(value)) }
  getAttribute(name) { return this.attributes.get(name) ?? null }
  hasAttribute(name) { return this.attributes.has(name) }
  removeAttribute(name) { this.attributes.delete(name) }
  toggleAttribute(name, force = !this.hasAttribute(name)) {
    if (force) this.setAttribute(name, "")
    else this.removeAttribute(name)
    return force
  }
  matches(selector) {
    if (selector === ":disabled") {
      if (this.disabled) return true
      for (let parent = this.parentElement; parent; parent = parent.parentElement) if (parent.tagName === "FIELDSET" && parent.disabled) return true
      return false
    }
    if (selector.includes(",")) return selector.split(",").some(part => this.matches(part.trim()))
    const tag = selector.match(/^[a-z]+/i)?.[0]
    if (tag && this.tagName !== tag.toUpperCase()) return false
    for (const [, name] of selector.matchAll(/\.([\w-]+)/g)) if (!this.classList.contains(name)) return false
    for (const [, name, value] of selector.matchAll(/\[([^=\]]+)(?:=["']?([^\]"']+)["']?)?\]/g)) {
      if (!this.hasAttribute(name) || (value !== undefined && this.getAttribute(name) !== value)) return false
    }
    return true
  }
  querySelectorAll(selector) {
    const parts = selector.split(" > ")
    return this.children.flatMap(child => [child, ...child.querySelectorAll("*")]).filter(child =>
      parts.length === 2 ? child.matches(parts[1]) && child.parentElement?.matches(parts[0]) : child.matches(selector)
    )
  }
  querySelector(selector) { return this.querySelectorAll(selector)[0] ?? null }
  closest(selector) {
    for (let element = this; element; element = element.parentElement) if (element.matches(selector)) return element
    return null
  }
  contains(node) {
    for (let element = node; element; element = element.parentElement) if (element === this) return true
    return false
  }
  append(...children) {
    for (const child of children) {
      if (typeof child !== "string") { child.remove(); child.parentElement = this }
      this.childNodes.push(child)
    }
  }
  appendChild(child) { this.append(child); return child }
  prepend(child) { child.remove(); child.parentElement = this; this.childNodes.unshift(child) }
  remove() {
    if (this.parentElement) this.parentElement.childNodes.splice(this.parentElement.childNodes.indexOf(this), 1)
    this.parentElement = null
  }
  replaceChildren(...children) {
    for (const child of this.children) child.remove()
    this.childNodes = []
    this.content = ""
    this.append(...children)
  }
  focus() { document.activeElement = this }
  scrollIntoView(options = {}) {
    this.scrolledIntoView = true
    const list = this.closest(".pc-combo-box__list")
    if (!list) return
    let item = this.getBoundingClientRect()
    const bounds = list.getBoundingClientRect()
    if (item.top < bounds.top) list.scrollTop += item.top - bounds.top
    else if (item.bottom > bounds.bottom) list.scrollTop += item.bottom - bounds.bottom
    if (options.container === "nearest") return
    item = this.getBoundingClientRect()
    const top = browser.visualViewport.offsetTop
    const bottom = top + browser.visualViewport.height
    const delta = item.top < top ? item.top - top : item.bottom > bottom ? item.bottom - bottom : 0
    browser.scrollY += delta
    const anchor = list.parentElement.layoutAnchor
    anchor.rect = {top: anchor.rect.top - delta, bottom: anchor.rect.bottom - delta}
  }
  dispatchEvent(event) {
    if (!event.target) Object.defineProperty(event, "target", {value: this})
    const result = super.dispatchEvent(event)
    if (event.bubbles && !event.cancelBubble) this.parentElement?.dispatchEvent(event)
    return result
  }
  get offsetHeight() {
    if (this.hidden) return 0
    if (this.layoutList) {
      const limit = parseFloat(this.style.maxHeight)
      return this.style.maxHeight === "none" ? this.scrollHeight : Math.min(this.scrollHeight, Number.isFinite(limit) ? limit : 252)
    }
    if (this.layoutPanel) return 46 + (this.empty.hidden ? 0 : 36) + this.layoutPanel.offsetHeight
    return this.height
  }
  get scrollHeight() { return this.children.reduce((total, child) => total + (child.hidden ? 0 : child.height), 0) }
  getBoundingClientRect() {
    if (this.rect) return this.rect
    if (this.layoutPanel) {
      const anchor = this.layoutAnchor.getBoundingClientRect()
      const top = this.hasAttribute("data-flip") ? anchor.top - 4 - this.offsetHeight : anchor.bottom + 4
      return {top, bottom: top + this.offsetHeight, height: this.offsetHeight}
    }
    if (this.layoutList) {
      const top = this.parentElement.getBoundingClientRect().top + 46
      return {top, bottom: top + this.offsetHeight, height: this.offsetHeight}
    }
    if (this.parentElement?.layoutList) {
      const index = this.parentElement.children.indexOf(this)
      const preceding = this.parentElement.children.slice(0, index).reduce((total, child) => total + (child.hidden ? 0 : child.height), 0)
      const top = this.parentElement.getBoundingClientRect().top + preceding - this.parentElement.scrollTop
      return {top, bottom: top + this.offsetHeight, height: this.offsetHeight}
    }
    return {top: 100, bottom: 144, height: this.offsetHeight}
  }
}

for (const name of ["id", "className"]) {
  const attribute = name === "className" ? "class" : name
  Object.defineProperty(Element.prototype, name, {get() { return this.getAttribute(attribute) ?? "" }, set(value) { this.setAttribute(attribute, value) }})
}

const browser = new EventTarget()
browser.innerHeight = 800
browser.scrollY = 0
browser.visualViewport = new EventTarget()
browser.visualViewport.offsetTop = 0
browser.visualViewport.height = 800
globalThis.window = browser
globalThis.document = new EventTarget()
document.body = new Element("body")
document.documentElement = document.body
document.activeElement = document.body
document.createElement = name => new Element(name)
document.querySelectorAll = selector => document.body.querySelectorAll(selector)
document.getElementById = id => document.body.querySelectorAll("*").find(element => element.id === id) ?? null
globalThis.getComputedStyle = () => ({marginTop: "4px"})
delete globalThis.MutationObserver

test.afterEach(() => {
  for (const fixture of fixtures) {
    fixture.context.destroyed()
    fixture.container.remove()
  }
  fixtures.clear()
  browser.visualViewport.offsetTop = 0
  browser.visualViewport.height = browser.innerHeight = 800
  browser.scrollY = 0
  document.activeElement = document.body
})
test.after(() => {
  for (const [name, value] of Object.entries(originalGlobals)) {
    if (value === undefined) delete globalThis[name]
    else globalThis[name] = value
  }
})

function picker({custom = false, multiple = false, externalClear = false, value = null, options = Array.from({length: 20}, (_, index) => [`Choice ${index + 1}`, String(index + 1)]), core = true} = {}) {
  const root = new Element()
  root.id = `picker-${++sequence}`
  root.className = `pc-combo-box${core ? " core-selection-input" : ""}`
  if (custom) root.setAttribute("data-free-text", "true")
  const select = new Element("select")
  select.className = "pc-combo-box__select"
  select.multiple = multiple
  select.form = null
  const blank = new Element("option")
  blank.value = ""
  blank.selected = true
  if (!multiple) select.append(blank)
  const trigger = new Element("button")
  trigger.setAttribute("data-pc-combo-trigger", "")
  trigger.rect = {top: 100, bottom: 144}
  const label = new Element("span")
  label.setAttribute("data-pc-combo-trigger-label", "")
  label.dataset.placeholderText = "Choose"
  trigger.append(label)
  const clear = new Element("button")
  clear.setAttribute(externalClear ? "data-input-clear" : "data-pc-combo-clear", "")
  const panel = new Element()
  panel.setAttribute("data-pc-combo-panel", "")
  panel.hidden = true
  const input = new Element("input")
  input.className = "pc-combo-box__input"
  const list = new Element()
  list.className = "pc-combo-box__list"
  list.layoutList = true
  panel.layoutPanel = list
  panel.layoutAnchor = trigger
  const empty = new Element()
  empty.setAttribute("data-pc-combo-empty", "")
  empty.hidden = true
  panel.empty = empty
  panel.append(input, list, empty)
  const rows = []
  for (const [text, value, metadata = {}] of options) {
    const option = new Element("option")
    option.value = value
    option.textContent = text
    option.disabled = !!metadata.disabled
    select.append(option)
    const row = new Element()
    row.setAttribute("data-pc-combo-item", "")
    row.dataset.label = text
    row.dataset.value = value
    if (metadata.disabled) {
      row.setAttribute("data-disabled", "true")
      row.setAttribute("aria-disabled", "true")
    }
    row.textContent = text
    list.append(row)
    rows.push(row)
  }
  if (value !== null) select.value = value
  let create
  if (custom) {
    create = new Element()
    create.setAttribute("data-pc-combo-create", "")
    create.hidden = true
    const query = new Element("span")
    query.setAttribute("data-pc-combo-create-query", "")
    const text = new Element("span")
    text.append('Create "', query, '"')
    create.append(text)
    list.append(create)
  }
  root.append(select, trigger, panel)
  const container = core ? new Element() : root
  if (core) {
    container.setAttribute("data-core-input", "")
    container.dataset.inputType = "combobox"
    container.dataset.inputClearable = "true"
    container.append(root)
  }
  if (externalClear) container.append(clear)
  else root.append(clear)
  document.body.append(container)
  const events = []
  select.addEventListener("input", () => events.push(["input", select.value]))
  select.addEventListener("change", () => events.push(["change", select.value]))
  const context = {...ComboBox, el: root}
  context.mounted()
  const fixture = {
    root, container, select, trigger, label, clear, panel, input, list, rows, create, empty, events, context,
    search(query) { input.value = query; input.dispatchEvent(new Event("input", {bubbles: true})) },
    key(key) { input.dispatchEvent(Object.assign(new Event("keydown", {cancelable: true}), {key})) },
  }
  fixtures.add(fixture)
  return fixture
}

test("opens below with seven complete options and shrinks to one before flipping", () => {
  const field = picker()
  field.context.openPanel()
  assert.equal(field.list.style.maxHeight, "252px")
  for (let rows = 7; rows >= 1; rows--) {
    const below = 46 + rows * 36 + 17
    field.trigger.rect = {top: 800 - below - 48, bottom: 800 - below - 4}
    browser.dispatchEvent(new Event("scroll"))
    assert.equal(field.panel.hasAttribute("data-flip"), false, `${rows} rows stay below`)
    assert.equal(field.list.style.maxHeight, `${rows * 36}px`)
  }
  field.trigger.rect = {top: 671, bottom: 715}
  browser.dispatchEvent(new Event("scroll"))
  assert.equal(field.panel.hasAttribute("data-flip"), true)
  assert.equal(field.list.style.maxHeight, "252px")
  field.trigger.rect = {top: 100, bottom: 144}
  browser.dispatchEvent(new Event("scroll"))
  assert.equal(field.panel.hasAttribute("data-flip"), false)
})

test("measures wrapped rows and list headings instead of assuming a fixed row height", () => {
  const field = picker()
  field.rows[0].height = 48
  field.rows[1].height = 60
  const heading = new Element()
  heading.height = 24
  field.list.prepend(heading)
  field.trigger.rect = {top: 568, bottom: 612}
  field.context.openPanel()
  assert.equal(field.panel.hasAttribute("data-flip"), false)
  assert.equal(field.list.style.maxHeight, "132px")
})

test("tracks the visual viewport and preserves list scrolling while resizing", () => {
  const field = picker()
  field.context.openPanel()
  field.list.scrollTop = 144
  browser.visualViewport.offsetTop = 50
  browser.visualViewport.height = 300
  browser.visualViewport.dispatchEvent(new Event("resize"))
  assert.equal(field.panel.hasAttribute("data-flip"), false)
  assert.equal(field.list.style.maxHeight, "144px")
  assert.equal(field.list.scrollTop, 144)
  browser.visualViewport.height = 100
  browser.visualViewport.dispatchEvent(new Event("scroll"))
  assert.equal(field.panel.hasAttribute("data-flip"), true)
  assert.equal(field.list.style.maxHeight, "0px")
})

test("opening a long preselected list and navigating it scrolls options without moving the page", () => {
  const options = Array.from({length: 150}, (_, index) => [index === 120 ? "Malaysia" : `Country ${index + 1}`, String(index + 1)])
  const field = picker({value: "121", options})
  field.trigger.rect = {top: 650, bottom: 694}
  browser.scrollY = 935
  field.trigger.dispatchEvent(new Event("click"))
  assert.equal(browser.scrollY, 935)
  assert.deepEqual(field.trigger.rect, {top: 650, bottom: 694})
  assert.equal(field.list.style.maxHeight, "36px")
  assert.equal(field.context.highlightedItem(), field.rows[120])
  assert.ok(field.list.scrollTop > 0)
  assert.equal(field.rows[120].getBoundingClientRect().bottom, field.list.getBoundingClientRect().bottom)
  assert.equal(document.activeElement, field.input)
  const scrolled = field.list.scrollTop
  browser.dispatchEvent(new Event("scroll"))
  assert.equal(field.list.scrollTop, scrolled)
  field.key("ArrowDown")
  assert.equal(field.context.highlightedItem(), field.rows[121])
  assert.equal(field.rows[121].getBoundingClientRect().bottom, field.list.getBoundingClientRect().bottom)
  field.key("Home")
  assert.equal(field.list.scrollTop, 0)
  field.key("End")
  assert.equal(field.context.highlightedItem(), field.rows.at(-1))
  assert.equal(field.rows.at(-1).getBoundingClientRect().bottom, field.list.getBoundingClientRect().bottom)
  assert.equal(browser.scrollY, 935)
  assert.equal(field.select.value, "121")
})

test("multiple selections reveal the first selected option on opening and preserve subsequent navigation", () => {
  const field = picker({multiple: true, options: Array.from({length: 150}, (_, index) => [`Choice ${index + 1}`, String(index + 1)])})
  for (const option of field.select.options) option.selected = ["91", "121"].includes(option.value)
  field.select.dispatchEvent(new Event("change"))
  field.events.length = 0
  field.trigger.rect = {top: 650, bottom: 694}
  browser.scrollY = 935
  field.trigger.dispatchEvent(new Event("click"))
  assert.equal(field.list.style.maxHeight, "36px")
  assert.equal(field.context.highlightedItem(), field.rows[90])
  assert.equal(field.input.getAttribute("aria-activedescendant"), field.rows[90].id)
  assert.equal(field.rows[90].getBoundingClientRect().bottom, field.list.getBoundingClientRect().bottom)
  assert.deepEqual(field.context.selectedValues(), ["91", "121"])
  assert.equal(field.label.textContent, "2 selected")
  assert.deepEqual(field.events, [])
  assert.equal(browser.scrollY, 935)
  field.key("ArrowDown")
  const scrolled = field.list.scrollTop
  field.key("Enter")
  assert.equal(field.panel.hidden, false)
  assert.equal(field.context.highlightedItem(), field.rows[91])
  assert.equal(field.list.scrollTop, scrolled)
  field.context.openPanel()
  assert.equal(field.context.highlightedItem(), field.rows[91])
  assert.equal(field.list.scrollTop, scrolled)
  field.context.closePanel()
  field.trigger.dispatchEvent(new Event("click"))
  assert.equal(field.context.highlightedItem(), field.rows[90])
  assert.equal(field.rows[90].getBoundingClientRect().bottom, field.list.getBoundingClientRect().bottom)
  assert.equal(browser.scrollY, 935)
})

test("multiple opening skips disabled selected options and keeps native empty-selection homing", () => {
  for (const selected of [["2", "91"], ["2"], []]) {
    const field = picker({multiple: true, options: Array.from({length: 100}, (_, index) => [`Choice ${index + 1}`, String(index + 1), {disabled: index === 1}])})
    for (const option of field.select.options) option.selected = selected.includes(option.value)
    field.select.dispatchEvent(new Event("change"))
    field.context.openPanel()
    const expected = selected.includes("91") ? field.rows[90] : field.rows[0]
    assert.equal(field.context.highlightedItem(), expected)
    assert.equal(field.context.highlightedItem().hasAttribute("data-disabled"), false)
    assert.deepEqual(field.context.selectedValues(), selected)
    if (selected.includes("91")) assert.equal(expected.getBoundingClientRect().bottom, field.list.getBoundingClientRect().bottom)
    else assert.equal(field.list.scrollTop, 0)
  }
})

test("multiple initial reveal leaves retained searches and noncore opening behavior native", () => {
  for (const core of [true, false]) {
    const field = picker({multiple: true, value: "20", core})
    if (core) {
      field.input.value = "Choice 1"
      field.context.query = "choice 1"
    }
    field.context.openPanel({keepQuery: true})
    assert.equal(field.context.highlightedItem(), field.rows[0])
    assert.equal(field.list.scrollTop, 0)
    assert.deepEqual(field.context.selectedValues(), ["20"])
  }
})

test("filtered results resize the popup and empty results retain native empty state", () => {
  const field = picker()
  field.context.openPanel()
  field.search("Choice 20")
  assert.equal(field.context.visibleItems().length, 1)
  assert.equal(field.list.style.maxHeight, "36px")
  field.search("unmatched")
  assert.equal(field.empty.hidden, false)
  assert.equal(field.list.style.maxHeight, "0px")
})

test("custom input defaults to unavailable and native exact choices still commit", () => {
  const field = picker({options: [["Administrator", "admin"]]})
  field.context.openPanel()
  field.search("New role")
  field.key("Enter")
  assert.equal(field.select.value, "")
  assert.equal(field.empty.hidden, false)
  field.search("Administrator")
  field.key("Enter")
  assert.equal(field.select.value, "admin")
  assert.equal(field.label.textContent, "Administrator")
})

test("custom values appear first in visual and keyboard order with the typed label", () => {
  const field = picker({custom: true, options: [["Administrator", "admin"], ["Editor", "editor"]]})
  field.context.openPanel()
  field.search("Admi")
  assert.equal(field.list.firstElementChild, field.create)
  assert.equal(field.create.textContent, "Admi (custom value)")
  assert.equal(field.context.navItems()[0], field.create)
  assert.equal(field.context.highlightedItem(), field.create)
  field.key("ArrowDown")
  assert.equal(field.context.highlightedItem(), field.rows[0])
  field.key("Home")
  assert.equal(field.context.highlightedItem(), field.create)
  field.key("End")
  assert.equal(field.context.highlightedItem(), field.rows[0])
})

test("custom commits update the canonical select and trigger label immediately", () => {
  const field = picker({custom: true})
  field.context.openPanel()
  field.search("New role")
  field.key("Enter")
  assert.equal(field.select.value, "New role")
  assert.equal(field.label.textContent, "New role")
  assert.equal(field.panel.hidden, true)
  assert.deepEqual(field.events, [["input", "New role"], ["change", "New role"]])
  assert.equal(field.context.items().filter(row => row.dataset.value === "New role").length, 1)
  assert.equal(field.select.options.filter(option => option.value === "New role").length, 1)
  field.context.updated()
  assert.equal(field.label.textContent, "New role")
  field.context.openPanel()
  field.search("New role")
  assert.equal(field.create.hidden, true)
})

test("case-insensitive exact labels suppress custom choices and preserve existing values", () => {
  const field = picker({custom: true, options: [["Administrator", "admin"]]})
  field.context.openPanel()
  field.search(" ADMINISTRATOR ")
  assert.equal(field.create.hidden, true)
  field.key("Enter")
  assert.equal(field.select.value, "admin")
  assert.equal(field.label.textContent, "Administrator")
  assert.equal(field.select.options.length, 2)
})

test("new custom rows have unique stable IDs that keyboard highlights can reference", () => {
  const field = picker({custom: true})
  const created = []
  for (const value of ["New role", "New/role"]) {
    field.context.openPanel()
    field.search(value)
    field.key("Enter")
    const row = field.context.items().find(item => item.dataset.value === value)
    assert.ok(row.id)
    assert.equal(document.getElementById(row.id), row)
    created.push(row)
  }
  assert.notEqual(created[0].id, created[1].id)
  field.context.openPanel()
  field.search("New role")
  assert.equal(field.context.highlightedItem(), created[0])
  assert.equal(field.input.getAttribute("aria-activedescendant"), created[0].id)
  field.key("Enter")
  assert.equal(field.select.value, "New role")
  assert.equal(field.context.items().filter(row => row.dataset.value === "New role").length, 1)
  assert.equal(field.select.options.filter(option => option.value === "New role").length, 1)
})

test("custom text matching an existing value retains the canonical option label", () => {
  const field = picker({custom: true, options: [["Administrator", "admin"]]})
  field.context.openPanel()
  field.search("admin")
  assert.equal(field.create.hidden, false)
  field.key("Enter")
  assert.equal(field.select.value, "admin")
  assert.equal(field.label.textContent, "Administrator")
  assert.equal(field.select.options.length, 2)
})

test("custom Enter cannot bypass disabled options through their exact labels or values", () => {
  for (const query of [" UNAVAILABLE ", "restricted"]) {
    const field = picker({custom: true, options: [["Unavailable", "restricted", {disabled: true}], ["Editor", "editor"]]})
    field.select.value = "editor"
    field.select.dispatchEvent(new Event("change"))
    field.events.length = 0
    field.context.openPanel()
    field.search(query)
    field.key("Enter")
    assert.equal(field.select.value, "editor")
    assert.equal(field.label.textContent, "Editor")
    assert.deepEqual(field.events, [])
    assert.equal(field.select.options.length, 3)
    assert.equal(field.context.items().length, 2)
    assert.equal(field.select.options.find(option => option.value === "restricted").selected, false)
  }
})

test("direct nonbubbling select changes refresh special input triggers and native clear still works", () => {
  const field = picker({options: [["RGB", "rgb"], ["HEX", "hex"]]})
  field.select.value = "rgb"
  field.select.dispatchEvent(new Event("change"))
  assert.equal(field.label.textContent, "RGB")
  assert.equal(field.root.hasAttribute("data-has-value"), true)
  field.clear.dispatchEvent(new Event("click"))
  assert.equal(field.select.value, "")
  assert.equal(field.label.textContent, "Choose")
  assert.equal(field.root.hasAttribute("data-has-value"), false)
})

test("multiple native and custom choices retain their selection order and clear together", () => {
  const field = picker({custom: true, multiple: true, options: [["Administrator", "admin"], ["Editor", "editor"]]})
  field.context.openPanel()
  field.context.choose(field.rows[1])
  field.search("New role")
  field.key("Enter")
  assert.deepEqual(field.context.selectedValues(), ["editor", "New role"])
  assert.equal(field.label.textContent, "2 selected")
  assert.equal(field.panel.hidden, false)
  field.clear.dispatchEvent(new Event("click"))
  assert.deepEqual(field.context.selectedValues(), [])
  assert.equal(field.label.textContent, "Choose")
  assert.equal(field.panel.hidden, true)
  assert.equal(field.root.hasAttribute("data-has-value"), false)
})

test("external multiple clear uses the native owner once and returns to working trigger navigation", () => {
  const field = picker({multiple: true, externalClear: true})
  globalThis.MutationObserver = class { observe() {} disconnect() {} }
  const controls = initInputControls()
  try {
    assert.equal(field.root.contains(field.clear), false)
    field.context.openPanel()
    field.context.choose(field.rows[0])
    field.events.length = 0
    const event = new Event("click", {bubbles: true, cancelable: true})
    Object.defineProperty(event, "target", {value: field.clear})
    controls.onActivation(event)
    assert.deepEqual(field.context.selectedValues(), [])
    assert.deepEqual(field.events.map(([name]) => name), ["input", "change"])
    assert.equal(field.panel.hidden, true)
    assert.equal(field.label.textContent, "Choose")
    assert.equal(document.activeElement, field.trigger)
    field.trigger.dispatchEvent(Object.assign(new Event("keydown", {cancelable: true}), {key: "ArrowDown"}))
    assert.equal(field.panel.hidden, false)
    assert.equal(document.activeElement, field.input)
  } finally {
    controls.destroyed()
    delete globalThis.MutationObserver
  }
})

test("keeps upstream presentation and navigation outside core selection inputs", () => {
  const field = picker({core: false, custom: true, options: [["Administrator", "admin"]]})
  field.context.openPanel()
  field.search("Admi")
  assert.equal(field.list.firstElementChild, field.rows[0])
  assert.equal(field.context.navItems().at(-1), field.create)
  assert.equal(field.create.textContent, 'Create "Admi"')
})

test("teardown removes native and visual viewport listeners", () => {
  const field = picker()
  field.context.openPanel()
  const listener = field.context.onReposition
  assert.ok(getEventListeners(browser.visualViewport, "resize").includes(listener))
  assert.ok(getEventListeners(field.select, "change").includes(field.context.onSelectChange))
  field.context.destroyed()
  fixtures.delete(field)
  field.container.remove()
  assert.equal(getEventListeners(browser, "scroll").includes(listener), false)
  assert.equal(getEventListeners(browser.visualViewport, "resize").includes(listener), false)
  assert.equal(getEventListeners(browser.visualViewport, "scroll").includes(listener), false)
  assert.equal(getEventListeners(field.select, "change").includes(field.context.onSelectChange), false)
  assert.equal(getEventListeners(field.container, "input:clear").includes(field.context.onClear), false)
})

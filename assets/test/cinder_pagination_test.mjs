import test from "node:test"
import assert from "node:assert/strict"
import {getEventListeners} from "node:events"
import {readFile} from "node:fs/promises"

const source = await readFile(new URL("../js/cinder_pagination.js", import.meta.url), "utf8")
const CinderPagination = (await import(`data:text/javascript;base64,${Buffer.from(source).toString("base64")}`)).default
const originalGlobals = Object.fromEntries(["document", "MutationObserver"].map(name => [name, globalThis[name]]))
const fixtures = new Set()

class TextNode {
  constructor(value) { this.nodeType = 3; this.textContent = String(value); this.parentElement = null }
  detach() {
    if (this.parentElement) this.parentElement.childNodes.splice(this.parentElement.childNodes.indexOf(this), 1)
    this.parentElement = null
  }
  remove() { this.detach() }
  cloneNode() { return new TextNode(this.textContent) }
  isEqualNode(other) { return other instanceof TextNode && this.textContent === other.textContent }
}

class Element extends EventTarget {
  constructor(tagName = "div") {
    super()
    this.nodeType = 1
    this.tagName = tagName.toUpperCase()
    this.attributeValues = new Map()
    this.childNodes = []
    this.parentElement = null
    this.content = ""
    this.inputValue = ""
    this.dataset = new Proxy({}, {
      get: (_target, key) => this.getAttribute(`data-${key.replace(/[A-Z]/g, letter => `-${letter.toLowerCase()}`)}`) ?? undefined,
      set: (_target, key, value) => { this.setAttribute(`data-${key.replace(/[A-Z]/g, letter => `-${letter.toLowerCase()}`)}`, value); return true },
    })
    this.classList = {
      contains: value => this.className.split(/\s+/).includes(value),
      remove: (...values) => { if (this.hasAttribute("class")) this.className = this.className.split(/\s+/).filter(value => !values.includes(value)).join(" ") },
      add: (...values) => { this.className = [...new Set([...this.className.split(/\s+/).filter(Boolean), ...values])].join(" ") },
    }
  }
  get attributes() { return Array.from(this.attributeValues, ([name, value]) => ({name, value})) }
  get children() { return this.childNodes.filter(child => child.nodeType === 1) }
  get textContent() { return this.content + this.childNodes.map(child => child.textContent).join("") }
  set textContent(value) { this.replaceChildren(); this.content = String(value) }
  get value() {
    if (this.tagName === "SELECT") return (this.options.find(option => option.selected) ?? this.options[0])?.value ?? ""
    if (this.tagName === "OPTION") return this.getAttribute("value") ?? this.textContent
    return this.inputValue
  }
  set value(value) {
    if (this.tagName === "SELECT") for (const option of this.options) option.selected = option.value === String(value)
    else if (this.tagName === "OPTION") this.setAttribute("value", value)
    else this.inputValue = String(value)
  }
  get options() { return this.querySelectorAll("option") }
  get selected() { return this.selectedState ?? this.hasAttribute("selected") }
  set selected(value) { this.selectedState = !!value }
  get firstElementChild() { return this.children[0] ?? null }
  get nextElementSibling() { return this.parentElement?.children[this.parentElement.children.indexOf(this) + 1] ?? null }
  get previousElementSibling() { return this.parentElement?.children[this.parentElement.children.indexOf(this) - 1] ?? null }
  get isConnected() { return globalThis.document.body.contains(this) }
  get valueAsNumber() { return this.value.trim() === "" ? NaN : Number(this.value) }
  get disabled() { return this.hasAttribute("disabled") }
  set disabled(value) { if (value) this.setAttribute("disabled", ""); else this.removeAttribute("disabled") }
  get hidden() { return this.hasAttribute("hidden") }
  set hidden(value) { if (value) this.setAttribute("hidden", ""); else this.removeAttribute("hidden") }
  setAttribute(name, value) { this.attributeValues.set(name, String(value)) }
  getAttribute(name) { return this.attributeValues.get(name) ?? null }
  hasAttribute(name) { return this.attributeValues.has(name) }
  removeAttribute(name) { this.attributeValues.delete(name) }
  toggleAttribute(name, force = !this.hasAttribute(name)) {
    if (force) this.setAttribute(name, "")
    else this.removeAttribute(name)
    return force
  }
  matches(selector) {
    if (selector.includes(",")) return selector.split(",").some(part => this.matches(part.trim()))
    const exclusions = [...selector.matchAll(/:not\(([^)]+)\)/g)]
    if (exclusions.some(match => this.matches(match[1]))) return false
    selector = selector.replace(/:not\([^)]+\)/g, "")
    const tag = selector.match(/^[a-z]+/i)?.[0]
    if (tag && this.tagName !== tag.toUpperCase()) return false
    for (const [, name, value] of selector.matchAll(/\[([^=\]]+)(?:=["']?([^\]"']+)["']?)?\]/g)) {
      if (!this.hasAttribute(name) || (value !== undefined && this.getAttribute(name) !== value)) return false
    }
    return true
  }
  querySelectorAll(selector) {
    if (selector.startsWith(":scope > ")) return this.children.filter(child => child.matches(selector.slice(9)))
    return this.children.flatMap(child => [child, ...child.querySelectorAll("*")]).filter(child => child.matches(selector))
  }
  querySelector(selector) { return this.querySelectorAll(selector)[0] ?? null }
  contains(node) {
    for (let element = node; element; element = element.parentElement) if (element === this) return true
    return false
  }
  append(...children) {
    for (let child of children) {
      if (typeof child === "string") child = new TextNode(child)
      child.detach()
      child.parentElement = this
      this.childNodes.push(child)
    }
  }
  prepend(child) { child.detach(); child.parentElement = this; this.childNodes.unshift(child) }
  before(child) {
    child.detach()
    child.parentElement = this.parentElement
    this.parentElement.childNodes.splice(this.parentElement.childNodes.indexOf(this), 0, child)
  }
  after(child) {
    child.detach()
    child.parentElement = this.parentElement
    this.parentElement.childNodes.splice(this.parentElement.childNodes.indexOf(this) + 1, 0, child)
  }
  detach() {
    if (this.parentElement) this.parentElement.childNodes.splice(this.parentElement.childNodes.indexOf(this), 1)
    this.parentElement = null
  }
  remove() {
    if (this.contains(globalThis.document.activeElement)) globalThis.document.activeElement = globalThis.document.body
    this.detach()
  }
  replaceChildren(...children) {
    for (const child of [...this.childNodes]) child.remove()
    this.content = ""
    this.append(...children)
  }
  replaceWith(...children) {
    for (const child of children) this.before(typeof child === "string" ? new TextNode(child) : child)
    this.remove()
  }
  cloneNode(deep) {
    const clone = new Element(this.tagName)
    for (const {name, value} of this.attributes) clone.setAttribute(name, value)
    clone.content = this.content
    clone.inputValue = this.inputValue
    clone.selectedState = this.selectedState
    if (deep) clone.append(...this.childNodes.map(child => child.cloneNode(true)))
    return clone
  }
  isEqualNode(other) {
    return !!other && this.tagName === other.tagName && this.content === other.content && this.attributeValues.size === other.attributeValues.size && this.attributes.every(({name, value}) => other.getAttribute(name) === value) && this.childNodes.length === other.childNodes.length && this.childNodes.every((child, index) => child.isEqualNode(other.childNodes[index]))
  }
  focus() {
    if (globalThis.document.activeElement === this) return
    globalThis.document.activeElement?.blur()
    globalThis.document.activeElement = this
    this.dispatchEvent(new Event("focusin", {bubbles: true}))
  }
  blur() {
    if (globalThis.document.activeElement !== this) return
    globalThis.document.activeElement = globalThis.document.body
    this.dispatchEvent(new Event("focusout", {bubbles: true}))
  }
  dispatchEvent(event) {
    if (!event.target) Object.defineProperty(event, "target", {value: this})
    const result = super.dispatchEvent(event)
    if (event.bubbles && !event.cancelBubble) this.parentElement?.dispatchEvent(event)
    return result
  }
}

for (const [property, attribute] of Object.entries({id: "id", className: "class", type: "type", placeholder: "placeholder", min: "min", max: "max", step: "step", inputMode: "inputmode"})) {
  Object.defineProperty(Element.prototype, property, {
    get() { return this.getAttribute(attribute) ?? "" },
    set(value) { this.setAttribute(attribute, value) },
  })
}

globalThis.document = {body: new Element("body"), createElement: tag => new Element(tag), createTextNode: value => new TextNode(value)}
globalThis.document.activeElement = globalThis.document.body
globalThis.MutationObserver = class {
  constructor(callback) { this.callback = callback; this.observing = false }
  observe() { this.observing = true }
  disconnect() { this.observing = false }
}

test.afterEach(() => {
  for (const fixture of fixtures) {
    if (!fixture.destroyed) fixture.context.destroyed()
    fixture.root.remove()
  }
  fixtures.clear()
})
test.after(() => {
  for (const [name, value] of Object.entries(originalGlobals)) {
    if (value === undefined) delete globalThis[name]
    else globalThis[name] = value
  }
})

function openCollection(current = 1, maximum = 20, configuration = {}) {
  const root = new Element()
  root.id = "test-collection"
  const collection = new Element()
  collection.dataset.key = "container_class"
  const controls = new Element()
  controls.dataset.key = "controls_class"
  collection.append(controls)
  root.append(collection)
  document.body.append(root)
  const requests = []
  const context = {...CinderPagination, el: root, pushEventTo: (target, event, payload) => requests.push({target, event, payload})}
  const fixture = {
    root, collection, controls, context, requests,
    patch(page, total = maximum, {pageSize = this.pageSize ?? 10, options = this.pageSizeOptions ?? [10, 25, 50, 100], count = total * pageSize} = {}) {
      this.pageSize = pageSize
      this.pageSizeOptions = options
      this.bottom?.remove()
      const bottom = new Element()
      bottom.dataset.key = "pagination_wrapper_class"
      const info = new Element()
      info.dataset.key = "pagination_info_class"
      info.textContent = `Page ${page} of ${total}`
      const countInfo = new Element("span")
      countInfo.dataset.key = "pagination_count_class"
      countInfo.textContent = `(showing ${(page - 1) * pageSize + 1}-${Math.min(page * pageSize, count)} of ${count})`
      info.append(countInfo)
      const navigation = new Element()
      navigation.dataset.key = "pagination_nav_class"
      const pageSizeControl = new Element()
      pageSizeControl.dataset.key = "page_size_container_class"
      if (options.length > 1) {
        const trigger = new Element("button")
        trigger.dataset.key = "page_size_dropdown_class"
        trigger.className = "input-native-select text-brand"
        trigger.textContent = this.pageSize
        const dropdown = new Element()
        dropdown.dataset.key = "page_size_dropdown_container_class"
        dropdown.id = "test-component-page-size-options"
        for (const size of options) {
          const option = new Element("button")
          option.dataset.key = "page_size_option_class"
          option.setAttribute("phx-click", "change_page_size")
          option.setAttribute("phx-value-page_size", size)
          option.setAttribute("phx-target", "17")
          option.textContent = size
          dropdown.append(option)
        }
        pageSizeControl.append(trigger, dropdown)
        bottom.append(pageSizeControl)
      }
      bottom.prepend(info)
      bottom.append(navigation)
      for (const [visible, target, title, text] of [
        [page > 2, 1, "First page", "«"],
        [page > 1, page - 1, "Previous page", "‹"],
      ]) if (visible) navigation.append(pageButton(target, title, text))
      for (let number = Math.max(1, page - 2); number <= Math.min(total, page + 2); number++) {
        const wrapper = new Element("span")
        if (number === page) {
          const selected = new Element("span")
          selected.dataset.key = "pagination_current_class"
          selected.textContent = number
          wrapper.append(selected)
        } else wrapper.append(pageButton(number, `Go to page ${number}`, String(number)))
        navigation.append(wrapper)
      }
      for (const [visible, target, title, text] of [
        [page < total, page + 1, "Next page", "›"],
        [page < total - 1, total, "Last page", "»"],
      ]) if (visible) navigation.append(pageButton(target, title, text))
      collection.append(bottom)
      this.bottom = bottom
      this.navigation = navigation
      if (context.observer) context.updated()
    },
    setLoading(active, content) {
      this.loading?.remove()
      this.loading = null
      if (active) {
        const loading = new Element()
        loading.dataset.key = "loading_overlay_class"
        loading.className = "absolute top-4 right-4"
        if (!content) {
          content = new Element()
          content.dataset.key = "loading_container_class"
          const spinner = new Element("svg")
          spinner.dataset.key = "loading_spinner_class"
          spinner.setAttribute("aria-hidden", "true")
          content.append(spinner, "Loading...")
        }
        loading.append(content)
        if (this.bottom?.isConnected) this.bottom.before(loading)
        else collection.append(loading)
        this.loading = loading
      }
      context.updated()
    },
    gap(position = "bottom", side = "after") {
      return (position === "top" ? context.topPagination : this.bottom).querySelector(`[data-cinder-pagination-gap=${side}]`)
    },
    pageSizeSelect(position = "bottom") {
      return (position === "top" ? context.topPagination : this.bottom)?.querySelector("[data-cinder-page-size]")
    },
  }
  fixture.patch(current, maximum, configuration)
  fixtures.add(fixture)
  context.mounted()
  return fixture
}

function pageButton(page, title, text) {
  const button = new Element("button")
  button.setAttribute("phx-click", "goto_page")
  button.setAttribute("phx-value-page", page)
  button.setAttribute("phx-target", "17")
  button.setAttribute("title", title)
  button.dataset.key = "pagination_button_class"
  button.className = "pagination-button"
  button.textContent = text
  return button
}

test("both pagination bars render bounded page inputs for omitted pages, including the last page", () => {
  for (const [current, sides] of [[1, ["after"]], [10, ["before", "after"]], [20, ["before"]]]) {
    const fixture = openCollection(current)
    for (const position of ["top", "bottom"]) {
      const bar = position === "top" ? fixture.context.topPagination : fixture.bottom
      assert.equal(bar.querySelectorAll("[data-cinder-pagination-gap]").length, sides.length)
      for (const side of sides) {
        const input = fixture.gap(position, side)
        assert.equal(input.tagName, "INPUT")
        assert.equal(input.type, "number")
        assert.equal(input.placeholder, "...")
        assert.equal(input.min, "1")
        assert.equal(input.max, "20")
        assert.ok(input.getAttribute("aria-label"))
        assert.equal(input.textContent, "")
      }
    }
    assert.equal(fixture.context.topPagination.querySelector("[data-key=page_size_container_class]"), null)
    assert.ok(fixture.bottom.querySelector("[data-key=page_size_container_class]"))
    assert.equal(fixture.controls.nextElementSibling, fixture.context.topPagination)
  }
})

test("both count summaries offer the configured page sizes with distinct accessible selectors", () => {
  const fixture = openCollection()
  const ids = []
  for (const position of ["top", "bottom"]) {
    const bar = position === "top" ? fixture.context.topPagination : fixture.bottom
    const count = bar.querySelector("[data-key=pagination_count_class]")
    const select = fixture.pageSizeSelect(position)
    assert.equal(select.tagName, "SELECT")
    assert.deepEqual(select.options.map(option => option.value), ["10", "25", "50", "100"])
    assert.equal(select.value, "10")
    assert.ok(select.getAttribute("aria-label"))
    assert.ok(select.id)
    ids.push(select.id)
    assert.equal(count.childNodes.map(node => node === select ? select.value : node.textContent).join(""), "(showing 10 of 200)")
  }
  assert.equal(new Set(ids).size, ids.length)
  assert.equal(fixture.bottom.querySelector("[data-key=page_size_container_class]").hidden, true)
})

test("changing either count selector uses Cinder's page-size event without affecting unrelated changes", () => {
  const fixture = openCollection()
  for (const [position, value] of [["top", "25"], ["bottom", "50"]]) {
    const select = fixture.pageSizeSelect(position)
    select.focus()
    select.value = value
    const count = fixture.requests.length
    select.dispatchEvent(new Event("change", {bubbles: true}))
    assert.equal(fixture.requests.length, count + 1)
    const request = fixture.requests.at(-1)
    assert.equal(request.target, "17")
    assert.equal(request.event, "change_page_size")
    assert.equal(String(request.payload.page_size), value)
  }
  const count = fixture.requests.length
  fixture.controls.dispatchEvent(new Event("change", {bubbles: true}))
  assert.equal(fixture.requests.length, count)
})

test("page-size patches update both summaries, available options, and focused selectors", () => {
  const fixture = openCollection()
  for (const [position, pageSize, total, options] of [
    ["top", 25, 8, [10, 25, 50, 100]],
    ["bottom", 40, 5, [10, 40, 80]],
  ]) {
    const previous = fixture.pageSizeSelect(position)
    previous.focus()
    fixture.patch(1, total, {pageSize, options, count: 200})
    const replacement = fixture.pageSizeSelect(position)
    assert.notEqual(replacement, previous)
    assert.equal(document.activeElement, replacement)
    for (const bar of [fixture.context.topPagination, fixture.bottom]) {
      const select = bar.querySelector("[data-cinder-page-size]")
      assert.equal(select.value, String(pageSize))
      assert.deepEqual(select.options.map(option => option.value), options.map(String))
      assert.equal(bar.querySelector("[data-key=pagination_count_class]").childNodes.map(node => node === select ? select.value : node.textContent).join(""), `(showing ${pageSize} of 200)`)
    }
    assert.deepEqual(fixture.requests, [])
  }
})

test("a size change updates the top selector when both presets have the same number of pages", () => {
  const fixture = openCollection(1, 2, {pageSize: 40, options: [40, 50], count: 80})
  assert.equal(fixture.pageSizeSelect("top").value, "40")
  fixture.patch(1, 2, {pageSize: 50, count: 80})
  assert.equal(fixture.pageSizeSelect("top").value, "50")
  assert.equal(fixture.pageSizeSelect().value, "50")
})

test("fixed page sizes retain the native range text without adding a selector", () => {
  const fixture = openCollection(1, 20, {options: []})
  for (const bar of [fixture.context.topPagination, fixture.bottom]) {
    assert.equal(bar.querySelector("[data-cinder-page-size]"), null)
    assert.equal(bar.querySelector("[data-key=pagination_count_class]").textContent, "(showing 1-10 of 200)")
  }
})

test("loading feedback appears beside both result counts and clears when results arrive", () => {
  const fixture = openCollection()
  fixture.setLoading(true)
  const source = fixture.loading
  assert.equal(source.parentElement, fixture.collection)
  assert.equal(source.hidden, true)
  for (let update = 0; update < 3; update++) {
    if (update === 1) fixture.patch(2)
    else fixture.context.updated()
    assert.equal(fixture.root.querySelectorAll("[data-cinder-loading]").length, 2)
    for (const bar of [fixture.context.topPagination, fixture.bottom]) {
      const indicator = bar.querySelector("[data-key=pagination_count_class]").nextElementSibling
      assert.ok(indicator.matches("[data-cinder-loading]"))
      assert.equal(indicator.hidden, false)
      assert.equal(indicator.textContent, "Loading...")
      assert.ok(indicator.firstElementChild.isEqualNode(source.firstElementChild))
    }
  }
  fixture.setLoading(false)
  assert.equal(fixture.root.querySelectorAll("[data-cinder-loading]").length, 0)
  assert.ok(fixture.context.topPagination)
  assert.ok(fixture.pageSizeSelect())
})

test("inline feedback retains the native custom loading content in both bars", () => {
  const fixture = openCollection()
  const content = new Element("section")
  content.setAttribute("role", "status")
  content.setAttribute("aria-live", "polite")
  content.dataset.phxId = "m2-test-component"
  content.className = "loading-content phx-click-loading"
  const message = new Element("strong")
  message.dataset.phxLoc = "14"
  message.textContent = "Refreshing records"
  const detail = new Element("span")
  detail.textContent = "Please wait"
  content.append(message, detail)
  fixture.setLoading(true, content)
  fixture.loading.dataset.phxId = "m1-test-component"
  fixture.loading.dataset.phxLoc = "12"
  fixture.loading.classList.add("phx-click-loading")
  fixture.context.updated()
  for (const bar of [fixture.context.topPagination, fixture.bottom]) {
    const indicator = bar.querySelector("[data-cinder-loading]")
    assert.ok(indicator)
    assert.notEqual(indicator, fixture.loading)
    const status = indicator.firstElementChild
    assert.equal(status.tagName, "SECTION")
    assert.equal(status.getAttribute("role"), "status")
    assert.equal(status.getAttribute("aria-live"), "polite")
    assert.ok(status.classList.contains("loading-content"))
    assert.deepEqual(status.children.map(child => [child.tagName, child.textContent]), [["STRONG", "Refreshing records"], ["SPAN", "Please wait"]])
    for (const element of [indicator, ...indicator.querySelectorAll("*")]) {
      assert.equal(element.attributes.some(attribute => attribute.name.startsWith("data-phx-")), false)
      assert.equal(element.classList.contains("phx-click-loading"), false)
    }
  }
  assert.equal(content.parentElement, fixture.loading)
  assert.equal(fixture.loading.dataset.phxId, "m1-test-component")
  assert.equal(fixture.loading.dataset.phxLoc, "12")
  assert.equal(content.dataset.phxId, "m2-test-component")
  assert.equal(message.dataset.phxLoc, "14")
  assert.ok(fixture.loading.classList.contains("phx-click-loading"))
  assert.ok(content.classList.contains("phx-click-loading"))
})

test("loading retains the native fallback when pagination or its count is unavailable", () => {
  const fixture = openCollection()
  fixture.bottom.querySelector("[data-key=pagination_count_class]").remove()
  fixture.setLoading(true)
  assert.equal(fixture.loading.hidden, false)
  assert.equal(fixture.root.querySelectorAll("[data-cinder-loading]").length, 0)
  fixture.patch(2)
  assert.equal(fixture.loading.hidden, true)
  assert.equal(fixture.root.querySelectorAll("[data-cinder-loading]").length, 2)
  fixture.bottom.remove()
  fixture.context.updated()
  assert.equal(fixture.context.topPagination, null)
  assert.equal(fixture.loading.hidden, false)
  assert.equal(fixture.root.querySelectorAll("[data-cinder-loading]").length, 0)
})

test("destroying pagination during loading restores its native feedback", () => {
  const fixture = openCollection()
  fixture.setLoading(true)
  assert.equal(fixture.loading.hidden, true)
  fixture.context.destroyed()
  fixture.destroyed = true
  assert.equal(fixture.loading.parentElement, fixture.collection)
  assert.equal(fixture.loading.hidden, false)
  assert.equal(fixture.loading.textContent, "Loading...")
  assert.equal(fixture.root.querySelectorAll("[data-cinder-loading]").length, 0)
  assert.equal(fixture.bottom.querySelector("[data-key=pagination_count_class]").textContent, "(showing 1-10 of 200)")
})

test("blur jumps from either bar, clamps page bounds, and ignores empty or invalid values", () => {
  const fixture = openCollection()
  for (const position of ["top", "bottom"]) {
    const input = fixture.gap(position)
    for (const [value, expected] of [["8", 8], ["999", 20], ["0", 1], ["-3", 1], ["4.9", 4]]) {
      input.focus()
      input.value = value
      input.blur()
      assert.deepEqual(fixture.requests.at(-1), {target: "17", event: "goto_page", payload: {page: expected}})
      assert.equal(input.value, "")
    }
    const count = fixture.requests.length
    for (const value of ["", "invalid", "Infinity"]) {
      input.focus()
      input.value = value
      input.blur()
      assert.equal(fixture.requests.length, count)
    }
  }
})

test("Enter blurs and submits once while ordinary keys leave the input focused", () => {
  const fixture = openCollection()
  for (const position of ["top", "bottom"]) {
    const input = fixture.gap(position)
    input.focus()
    input.value = "7"
    const ordinary = Object.assign(new Event("keydown", {bubbles: true, cancelable: true}), {key: "7"})
    input.dispatchEvent(ordinary)
    assert.equal(ordinary.defaultPrevented, false)
    assert.equal(document.activeElement, input)
    const count = fixture.requests.length
    const enter = Object.assign(new Event("keydown", {bubbles: true, cancelable: true}), {key: "Enter"})
    input.dispatchEvent(enter)
    assert.equal(enter.defaultPrevented, true)
    assert.equal(document.activeElement, document.body)
    assert.equal(fixture.requests.length, count + 1)
    input.dispatchEvent(new Event("focusout", {bubbles: true}))
    assert.equal(fixture.requests.length, count + 1)
    fixture.patch(position === "top" ? 7 : 8)
    assert.equal(document.activeElement, document.body)
  }
})

test("updates preserve existing inputs and listeners without submitting pending text", () => {
  const fixture = openCollection()
  for (const position of ["top", "bottom"]) {
    const input = fixture.gap(position)
    input.focus()
    input.value = "9"
    for (let update = 0; update < 3; update++) fixture.context.updated()
    assert.equal(fixture.gap(position), input)
    assert.equal(document.activeElement, input)
    assert.equal(input.value, "9")
    assert.equal(getEventListeners(fixture.root, "focusout").length, 1)
    assert.equal(getEventListeners(fixture.root, "keydown").length, 1)
    assert.equal(getEventListeners(fixture.root, "change").length, 1)
    const count = fixture.requests.length
    input.blur()
    assert.equal(fixture.requests.length, count + 1)
  }
})

test("replacing the top bar restores its focused page input and pending value", () => {
  const fixture = openCollection()
  const input = fixture.gap("top")
  input.focus()
  input.value = "12"
  fixture.patch(2)
  const replacement = fixture.gap("top")
  assert.notEqual(replacement, input)
  assert.equal(document.activeElement, replacement)
  assert.equal(replacement.value, "12")
  assert.deepEqual(fixture.requests, [])
  replacement.blur()
  assert.deepEqual(fixture.requests, [{target: "17", event: "goto_page", payload: {page: 12}}])
})

test("a disappearing focused gap moves focus to the current page without navigating", () => {
  const fixture = openCollection()
  const input = fixture.gap("top")
  input.focus()
  input.value = "12"
  fixture.patch(19)
  assert.equal(fixture.gap("top"), null)
  assert.equal(document.activeElement, fixture.context.topPagination.querySelector("[aria-current=page]"))
  assert.deepEqual(fixture.requests, [])
})

test("navigation arrows use centered icon elements and retain their accessible actions", () => {
  const fixture = openCollection(10)
  for (const bar of [fixture.context.topPagination, fixture.bottom]) {
    const navigation = bar.querySelector("[data-key=pagination_nav_class]")
    for (const button of navigation.children.filter(child => child.tagName === "BUTTON")) {
      assert.equal(button.getAttribute("aria-label"), button.getAttribute("title"))
      assert.equal(button.getAttribute("phx-click"), "goto_page")
      assert.equal(button.getAttribute("phx-target"), "17")
      assert.equal(button.textContent, "")
      assert.equal(button.children.length, 1)
      assert.equal(button.firstElementChild.getAttribute("aria-hidden"), "true")
      assert.match(button.firstElementChild.className, /hero-chevron-(?:double-)?(?:left|right)/)
    }
  }
})

test("hiding pagination removes its top copy and destroying removes listeners and generated controls", () => {
  const fixture = openCollection()
  fixture.context.updated()
  fixture.bottom.remove()
  fixture.context.updated()
  assert.equal(fixture.context.topPagination, null)
  fixture.patch(1)
  fixture.context.destroyed()
  fixture.destroyed = true
  assert.equal(fixture.root.querySelectorAll("[data-cinder-pagination-gap]").length, 0)
  assert.equal(fixture.root.querySelectorAll("[data-cinder-pagination]").length, 0)
  assert.equal(fixture.root.querySelectorAll("[data-cinder-page-size]").length, 0)
  assert.equal(fixture.bottom.querySelector("[data-key=pagination_count_class]").textContent, "(showing 1-10 of 200)")
  assert.equal(fixture.bottom.querySelector("[data-key=page_size_container_class]").hidden, false)
  for (const name of ["focusin", "focusout", "keydown", "change"]) assert.equal(getEventListeners(fixture.root, name).length, 0)
  assert.equal(fixture.context.observer.observing, false)
})

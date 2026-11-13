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
    this.content = this.tagName === "TEMPLATE" ? new Element("fragment") : ""
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
  get textContent() { return this.tagName === "TEMPLATE" ? "" : this.content + this.childNodes.map(child => child.textContent).join("") }
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
  get isConnected() { return globalThis.document.head.contains(this) || globalThis.document.body.contains(this) }
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

globalThis.document = {
  head: new Element("head"), body: new Element("body"),
  createElement: tag => new Element(tag), createTextNode: value => new TextNode(value),
  querySelector(selector) { return this.head.querySelector(selector) || this.body.querySelector(selector) },
}
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
  root.id = configuration.id ?? "test-collection"
  root.setAttribute("phx-hook", "CinderPagination")
  const collection = new Element()
  collection.dataset.key = "container_class"
  collection.setAttribute("data-phx-component", configuration.component ?? "17")
  const controls = new Element()
  controls.dataset.key = "controls_class"
  collection.append(controls)
  root.append(collection)
  document.body.append(root)
  const requests = []
  const context = {...CinderPagination, el: root, pushEventTo: (target, event, payload) => requests.push({target, event, payload})}
  const fixture = {
    root, collection, controls, context, requests,
    configureSummary({pageSize = 10, selected = pageSize, options = [10, 25, 50, 100]} = {}) {
      this.summaryTemplate?.remove()
      const template = new Element("template")
      template.dataset.cinderSummary = ""
      template.dataset.cinderPageSizeConfig = JSON.stringify({selected_page_size: selected, default_page_size: pageSize, page_size_options: options, configurable: options.length > 1})
      template.dataset.cinderPageSizeClass = "input-native-select text-brand"
      const summary = new Element()
      summary.dataset.key = "pagination_wrapper_class"
      summary.dataset.phxLoc = "11"
      summary.dataset.phxId = "summary-template"
      const container = new Element()
      container.dataset.key = "pagination_container_class"
      const info = new Element()
      info.dataset.key = "pagination_info_class"
      info.append("Page 1 of 1")
      const count = new Element("span")
      count.dataset.key = "pagination_count_class"
      count.textContent = "(showing {start}-{count} of {count})"
      info.append(count)
      const navigation = new Element()
      navigation.dataset.key = "pagination_nav_class"
      const marker = new Element("span")
      const current = new Element("span")
      current.dataset.key = "pagination_current_class"
      current.dataset.phxLoc = "19"
      current.textContent = "1"
      marker.append(current)
      navigation.append(marker)
      container.append(info, navigation)
      summary.append(container)
      template.content.append(summary)
      root.prepend(template)
      this.summaryTemplate = template
      if (context.observer) context.updated()
    },
    patchResults(count, {layout = this.layout ?? "table", loading = false, error = false} = {}) {
      this.bottom?.remove()
      this.results?.remove()
      this.layout = layout
      const results = new Element(layout === "table" ? "tbody" : "div")
      results.dataset.key = {table: "tbody_class", list: "list_container_class", grid: "grid_container_class"}[layout]
      if (error || count === 0) {
        const message = new Element(layout === "table" ? "td" : "div")
        message.dataset.key = error ? "error_class" : "empty_class"
        message.textContent = error ? "Could not load records" : "No records found"
        if (layout === "table") {
          const row = new Element("tr")
          row.append(message)
          results.append(row)
        } else results.append(message)
      } else for (let index = 0; index < count; index++) {
        const item = new Element(layout === "table" ? "tr" : "div")
        item.dataset.key = {table: "row_class", list: "list_item_class", grid: "grid_item_clickable_class"}[layout]
        item.textContent = `Record ${index + 1}`
        results.append(item)
      }
      collection.append(results)
      this.results = results
      this.setLoading(loading)
    },
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
          option.setAttribute("phx-target", collection.getAttribute("data-phx-component"))
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
      ]) if (visible) navigation.append(pageButton(target, title, text, collection.getAttribute("data-phx-component")))
      for (let number = Math.max(1, page - 2); number <= Math.min(total, page + 2); number++) {
        const wrapper = new Element("span")
        if (number === page) {
          const selected = new Element("span")
          selected.dataset.key = "pagination_current_class"
          selected.textContent = number
          wrapper.append(selected)
        } else wrapper.append(pageButton(number, `Go to page ${number}`, String(number), collection.getAttribute("data-phx-component")))
        navigation.append(wrapper)
      }
      for (const [visible, target, title, text] of [
        [page < total, page + 1, "Next page", "›"],
        [page < total - 1, total, "Last page", "»"],
      ]) if (visible) navigation.append(pageButton(target, title, text, collection.getAttribute("data-phx-component")))
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
      if (context.observer) context.updated()
    },
    gap(position = "bottom", side = "after") {
      return (position === "top" ? context.topPagination : context.summary || this.bottom).querySelector(`[data-cinder-pagination-gap=${side}]`)
    },
    pageSizeSelect(position = "bottom") {
      return (position === "top" ? context.topPagination : context.summary || this.bottom)?.querySelector("[data-cinder-page-size]")
    },
  }
  if (configuration.paginationEnabled !== false) fixture.configureSummary(configuration.summary)
  if (configuration.summary) {
    fixture.patchResults(configuration.summary.count ?? 7, configuration.summary)
  } else fixture.patch(current, maximum, configuration)
  fixtures.add(fixture)
  context.mounted()
  return fixture
}

function pageButton(page, title, text, target = "17") {
  const button = new Element("button")
  button.setAttribute("phx-click", "goto_page")
  button.setAttribute("phx-value-page", page)
  button.setAttribute("phx-target", target)
  button.setAttribute("title", title)
  button.dataset.key = "pagination_button_class"
  button.className = "pagination-button"
  button.textContent = text
  return button
}

test("enabled collections show their count and inactive page marker in both bars", () => {
  for (const layout of ["table", "list", "grid"]) {
    for (const count of [10, 7, 0]) {
      const fixture = openCollection(1, 1, {summary: {layout, count}})
      assert.equal(fixture.root.querySelector("template[data-cinder-summary]"), fixture.summaryTemplate)
      assert.equal(fixture.root.querySelectorAll("[data-key=pagination_wrapper_class]").length, 2)
      assert.equal(fixture.summaryTemplate.querySelector("[data-key=pagination_wrapper_class]"), null)
      for (const bar of [fixture.context.topPagination, fixture.context.summary]) {
        assert.ok(bar.isConnected)
        assert.match(bar.querySelector("[data-key=pagination_info_class]").textContent, /^Page 1 of 1/)
        const select = bar.querySelector("[data-cinder-page-size]")
        const countInfo = bar.querySelector("[data-key=pagination_count_class]")
        assert.equal(select.value, "10")
        assert.equal(select.getAttribute("phx-target"), "17")
        assert.deepEqual(select.options.map(option => option.value), ["10", "25", "50", "100"])
        assert.equal(countInfo.childNodes.map(node => node === select ? select.value : node.textContent).join(""), `(showing 10 of ${count})`)
        const current = bar.querySelector("[aria-current=page]")
        assert.equal(current.tagName, "SPAN")
        assert.equal(current.textContent, "1")
        assert.equal(bar.querySelectorAll("button, input, [phx-click]").length, 0)
        for (const element of [bar, ...bar.querySelectorAll("*")]) {
          assert.equal(element.attributes.some(attribute => attribute.name.startsWith("data-phx-")), false)
        }
        current.dispatchEvent(new Event("click", {bubbles: true}))
      }
      const source = fixture.summaryTemplate.content.firstElementChild
      assert.equal(source.dataset.phxLoc, "11")
      assert.equal(source.dataset.phxId, "summary-template")
      assert.equal(source.querySelector("[data-key=pagination_current_class]").dataset.phxLoc, "19")
      assert.deepEqual(fixture.requests, [])
    }
  }
})

test("independent collections keep their own templates, presets, counts, and event targets", () => {
  const first = openCollection(1, 1, {id: "first-collection", component: "17", summary: {count: 7}})
  const second = openCollection(1, 1, {id: "second-collection", component: "18", summary: {count: 19, selected: 100}})
  const source = first.summaryTemplate.content.firstElementChild
  const originalSource = source.cloneNode(true)
  assert.notEqual(first.summaryTemplate, second.summaryTemplate)
  assert.equal(document.head.querySelectorAll("template[data-cinder-summary]").length, 0)
  assert.equal(first.root.querySelector("template"), first.summaryTemplate)
  assert.equal(second.root.querySelector("template"), second.summaryTemplate)

  first.pageSizeSelect("top").value = "25"
  first.pageSizeSelect("top").dispatchEvent(new Event("change", {bubbles: true}))
  first.patchResults(3)
  for (const position of ["top", "bottom"]) {
    assert.equal(first.pageSizeSelect(position).value, "25")
    assert.equal(second.pageSizeSelect(position).value, "100")
    assert.equal(second.pageSizeSelect(position).getAttribute("phx-target"), "18")
  }
  assert.equal(first.context.summary.querySelector("[data-key=pagination_count_class]").childNodes.at(-1).textContent, " of 3)")
  assert.equal(second.context.summary.querySelector("[data-key=pagination_count_class]").childNodes.at(-1).textContent, " of 19)")
  assert.deepEqual(first.requests, [{target: "17", event: "change_page_size", payload: {page_size: "25"}}])
  assert.deepEqual(second.requests, [])

  first.context.destroyed()
  first.destroyed = true
  assert.equal(first.summaryTemplate.isConnected, true)
  assert.equal(second.summaryTemplate.isConnected, true)
  assert.equal(second.context.summary.isConnected, true)
  second.pageSizeSelect("bottom").value = "25"
  second.pageSizeSelect("bottom").dispatchEvent(new Event("change", {bubbles: true}))
  second.context.updated()
  assert.equal(second.pageSizeSelect("top").value, "25")
  assert.deepEqual(second.requests, [{target: "18", event: "change_page_size", payload: {page_size: "25"}}])
  assert.equal(source.isEqualNode(originalSource), true)
  assert.equal(JSON.parse(first.summaryTemplate.dataset.cinderPageSizeConfig).selected_page_size, 10)
  assert.equal(JSON.parse(second.summaryTemplate.dataset.cinderPageSizeConfig).selected_page_size, 100)
})

test("disabled collections do not use a summary template outside their component", () => {
  const enabled = openCollection(1, 1, {summary: {count: 19, selected: 100}})
  const disabled = openCollection(1, 1, {id: "disabled-collection", component: "18", paginationEnabled: false, summary: {count: 7}})
  assert.equal(disabled.root.querySelector("template"), null)
  assert.equal(disabled.context.summary, null)
  assert.equal(disabled.context.topPagination, null)

  document.head.append(enabled.summaryTemplate)
  enabled.context.updated()
  assert.equal(enabled.context.summary, null)
  assert.equal(enabled.context.topPagination, null)
  assert.equal(disabled.root.querySelectorAll("[data-key=pagination_wrapper_class]").length, 0)
  enabled.summaryTemplate.remove()
})

test("filtering between multiple pages and one page updates both summaries without duplicating bars", () => {
  const fixture = openCollection(20)
  fixture.configureSummary()
  const previousTop = fixture.context.topPagination
  fixture.patchResults(7)
  assert.equal(previousTop.isConnected, false)
  assert.equal(fixture.root.querySelectorAll("[data-key=pagination_wrapper_class]").length, 2)
  assert.equal(fixture.root.querySelectorAll("[data-cinder-pagination-gap]").length, 0)
  assert.equal(fixture.root.querySelectorAll("[data-cinder-page-size]").length, 2)
  for (const count of [3, 0, 10]) {
    fixture.patchResults(count)
    for (const bar of [fixture.context.topPagination, fixture.context.summary]) {
      assert.equal(bar.querySelector("[data-key=pagination_count_class]").childNodes.at(-1).textContent, ` of ${count})`)
      assert.equal(bar.querySelector("[data-cinder-page-size]").value, "10")
    }
  }
  const summary = fixture.context.summary
  fixture.patch(1)
  assert.equal(summary.isConnected, false)
  assert.equal(fixture.context.summary, null)
  assert.equal(fixture.root.querySelectorAll("[data-key=pagination_wrapper_class]").length, 2)
  assert.equal(fixture.pageSizeSelect("top").value, "10")
  fixture.gap("top").focus()
  fixture.gap("top").value = "8"
  fixture.gap("top").blur()
  assert.deepEqual(fixture.requests, [{target: "17", event: "goto_page", payload: {page: 8}}])
})

test("initial one-page summaries use the selected preset and fixed sizes remain noninteractive", () => {
  for (const selected of [10, 100]) {
    const fixture = openCollection(1, 1, {summary: {count: 7, selected}})
    const ids = []
    for (const position of ["top", "bottom"]) {
      const select = fixture.pageSizeSelect(position)
      assert.equal(select.value, String(selected))
      assert.equal(select.getAttribute("aria-label"), "Entries per page")
      ids.push(select.id)
    }
    assert.equal(new Set(ids).size, 2)
  }
  for (const count of [7, 0]) {
    const fixture = openCollection(1, 1, {summary: {count, pageSize: 100, options: []}})
    for (const bar of [fixture.context.topPagination, fixture.context.summary]) {
      assert.equal(bar.querySelector("[data-cinder-page-size]"), null)
      assert.equal(bar.querySelector("[data-key=pagination_count_class]").textContent, `(showing ${count ? 1 : 0}-${count} of ${count})`)
    }
  }
})

test("one-page selectors retain focus and values across unchanged updates and new result counts", () => {
  for (const position of ["top", "bottom"]) {
    const fixture = openCollection(1, 1, {summary: {count: 7, selected: 100}})
    const select = fixture.pageSizeSelect(position)
    select.focus()
    for (let update = 0; update < 3; update++) fixture.context.updated()
    assert.equal(fixture.pageSizeSelect(position), select)
    assert.equal(document.activeElement, select)
    fixture.patchResults(3)
    assert.equal(document.activeElement, fixture.pageSizeSelect(position))
    assert.equal(fixture.pageSizeSelect(position).value, "100")
    assert.equal(fixture.context.topPagination.querySelector("[data-key=pagination_count_class]").childNodes.at(-1).textContent, " of 3)")
    assert.deepEqual(fixture.requests, [])
  }
})

test("summary template updates refresh both bars without losing preset focus or loading feedback", () => {
  for (const position of ["top", "bottom"]) {
    for (const loading of [false, true]) {
      const fixture = openCollection(1, 1, {summary: {count: 7, selected: 100}})
      if (loading) fixture.setLoading(true)
      fixture.pageSizeSelect(position).focus()
      const source = fixture.summaryTemplate.content.firstElementChild
      source.className = "summary-updated"
      const sourceInfo = source.querySelector("[data-key=pagination_info_class]")
      sourceInfo.className = "info-updated"
      sourceInfo.childNodes[0].textContent = "Results page 1 of 1"
      source.querySelector("[data-key=pagination_count_class]").textContent = "(displaying {start}-{count} from {count})"
      source.querySelector("[data-key=pagination_current_class]").className = "current-updated"
      fixture.summaryTemplate.dataset.cinderPageSizeClass = "input-native-select preset-updated"
      fixture.context.updated()

      for (const bar of [fixture.context.topPagination, fixture.context.summary]) {
        assert.equal(bar.className, "summary-updated")
        assert.equal(bar.querySelector("[data-key=pagination_info_class]").className, "info-updated")
        assert.match(bar.querySelector("[data-key=pagination_info_class]").textContent, /^Results page 1 of 1/)
        const count = bar.querySelector("[data-key=pagination_count_class]")
        const select = count.querySelector("[data-cinder-page-size]")
        assert.equal(select.value, "100")
        assert.equal(select.className, "input-native-select preset-updated")
        assert.equal(count.childNodes.map(node => node === select ? select.value : node.textContent).join(""), "(displaying 100 from 7)")
        assert.equal(bar.querySelector("[data-key=pagination_current_class]").className, "current-updated")
        assert.equal(bar.querySelector("[data-cinder-loading]")?.textContent, loading ? "Loading..." : undefined)
      }
      assert.equal(document.activeElement, fixture.pageSizeSelect(position))
      if (loading) assert.equal(fixture.loading.hidden, true)

      fixture.summaryTemplate.dataset.cinderPageSizeClass = "input-native-select preset-refreshed"
      fixture.context.updated()
      for (const bar of [fixture.context.topPagination, fixture.context.summary]) {
        assert.equal(bar.querySelector("[data-cinder-page-size]").className, "input-native-select preset-refreshed")
        assert.equal(bar.querySelector("[data-cinder-page-size]").value, "100")
      }
      assert.equal(document.activeElement, fixture.pageSizeSelect(position))
      assert.deepEqual(fixture.requests, [])
    }
  }
})

test("replacing the collection or server page-size configuration resets the summary preset", () => {
  const fixture = openCollection(1, 1, {summary: {count: 7, selected: 100}})
  fixture.collection.setAttribute("data-phx-component", "18")
  fixture.configureSummary()
  fixture.context.updated()
  for (const position of ["top", "bottom"]) {
    assert.equal(fixture.pageSizeSelect(position).value, "10")
    assert.equal(fixture.pageSizeSelect(position).getAttribute("phx-target"), "18")
  }
  fixture.configureSummary({pageSize: 40, selected: 40, options: [10, 40, 80]})
  fixture.context.updated()
  for (const position of ["top", "bottom"]) {
    assert.equal(fixture.pageSizeSelect(position).value, "40")
    assert.deepEqual(fixture.pageSizeSelect(position).options.map(option => option.value), ["10", "40", "80"])
  }
  fixture.configureSummary({pageSize: 100, options: []})
  fixture.context.updated()
  for (const bar of [fixture.context.topPagination, fixture.context.summary]) {
    const count = bar.querySelector("[data-key=pagination_count_class]")
    assert.equal(bar.querySelector("[data-cinder-page-size]"), null)
    assert.equal(count.textContent, "(showing 1-7 of 7)")
    assert.equal(count.hasAttribute("data-core-input"), false)
    assert.equal(bar.querySelector("[aria-current=page]").textContent, "1")
  }
})

test("either page-size selector can expand to one page and return to multiple pages", () => {
  for (const position of ["top", "bottom"]) {
    const fixture = openCollection(1, 2, {count: 19})
    fixture.configureSummary()
    const select = fixture.pageSizeSelect(position)
    select.focus()
    select.value = "100"
    select.dispatchEvent(new Event("change", {bubbles: true}))
    fixture.patchResults(19)
    const bar = position === "top" ? fixture.context.topPagination : fixture.context.summary
    const replacement = fixture.pageSizeSelect(position)
    assert.equal(document.activeElement, replacement)
    for (const summary of [fixture.context.topPagination, fixture.context.summary]) {
      const summarySelect = summary.querySelector("[data-cinder-page-size]")
      const count = summary.querySelector("[data-key=pagination_count_class]")
      assert.equal(summarySelect.value, "100")
      assert.equal(count.childNodes.map(node => node === summarySelect ? summarySelect.value : node.textContent).join(""), "(showing 100 of 19)")
    }
    assert.equal(bar.querySelector("[aria-current=page]").tagName, "SPAN")
    replacement.value = "10"
    replacement.dispatchEvent(new Event("change", {bubbles: true}))
    fixture.patch(1, 2, {pageSize: 10, count: 19})
    assert.equal(fixture.context.summary, null)
    assert.equal(fixture.pageSizeSelect("top").value, "10")
    assert.equal(fixture.pageSizeSelect("bottom").value, "10")
    assert.equal(document.activeElement, fixture.pageSizeSelect(position))
    assert.deepEqual(fixture.requests, [
      {target: "17", event: "change_page_size", payload: {page_size: "100"}},
      {target: "17", event: "change_page_size", payload: {page_size: "10"}},
    ])
  }
})

test("show_pagination=false removes native and generated bars without another flag", () => {
  const disabled = openCollection(1, 1, {paginationEnabled: false, summary: {count: 7}})
  assert.equal(disabled.context.summary, null)
  assert.equal(disabled.context.topPagination, null)
  const fixture = openCollection(1, 1, {summary: {count: 7}})
  fixture.pageSizeSelect().value = "100"
  fixture.pageSizeSelect().dispatchEvent(new Event("change", {bubbles: true}))
  fixture.context.updated()
  fixture.summaryTemplate.remove()
  fixture.context.updated()
  assert.equal(fixture.context.summary, null)
  assert.equal(fixture.context.topPagination, null)
  assert.equal(fixture.root.querySelectorAll("[data-key=pagination_wrapper_class]").length, 0)
  fixture.configureSummary()
  assert.equal(fixture.root.querySelectorAll("[data-key=pagination_wrapper_class]").length, 2)
  assert.equal(fixture.pageSizeSelect("top").value, "100")
  assert.equal(fixture.pageSizeSelect("bottom").value, "100")

  const multiple = openCollection(1, 2, {count: 19})
  multiple.summaryTemplate.remove()
  multiple.patchResults(10)
  assert.equal(multiple.context.summary, null)
  assert.equal(multiple.context.topPagination, null)
  assert.equal(multiple.root.querySelectorAll("[data-key=pagination_wrapper_class]").length, 0)
  assert.equal(multiple.results.children.length, 10)
  multiple.patch(1, 2, {count: 19})
  multiple.configureSummary()
  assert.equal(multiple.root.querySelectorAll("[data-key=pagination_wrapper_class]").length, 2)
})

test("initial loading waits for records and later loading preserves the last one-page count", () => {
  const fixture = openCollection(1, 1, {summary: {count: 0, loading: true, selected: 100}})
  assert.equal(fixture.context.topPagination, null)
  assert.equal(fixture.loading.hidden, false)
  assert.equal(fixture.root.querySelectorAll("[data-key=pagination_wrapper_class]").length, 0)
  fixture.patchResults(7)
  fixture.setLoading(true)
  assert.equal(fixture.loading.hidden, true)
  for (const bar of [fixture.context.topPagination, fixture.context.summary]) {
    assert.equal(bar.querySelector("[data-key=pagination_count_class]").childNodes.at(-1).textContent, " of 7)")
    assert.equal(bar.querySelector("[data-cinder-page-size]").value, "100")
    assert.equal(bar.querySelector("[data-cinder-loading]").textContent, "Loading...")
  }
  fixture.patchResults(3)
  assert.equal(fixture.root.querySelectorAll("[data-cinder-loading]").length, 0)
  assert.equal(fixture.context.topPagination.querySelector("[data-key=pagination_count_class]").childNodes.at(-1).textContent, " of 3)")
  assert.equal(fixture.pageSizeSelect("top").value, "100")
})

test("query errors remove one-page summaries and successful results restore them", () => {
  const fixture = openCollection(1, 1, {summary: {count: 7, layout: "list", selected: 100}})
  fixture.patchResults(0, {error: true})
  assert.equal(fixture.context.summary, null)
  assert.equal(fixture.context.topPagination, null)
  assert.equal(fixture.root.querySelectorAll("[data-key=pagination_wrapper_class]").length, 0)
  fixture.patchResults(2)
  assert.equal(fixture.context.topPagination.querySelector("[data-key=pagination_count_class]").childNodes.at(-1).textContent, " of 2)")
  assert.equal(fixture.pageSizeSelect("top").value, "100")
  assert.equal(fixture.pageSizeSelect("bottom").value, "100")
})

test("destroying a one-page collection removes generated bars and restores native loading feedback", () => {
  const fixture = openCollection(1, 1, {summary: {count: 7}})
  fixture.setLoading(true)
  fixture.context.destroyed()
  fixture.destroyed = true
  assert.equal(fixture.root.querySelectorAll("[data-key=pagination_wrapper_class]").length, 0)
  assert.equal(fixture.root.querySelectorAll("[data-cinder-loading]").length, 0)
  assert.equal(fixture.loading.hidden, false)
  assert.equal(fixture.summaryTemplate.isConnected, true)
  assert.equal(fixture.results.children.length, 7)
  assert.equal(fixture.context.observer.observing, false)
  for (const name of ["focusin", "focusout", "keydown", "change"]) assert.equal(getEventListeners(fixture.root, name).length, 0)
})

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

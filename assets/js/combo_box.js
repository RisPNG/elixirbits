import {PetalComboBox} from "../../deps/petal_components/assets/js/petal_components"

const ComboBox = {
  ...PetalComboBox,

  mounted() {
    PetalComboBox.mounted.call(this)
    if (!this.select || !this.input || !this.panel || !this.list) return
    this.onSelectChange = () => this.syncFromSelect()
    this.select.addEventListener("change", this.onSelectChange)
    this.field = this.el.closest("[data-core-input]")
    if (["select", "combobox"].includes(this.field?.dataset.inputType)) {
      this.onClear = event => {
        if (event.target !== this.field) return
        event.preventDefault()
        this.onClearClick(event)
      }
      this.field.addEventListener("input:clear", this.onClear)
    }
    if (this.el.classList.contains("core-selection-input")) {
      this.viewport = window.visualViewport
      this.viewport?.addEventListener("resize", this.onReposition)
      this.viewport?.addEventListener("scroll", this.onReposition)
    }
  },

  destroyed() {
    this.select?.removeEventListener("change", this.onSelectChange)
    this.field?.removeEventListener("input:clear", this.onClear)
    this.viewport?.removeEventListener("resize", this.onReposition)
    this.viewport?.removeEventListener("scroll", this.onReposition)
    PetalComboBox.destroyed.call(this)
  },

  openPanel(options = {}) {
    const opening = this.panel.hidden
    PetalComboBox.openPanel.call(this, options)
    if (!opening || !this.el.classList.contains("core-selection-input") || !this.multiple || this.query.trim()) return
    const chosen = this.visibleItems().find(item => item.getAttribute("aria-selected") === "true")
    if (chosen) this.highlight(chosen)
  },

  positionPanel() {
    if (!this.el.classList.contains("core-selection-input")) return PetalComboBox.positionPanel.call(this)
    if (this.panel.hidden) return
    const anchor = this.control || this.trigger
    if (!anchor) return
    const control = anchor.getBoundingClientRect()
    const scrollTop = this.list.scrollTop
    this.panel.removeAttribute("data-flip")
    const panelHeight = this.panel.offsetHeight
    if (!panelHeight || (!control.top && !control.bottom)) return

    const listTop = this.list.getBoundingClientRect().top
    const rowEnds = Array.from(this.list.querySelectorAll("[data-pc-combo-item], [data-pc-combo-create]"))
      .filter(row => !row.hidden)
      .slice(0, 7)
      .map(row => Math.ceil(row.getBoundingClientRect().bottom - listTop + this.list.scrollTop))
    const chrome = panelHeight - this.list.offsetHeight
    const gap = parseFloat(getComputedStyle(this.panel).marginTop) || 0
    const viewportTop = window.visualViewport?.offsetTop || 0
    const viewportHeight = window.visualViewport?.height || window.innerHeight
    const below = viewportTop + viewportHeight - control.bottom - gap
    const above = control.top - viewportTop - gap
    const minimum = chrome + (rowEnds[0] || 0)
    const flip = below < minimum && above > below
    const available = Math.max((flip ? above : below) - chrome, 0)
    const height = rowEnds.filter(end => end <= available).at(-1) ?? Math.min(available, rowEnds[0] || 0)
    this.panel.toggleAttribute("data-flip", flip)
    this.list.style.maxHeight = `${height}px`
    this.list.scrollTop = scrollTop
  },

  filter() {
    const custom = this.el.classList.contains("core-selection-input") && this.createRow
    if (custom) {
      const label = this.createQueryEl.parentElement
      label.className = "pc-combo-box__option-label"
      label.replaceChildren(this.createQueryEl, " (custom value)")
      this.createRow.replaceChildren(label)
      if (this.list.firstElementChild !== this.createRow) this.list.prepend(this.createRow)
    }
    PetalComboBox.filter.call(this)
    if (custom && !this.createRow.hidden) this.highlight(this.createRow, false)
  },

  highlight(item, scroll = true) {
    if (!this.el.classList.contains("core-selection-input")) return PetalComboBox.highlight.call(this, item, scroll)
    PetalComboBox.highlight.call(this, item, false)
    if (!scroll || !item) return
    this.positionPanel()
    const option = item.getBoundingClientRect()
    const list = this.list.getBoundingClientRect()
    if (option.top < list.top) this.list.scrollTop += option.top - list.top
    else if (option.bottom > list.bottom) this.list.scrollTop += option.bottom - list.bottom
  },

  navItems() {
    if (!this.el.classList.contains("core-selection-input")) return PetalComboBox.navItems.call(this)
    const items = this.visibleItems()
    if (this.createRow && !this.createRow.hidden) items.unshift(this.createRow)
    return items
  },

  keydown(event) {
    if (this.el.classList.contains("core-selection-input") && event.key === "Home" && !this.panel.hidden) {
      event.preventDefault()
      this.highlight(this.navItems()[0] || null)
      return
    }
    PetalComboBox.keydown.call(this, event)
  },

  commitFreeText() {
    const raw = this.input.value.trim()
    if (this.el.classList.contains("core-selection-input") && this.items().some(item =>
      item.hasAttribute("data-disabled") && !item.hasAttribute("data-max-blocked") &&
        ((item.dataset.label || "").trim().toLowerCase() === raw.toLowerCase() || item.dataset.value === raw)
    )) return
    PetalComboBox.commitFreeText.call(this)
  },

  ensureOption(value, label) {
    const option = PetalComboBox.ensureOption.call(this, value, label)
    if (this.el.classList.contains("core-selection-input") && !this.items().some(item => item.dataset.value === value)) {
      const row = document.createElement("div")
      row.id = `${this.el.id}-custom-${encodeURIComponent(value)}`
      row.className = "pc-combo-box__option"
      row.setAttribute("role", "option")
      row.setAttribute("data-pc-combo-item", "")
      row.setAttribute("aria-selected", "false")
      row.dataset.value = value
      row.dataset.label = option.textContent.trim()
      const text = document.createElement("span")
      text.className = "pc-combo-box__option-label"
      text.textContent = row.dataset.label
      const check = document.createElement("span")
      check.className = "hero-check-mini pc-combo-box__check"
      row.append(text, check)
      this.list.append(row)
    }
    return option
  },
}

export default ComboBox

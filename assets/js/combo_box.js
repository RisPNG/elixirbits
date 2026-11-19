import {PetalComboBox} from "../../deps/petal_components/assets/js/petal_components"
import {hasAnchorPositioning, slidePopover} from "./popover_placement.js"

const ComboBox = {
  ...PetalComboBox,

  mounted() {
    this.field = this.el.closest("[data-core-input]")
    PetalComboBox.mounted.call(this)
    if (!this.select || !this.input || !this.panel || !this.list) return
    this.onSelectChange = () => this.syncFromSelect()
    this.select.addEventListener("change", this.onSelectChange)
    if (["select", "combobox"].includes(this.field?.dataset.inputType)) {
      this.onClear = event => {
        if (event.target !== this.field) return
        event.preventDefault()
        this.onClearClick(event)
      }
      this.field.addEventListener("input:clear", this.onClear)
      this.onPillRemove = event => {
        const button = event.target.closest("[data-pc-combo-chip-remove]")
        if (button && this.chips?.contains(button) && !button.matches(":disabled")) {
          this.setSelected(button.dataset.value, false)
        }
      }
      this.field.addEventListener("click", this.onPillRemove)
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
    this.field?.removeEventListener("click", this.onPillRemove)
    this.viewport?.removeEventListener("resize", this.onReposition)
    this.viewport?.removeEventListener("scroll", this.onReposition)
    PetalComboBox.destroyed.call(this)
  },

  syncChips() {
    const pills = this.field?.querySelector("[data-selection-pills]")
    if (!pills) return PetalComboBox.syncChips.call(this)
    this.chips = pills
    const previous = pills.querySelectorAll("[data-pc-combo-chip]")
    const focused = document.activeElement
    PetalComboBox.syncChips.call(this)

    for (const pill of pills.querySelectorAll("[data-pc-combo-chip]")) {
      pill.classList.add("motion-grow")
      const remove = pill.querySelector("[data-pc-combo-chip-remove]")
      remove.disabled = this.select.disabled || pills.dataset.selectionPills === "false"
      remove.tabIndex = 0
    }

    const exiting = []
    for (let index = previous.length - 1; index >= 0; index--) {
      const pill = previous[index]
      if (pills.contains(pill)) continue
      if (pill.contains(focused)) this.trigger.focus({preventScroll: true})
      pill.removeAttribute("data-pc-combo-chip")
      pill.inert = true
      pills.insertBefore(pill, previous[index + 1] || null)
      pill.classList.add("motion-shrink")
      exiting.push(pill)
    }
    for (const pill of exiting) {
      Promise.allSettled(pill.getAnimations().map(animation => animation.finished)).then(() => pill.remove())
    }
  },

  openPanel(options = {}) {
    const opening = this.panel.hidden
    if (opening) {
      this.panel.inert = false
      this.placementKnown = false
    }
    PetalComboBox.openPanel.call(this, options)
    if (!opening || !this.el.classList.contains("core-selection-input") || !this.multiple || this.query.trim()) return
    const chosen = this.visibleItems().find(item => item.getAttribute("aria-selected") === "true")
    if (chosen) this.highlight(chosen)
  },

  closePanel() {
    const open = !this.panel.hidden
    const flip = this.panel.hasAttribute("data-flip")
    const listHeight = this.list.style.maxHeight
    PetalComboBox.closePanel.call(this)
    if (open) {
      this.panel.inert = true
      this.panel.toggleAttribute("data-flip", flip)
      this.list.style.maxHeight = listHeight
    }
  },

  positionPanel() {
    if (this.panel.hidden) return
    const wasFlipped = this.panel.hasAttribute("data-flip")
    const fromTop = this.placementKnown ? this.panel.getBoundingClientRect().top : null

    if (this.el.classList.contains("core-selection-input")) {
      const anchor = this.control || this.trigger
      if (!anchor) return
      const control = anchor.getBoundingClientRect()
      const scrollTop = this.list.scrollTop
      if (!hasAnchorPositioning) this.panel.style.setProperty("--combobox-anchor-width", `${control.width}px`)
      const panelHeight = this.panel.offsetHeight
      if (!panelHeight || (!control.top && !control.bottom)) return

      const rowEnds = Array.from(this.list.querySelectorAll("[data-pc-combo-item], [data-pc-combo-create]"))
        .filter(row => !row.hidden)
        .slice(0, 7)
        .map(row => row.offsetTop + row.offsetHeight)
      const chrome = panelHeight - this.list.offsetHeight
      const style = getComputedStyle(this.panel)
      const gap = parseFloat(style.marginTop) || 0
      const viewport = window.visualViewport
      const viewportTop = viewport?.offsetTop || 0
      const viewportHeight = viewport?.height || window.innerHeight
      const below = viewportTop + viewportHeight - control.bottom - gap
      const above = control.top - viewportTop - gap
      const minimum = chrome + (rowEnds[0] || 0)
      const flip = below < minimum && above > below
      const available = Math.max((flip ? above : below) - chrome, 0)
      const height = rowEnds.filter(end => end <= available).at(-1) ?? Math.min(available, rowEnds[0] || 0)
      this.panel.toggleAttribute("data-flip", flip)
      this.list.style.maxHeight = `${height}px`
      this.list.scrollTop = scrollTop
      if (!hasAnchorPositioning) {
        const viewportLeft = viewport?.offsetLeft || 0
        const viewportWidth = viewport?.width || window.innerWidth
        const width = this.panel.offsetWidth
        const alignRight = this.el.closest("[data-color-space-select]") ? style.direction !== "rtl" : style.direction === "rtl"
        const left = alignRight ? control.right - width : control.left
        this.panel.style.left = `${Math.max(viewportLeft + 8, Math.min(left, viewportLeft + viewportWidth - width - 8))}px`
        this.panel.style.top = `${flip ? control.top - this.panel.offsetHeight - 2 * gap : control.bottom}px`
      }
    } else {
      PetalComboBox.positionPanel.call(this)
    }

    this.placementKnown = true
    if (wasFlipped !== this.panel.hasAttribute("data-flip")) slidePopover(this.panel, fromTop)
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
    const top = item.offsetTop
    const bottom = top + item.offsetHeight
    if (top < this.list.scrollTop) this.list.scrollTop = top
    else if (bottom > this.list.scrollTop + this.list.clientHeight) this.list.scrollTop = bottom - this.list.clientHeight
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

import ComboBox from "./combo_box"

customElements.define("cinder-page-size", class extends HTMLElement {
  connectedCallback() {
    const el = this.querySelector(".core-selection-input")
    el.removeAttribute("phx-hook")
    this.picker = {...ComboBox, el}
    this.picker.mounted()
  }

  disconnectedCallback() {
    this.picker.destroyed()
  }
})

const CinderPagination = {
  mounted() {
    this.onFocusIn = event => {
      this.focusedControl = this.topPagination?.contains(event.target) || event.target.closest("cinder-page-size") ? event.target : null
    }
    this.onFocusOut = event => {
      const input = event.target
      if (this.focusedControl === input) this.focusedControl = null
      if (!input.matches("[data-cinder-pagination-gap]")) return
      const value = input.valueAsNumber
      input.value = ""
      if (!Number.isFinite(value)) return
      const page = Math.max(Number(input.min), Math.min(Number(input.max), Math.trunc(value)))
      this.requestedPage = page === this.displayedPage ? null : page
      this.pushEventTo(input.getAttribute("phx-target"), "goto_page", {page})
    }
    this.onKeyDown = event => {
      if (event.key !== "Enter" || !event.target.matches("[data-cinder-pagination-gap]")) return
      event.preventDefault()
      event.target.blur()
    }
    this.onChange = event => {
      const select = event.target
      if (!select.matches("select") || !select.closest("cinder-page-size")) return
      this.requestedPage = null
      this.pageSize = select.value
      this.pushEventTo(this.component, "change_page_size", {page_size: select.value})
    }
    this.onClick = event => {
      const button = event.target.closest("button[phx-click=goto_page], button[phx-click=next_page], button[phx-click=prev_page]")
      if (!button || button.disabled || !button.closest("[data-key=pagination_wrapper_class]")) return
      const page = button.getAttribute("phx-value-page")
      if (page !== null) this.requestedPage = Number(page)
      else this.requestedPage = button.getAttribute("phx-click") === "next_page" ? "left" : "right"
    }
    this.el.addEventListener("focusin", this.onFocusIn)
    this.el.addEventListener("focusout", this.onFocusOut)
    this.el.addEventListener("keydown", this.onKeyDown)
    this.el.addEventListener("change", this.onChange)
    this.el.addEventListener("click", this.onClick)
    this.observer = new MutationObserver(records => {
      if (records.some(({attributeName, target}) => {
        const element = target.nodeType === 1 ? target : target.parentElement
        return !element?.closest("cinder-page-size") &&
          (attributeName !== "title" || target.matches("[data-key=pagination_nav_class] > span > button[phx-value-page]"))
      })) this.synchronize()
    })
    this.synchronize()
  },

  updated() {
    this.synchronize()
  },

  destroyed() {
    this.observer.disconnect()
    this.el.removeEventListener("focusin", this.onFocusIn)
    this.el.removeEventListener("focusout", this.onFocusOut)
    this.el.removeEventListener("keydown", this.onKeyDown)
    this.el.removeEventListener("change", this.onChange)
    this.el.removeEventListener("click", this.onClick)
    this.pageAnimation?.cancel()
    this.topPagination?.remove()
    this.summary?.remove()
    for (const gap of this.el.querySelectorAll("[data-cinder-pagination-gap]")) gap.remove()
    for (const slot of this.el.querySelectorAll("[data-cinder-page-size-slot]")) {
      slot.replaceWith(document.createTextNode(slot.dataset.cinderPageRange))
    }
    for (const controls of this.el.querySelectorAll("[data-key=page_size_container_class]")) controls.hidden = false
    for (const indicator of this.el.querySelectorAll("[data-cinder-loading]")) indicator.remove()
    for (const loading of this.el.querySelectorAll("[data-key=loading_overlay_class]")) loading.hidden = false
  },

  synchronize() {
    this.observer.disconnect()
    const focused = this.focusedControl
    const restoreFocus = focused && (document.activeElement === focused || (!focused.isConnected && document.activeElement === document.body))
    const focusedTop = this.topPagination?.contains(focused)
    const focusedPicker = focused?.closest("cinder-page-size")
    let focusTarget
    const collection = this.el.querySelector("[data-key=container_class]")
    let pagination = collection?.querySelector(":scope > [data-key=pagination_wrapper_class]:not([data-cinder-pagination])")
    const loading = collection?.querySelector(":scope > [data-key=loading_overlay_class]")
    const summaryTemplate = this.el.querySelector("template[data-cinder-summary]")
    const pageSizeSource = this.el.querySelector("template[data-cinder-page-size-template]")?.content
    const component = collection?.getAttribute("data-phx-component")
    if (this.component !== component) {
      this.component = component
      this.pageSizeSource = null
      this.pageSize = null
      this.displayedPage = null
      this.firstRow = null
      this.requestedPage = null
      this.pageAnimation?.cancel()
      this.summary?.remove()
      this.summary = null
    }
    const pageSizeChanged = pageSizeSource && !this.pageSizeSource?.isEqualNode(pageSizeSource)
    if (pageSizeChanged) {
      const preset = pageSizeSource.querySelector("select")
      if (this.pageSizeSource?.querySelector("select").value !== preset.value || !Array.from(preset.options).some(option => option.value === this.pageSize)) {
        this.pageSize = preset.value
      }
      this.pageSizeSource = pageSizeSource.cloneNode(true)
    }
    if (loading) loading.hidden = false

    if (!loading) {
      const body = collection?.querySelector("[data-key=tbody_class], .identity-grid[data-key=grid_container_class]")
      const current = pagination?.querySelector("[data-key=pagination_current_class]")
      const page = current ? Number(current.textContent) : null
      const firstRow = body?.querySelector("[data-item-id]")?.dataset.itemId
      const request = this.requestedPage
      let direction
      if (typeof request === "number" && Number.isFinite(this.displayedPage) && page === request && page !== this.displayedPage) {
        direction = page > this.displayedPage ? "left" : "right"
      } else if (typeof request === "string" && firstRow && this.firstRow && firstRow !== this.firstRow) {
        direction = request
      }

      if (typeof request === "number" ? page !== this.displayedPage : firstRow !== this.firstRow) {
        this.requestedPage = null
      }
      this.displayedPage = page
      this.firstRow = firstRow
      if (body && direction && !matchMedia("(prefers-reduced-motion: reduce)").matches) {
        const style = getComputedStyle(body)
        this.pageAnimation?.cancel()
        this.pageAnimation = body.animate(
          [{translate: direction === "right" ? "-1.5rem" : "1.5rem", opacity: 0.6}, {translate: "0", opacity: 1}],
          {duration: parseFloat(style.getPropertyValue("--motion-duration")), easing: style.getPropertyValue("--motion-ease").trim()},
        )
      }
    }
    if (pagination || !summaryTemplate || !collection || collection.querySelector("[data-key=error_class]")) {
      this.summary?.remove()
      this.summary = null
    } else if (!loading || this.summary) {
      const results = collection.querySelector("[data-key=tbody_class], [data-key=list_container_class], [data-key=grid_container_class]")
      if (results) {
        let total = this.summary?.dataset.cinderResultCount
        const source = summaryTemplate.content.firstElementChild
        if (!this.summarySource?.isEqualNode(source)) {
          this.summary?.remove()
          this.summary = null
          this.summarySource = source.cloneNode(true)
        }
        this.summary ??= source.cloneNode(true)
        this.summary.id = `${this.el.id}-pagination-bottom`
        this.summary.dataset.cinderPagination = "summary"
        this.summary.setAttribute("phx-update", "ignore")
        if (!loading) total = String(results.querySelectorAll(":scope > [data-key]:not([data-key=empty_class]):not([data-key=error_class])").length)
        if (this.summary.dataset.cinderResultCount !== total) {
          this.summary.querySelector("[data-key=pagination_count_class]").textContent = source.querySelector("[data-key=pagination_count_class]").textContent.replaceAll("{start}", Number(total) > 0 ? "1" : "0").replaceAll("{count}", total)
          this.summary.dataset.cinderResultCount = total
        }
        if (this.summary.parentElement !== collection) collection.append(this.summary)
        pagination = this.summary
      }
    }

    if (pagination) {
      const navigation = pagination.querySelector("[data-key=pagination_nav_class]")
      const count = pagination.querySelector("[data-key=pagination_count_class]")
      const pageSizes = pagination.querySelector("[data-key=page_size_container_class]")
      const trigger = pageSizes?.querySelector("[data-key=page_size_dropdown_class]")
      if (trigger) this.pageSize = trigger.textContent.trim()

      pagination.querySelector("[data-cinder-loading]")?.remove()
      if (loading && count) {
        const indicator = loading.cloneNode(true)
        indicator.className = "inline-grid align-middle ml-2"
        indicator.dataset.cinderLoading = ""
        indicator.hidden = false
        count.after(indicator)
        loading.hidden = true
      }

      let sizeSlot = count?.querySelector("[data-cinder-page-size-slot]")
      if (count && pageSizeSource) {
        if (!sizeSlot) {
          const [, before, range, after] = count.textContent.match(/^(.*?)(\d+-\d+)(.*)$/s)
          sizeSlot = document.createElement("span")
          sizeSlot.dataset.cinderPageSizeSlot = ""
          sizeSlot.dataset.cinderPageRange = range
          count.replaceChildren(document.createTextNode(before), sizeSlot, document.createTextNode(after))
        }
        if (pageSizes) pageSizes.hidden = true
      } else if (sizeSlot) {
        sizeSlot.replaceWith(document.createTextNode(sizeSlot.dataset.cinderPageRange))
        sizeSlot = null
        if (pageSizes) pageSizes.hidden = false
      }

      for (const button of navigation.querySelectorAll(":scope > button[phx-value-page]")) {
        const iconName = {
          "\u00ab": "hero-chevron-double-left",
          "\u2039": "hero-chevron-left",
          "\u203a": "hero-chevron-right",
          "\u00bb": "hero-chevron-double-right",
        }[button.textContent.trim()]
        if (!iconName) continue
        const icon = document.createElement("span")
        icon.className = `${iconName} size-5`
        icon.setAttribute("aria-hidden", "true")
        button.setAttribute("aria-label", button.getAttribute("title"))
        button.replaceChildren(icon)
      }

      const pages = Array.from(navigation.children).filter(element =>
        element.tagName === "SPAN" && element.querySelector("[data-key=pagination_current_class], button[phx-value-page]")
      )

      if (pages.length > 0) {
        for (const page of pages) {
          const button = page.querySelector("button[phx-value-page]")
          const label = button?.getAttribute("title") ?? button?.getAttribute("data-tooltip")
          if (label == null) continue
          button.setAttribute("aria-label", label)
          button.removeAttribute("title")
          button.removeAttribute("data-tooltip")
        }

        const firstPage = Number(pages[0].textContent.trim())
        const lastPage = Number(pages.at(-1).textContent.trim())
        const button = navigation.querySelector("button[phx-value-page]")
        const totalPages = Math.max(lastPage, ...Array.from(navigation.querySelectorAll("button[phx-value-page]"), button => Number(button.getAttribute("phx-value-page"))))

        for (const [side, omitted] of [["before", firstPage > 1], ["after", totalPages > lastPage]]) {
          let gap = navigation.querySelector(`[data-cinder-pagination-gap=${side}]`)
          if (!omitted) {
            gap?.remove()
            continue
          }
          gap ??= document.createElement("input")
          gap.className = `${button.className} w-11 text-center placeholder:text-subcontent focus:outline-none focus:ring-2 focus:ring-brand appearance-textfield [&::-webkit-inner-spin-button]:appearance-none [&::-webkit-outer-spin-button]:appearance-none`
          gap.dataset.cinderPaginationGap = side
          gap.type = "number"
          gap.inputMode = "numeric"
          gap.placeholder = "..."
          gap.min = "1"
          gap.max = String(totalPages)
          gap.step = "1"
          gap.setAttribute("aria-label", "Go to page")
          gap.setAttribute("phx-target", button.getAttribute("phx-target"))
          if (side === "before" && pages[0].previousElementSibling !== gap) pages[0].before(gap)
          else if (side === "after" && pages.at(-1).nextElementSibling !== gap) pages.at(-1).after(gap)
        }
      }

      navigation.setAttribute("role", "navigation")
      navigation.setAttribute("aria-label", "Pagination below results")
      navigation.querySelector("[data-key=pagination_current_class]")?.setAttribute("aria-current", "page")

      const top = pagination.cloneNode(true)
      top.id = `${this.el.id}-pagination-top`
      top.dataset.cinderPagination = "top"
      top.setAttribute("phx-update", "ignore")
      top.querySelector("[data-key=page_size_container_class]")?.remove()
      top.querySelector("[data-cinder-page-size-slot]")?.replaceChildren()
      top.querySelector("[data-key=pagination_nav_class]").setAttribute("aria-label", "Pagination above results")

      for (const copy of [top, this.summary, ...pagination.querySelectorAll("[data-cinder-loading]")].filter(Boolean)) {
        for (const element of [copy, ...copy.querySelectorAll("*")]) {
          for (const attribute of Array.from(element.attributes)) {
            if (attribute.name.startsWith("data-phx-")) element.removeAttribute(attribute.name)
          }
          element.classList.remove("phx-click-loading")
        }
      }

      if (!this.topPagination || !this.topSource.isEqualNode(top)) {
        for (const input of this.topPagination?.querySelectorAll("[data-cinder-pagination-gap]") || []) {
          const replacement = top.querySelector(`[data-cinder-pagination-gap=${input.dataset.cinderPaginationGap}]`)
          if (replacement) replacement.value = input.value
        }
        this.topPagination?.remove()
        this.topPagination = top
        this.topSource = top.cloneNode(true)
        if (restoreFocus && focusedTop) {
          focusTarget = (focused.matches("[data-cinder-pagination-gap]") && top.querySelector(`[data-cinder-pagination-gap=${focused.dataset.cinderPaginationGap}]`)) || Array.from(top.querySelectorAll("button")).find(button =>
            !button.disabled && button.textContent === focused.textContent && button.getAttribute("title") === focused.getAttribute("title") && button.getAttribute("phx-click") === focused.getAttribute("phx-click")
          ) || top.querySelector("[aria-current=page]") || top.querySelector("[data-key=pagination_nav_class]")
        }
      }

      const controls = collection.querySelector(":scope > [data-key=controls_class]")
      if (controls) {
        if (controls.nextElementSibling !== this.topPagination) controls.after(this.topPagination)
      } else if (collection.firstElementChild !== this.topPagination) {
        collection.prepend(this.topPagination)
      }
      if (sizeSlot) {
        for (const [position, slot] of [["top", this.topPagination.querySelector("[data-cinder-page-size-slot]")], ["bottom", sizeSlot]]) {
          if (!slot.firstElementChild || pageSizeChanged) {
            slot.replaceChildren(pageSizeSource.querySelector(`[data-cinder-page-size=${position}]`).cloneNode(true))
          }
          const select = slot.querySelector("select")
          if (select.value !== this.pageSize) {
            select.value = this.pageSize
            select.dispatchEvent(new Event("change"))
          }
        }
      }
      if (restoreFocus && focusedPicker && !focused.isConnected) {
        const bar = focusedPicker.dataset.cinderPageSize === "top" ? this.topPagination : pagination
        focusTarget = bar.querySelector("[data-pc-combo-trigger]") || bar.querySelector("[aria-current=page]")
      }
      if (focusTarget) {
        if (!["BUTTON", "INPUT", "SELECT"].includes(focusTarget.tagName)) focusTarget.setAttribute("tabindex", "-1")
        focusTarget.focus({preventScroll: true})
      }
    } else {
      this.topPagination?.remove()
      this.topPagination = null
      this.focusedControl = null
    }

    this.observer.observe(this.el, {childList: true, subtree: true, characterData: true, attributes: true, attributeFilter: ["phx-value-page", "disabled", "title"]})
  },
}

export default CinderPagination

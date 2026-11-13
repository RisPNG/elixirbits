const CinderPagination = {
  mounted() {
    this.onFocusIn = event => {
      this.focusedControl = this.topPagination?.contains(event.target) || event.target.matches("[data-cinder-page-size]") ? event.target : null
    }
    this.onFocusOut = event => {
      const input = event.target
      if (this.focusedControl === input) this.focusedControl = null
      if (!input.matches("[data-cinder-pagination-gap]")) return
      const value = input.valueAsNumber
      input.value = ""
      if (!Number.isFinite(value)) return
      const page = Math.max(Number(input.min), Math.min(Number(input.max), Math.trunc(value)))
      this.pushEventTo(input.getAttribute("phx-target"), "goto_page", {page})
    }
    this.onKeyDown = event => {
      if (event.key !== "Enter" || !event.target.matches("[data-cinder-pagination-gap]")) return
      event.preventDefault()
      event.target.blur()
    }
    this.onChange = event => {
      const select = event.target
      if (!select.matches("[data-cinder-page-size]")) return
      this.pageSize = select.value
      this.pushEventTo(select.getAttribute("phx-target"), "change_page_size", {page_size: select.value})
    }
    this.el.addEventListener("focusin", this.onFocusIn)
    this.el.addEventListener("focusout", this.onFocusOut)
    this.el.addEventListener("keydown", this.onKeyDown)
    this.el.addEventListener("change", this.onChange)
    this.observer = new MutationObserver(() => this.synchronize())
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
    this.topPagination?.remove()
    this.summary?.remove()
    for (const gap of this.el.querySelectorAll("[data-cinder-pagination-gap]")) gap.remove()
    for (const select of this.el.querySelectorAll("[data-cinder-page-size]")) {
      select.parentElement.removeAttribute("data-core-input")
      select.replaceWith(document.createTextNode(select.dataset.cinderPageRange))
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
    let focusTarget
    const collection = this.el.querySelector("[data-key=container_class]")
    let pagination = collection?.querySelector(":scope > [data-key=pagination_wrapper_class]:not([data-cinder-pagination])")
    const loading = collection?.querySelector(":scope > [data-key=loading_overlay_class]")
    const summaryTemplate = this.el.querySelector("template[data-cinder-summary]")
    const pageSizeConfigData = summaryTemplate?.dataset.cinderPageSizeConfig
    const pageSizeConfig = pageSizeConfigData && JSON.parse(pageSizeConfigData)
    const component = collection?.getAttribute("data-phx-component")
    if (this.component !== component) {
      this.component = component
      this.pageSizeConfig = null
      this.pageSize = null
      this.summary?.remove()
      this.summary = null
    }
    if (pageSizeConfig && this.pageSizeConfig !== pageSizeConfigData) {
      this.pageSizeConfig = pageSizeConfigData
      this.pageSize = String(pageSizeConfig.selected_page_size)
    }
    if (loading) loading.hidden = false

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
      const sizeOptions = pageSizes?.querySelectorAll("button[phx-value-page_size]")
      const trigger = pageSizes?.querySelector("[data-key=page_size_dropdown_class]")
      const options = sizeOptions?.length ? Array.from(sizeOptions, button => button.getAttribute("phx-value-page_size")) : pagination === this.summary && pageSizeConfig.configurable ? pageSizeConfig.page_size_options.map(String) : []
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

      if (count && options.length) {
        let select = count.querySelector("[data-cinder-page-size]")

        if (!select) {
          const [, before, range, after] = count.textContent.match(/^(.*?)(\d+-\d+)(.*)$/s)
          select = document.createElement("select")
          select.id = `${this.el.id}-page-size-bottom`
          select.dataset.cinderPageSize = ""
          select.dataset.cinderPageRange = range
          select.dataset.inputText = ""
          select.setAttribute("aria-label", "Entries per page")
          select.setAttribute("phx-target", sizeOptions?.[0]?.getAttribute("phx-target") || component)
          count.replaceChildren(document.createTextNode(before), select, document.createTextNode(after))
          count.dataset.coreInput = ""
        }

        select.className = trigger?.className || summaryTemplate.dataset.cinderPageSizeClass
        if (select.options.length !== options.length || options.some((size, index) => select.options[index].value !== size)) {
          select.replaceChildren()
          for (const size of options) {
            const option = document.createElement("option")
            option.value = size
            option.textContent = size
            select.append(option)
          }
        }

        const selected = this.pageSize
        for (const option of select.querySelectorAll("option")) {
          if (option.value === selected) option.setAttribute("selected", "")
          else option.removeAttribute("selected")
        }
        select.value = selected
        if (pageSizes) pageSizes.hidden = true
      } else if (count?.querySelector("[data-cinder-page-size]")) {
        const select = count.querySelector("[data-cinder-page-size]")
        count.removeAttribute("data-core-input")
        select.replaceWith(document.createTextNode(select.dataset.cinderPageRange))
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
      const topSize = top.querySelector("[data-cinder-page-size]")
      if (topSize) topSize.id = `${this.el.id}-page-size-top`
      top.querySelector("[data-key=pagination_nav_class]").setAttribute("aria-label", "Pagination above results")

      for (const copy of [top, this.summary, ...pagination.querySelectorAll("[data-cinder-loading]")].filter(Boolean)) {
        for (const element of [copy, ...copy.querySelectorAll("*")]) {
          for (const attribute of Array.from(element.attributes)) {
            if (attribute.name.startsWith("data-phx-")) element.removeAttribute(attribute.name)
          }
          element.classList.remove("phx-click-loading")
        }
      }

      if (!this.topPagination?.isEqualNode(top)) {
        for (const input of this.topPagination?.querySelectorAll("[data-cinder-pagination-gap]") || []) {
          const replacement = top.querySelector(`[data-cinder-pagination-gap=${input.dataset.cinderPaginationGap}]`)
          if (replacement) replacement.value = input.value
        }
        this.topPagination?.remove()
        this.topPagination = top
        if (restoreFocus && focusedTop) {
          focusTarget = (focused.matches("[data-cinder-pagination-gap]") && top.querySelector(`[data-cinder-pagination-gap=${focused.dataset.cinderPaginationGap}]`)) || Array.from(top.querySelectorAll("button")).find(button =>
            !button.disabled && button.textContent === focused.textContent && button.getAttribute("title") === focused.getAttribute("title") && button.getAttribute("phx-click") === focused.getAttribute("phx-click")
          ) || top.querySelector("[aria-current=page]") || top.querySelector("[data-key=pagination_nav_class]")
        }
      }

      if (restoreFocus && focused.matches("[data-cinder-page-size]")) {
        const bar = focusedTop ? this.topPagination : pagination
        focusTarget = bar.querySelector("[data-cinder-page-size]") || bar.querySelector("[aria-current=page]")
      }

      const controls = collection.querySelector(":scope > [data-key=controls_class]")
      if (controls) {
        if (controls.nextElementSibling !== this.topPagination) controls.after(this.topPagination)
      } else if (collection.firstElementChild !== this.topPagination) {
        collection.prepend(this.topPagination)
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

    this.observer.observe(this.el, {childList: true, subtree: true, characterData: true, attributes: true, attributeFilter: ["phx-value-page", "disabled"]})
  },
}

export default CinderPagination

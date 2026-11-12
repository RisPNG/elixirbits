const CinderPagination = {
  mounted() {
    this.onFocusIn = event => {
      this.focusedControl = this.topPagination?.contains(event.target) ? event.target : null
    }
    this.onFocusOut = event => {
      const input = event.target
      if (!input.matches("[data-cinder-pagination-gap]")) return
      if (this.focusedControl === input) this.focusedControl = null
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
    this.el.addEventListener("focusin", this.onFocusIn)
    this.el.addEventListener("focusout", this.onFocusOut)
    this.el.addEventListener("keydown", this.onKeyDown)
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
    this.topPagination?.remove()
    for (const gap of this.el.querySelectorAll("[data-cinder-pagination-gap]")) gap.remove()
  },

  synchronize() {
    this.observer.disconnect()
    const collection = this.el.querySelector("[data-key=container_class]")
    const pagination = collection?.querySelector(":scope > [data-key=pagination_wrapper_class]:not([data-cinder-pagination])")

    if (pagination) {
      const navigation = pagination.querySelector("[data-key=pagination_nav_class]")

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
      top.querySelector("[data-key=pagination_nav_class]").setAttribute("aria-label", "Pagination above results")

      for (const element of [top, ...top.querySelectorAll("*")]) {
        for (const attribute of Array.from(element.attributes)) {
          if (attribute.name.startsWith("data-phx-")) element.removeAttribute(attribute.name)
        }
        element.classList.remove("phx-click-loading")
      }

      let focusTarget
      if (!this.topPagination?.isEqualNode(top)) {
        const focused = this.focusedControl
        const restoreFocus = focused && (document.activeElement === focused || (!focused.isConnected && document.activeElement === document.body))
        for (const input of this.topPagination?.querySelectorAll("[data-cinder-pagination-gap]") || []) {
          const replacement = top.querySelector(`[data-cinder-pagination-gap=${input.dataset.cinderPaginationGap}]`)
          if (replacement) replacement.value = input.value
        }
        this.topPagination?.remove()
        this.topPagination = top
        if (restoreFocus) {
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
      if (focusTarget) {
        if (!["BUTTON", "INPUT"].includes(focusTarget.tagName)) focusTarget.setAttribute("tabindex", "-1")
        focusTarget.focus({preventScroll: true})
      }
    } else {
      this.topPagination?.remove()
      this.topPagination = null
    }

    this.observer.observe(this.el, {childList: true, subtree: true, characterData: true, attributes: true, attributeFilter: ["phx-value-page", "disabled"]})
  },
}

export default CinderPagination

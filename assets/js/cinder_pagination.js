const CinderPagination = {
  mounted() {
    this.onFocusIn = event => {
      this.focusedControl = this.topPagination?.contains(event.target) ? event.target : null
    }
    this.el.addEventListener("focusin", this.onFocusIn)
    this.observer = new MutationObserver(() => this.synchronize())
    this.synchronize()
  },

  updated() {
    this.synchronize()
  },

  destroyed() {
    this.observer.disconnect()
    this.el.removeEventListener("focusin", this.onFocusIn)
    this.topPagination?.remove()
    for (const gap of this.el.querySelectorAll("[data-cinder-pagination-gap]")) gap.remove()
  },

  synchronize() {
    this.observer.disconnect()
    const collection = this.el.querySelector("[data-key=container_class]")
    const pagination = collection?.querySelector(":scope > [data-key=pagination_wrapper_class]:not([data-cinder-pagination])")

    if (pagination) {
      const navigation = pagination.querySelector("[data-key=pagination_nav_class]")
      for (const gap of navigation.querySelectorAll("[data-cinder-pagination-gap]")) gap.remove()

      const pages = Array.from(navigation.children).filter(element =>
        element.tagName === "SPAN" && element.querySelector("[data-key=pagination_current_class], button[phx-value-page]")
      )

      if (pages.length > 0) {
        const firstPage = Number(pages[0].textContent.trim())
        const lastPage = Number(pages.at(-1).textContent.trim())
        const lastTarget = Math.max(...Array.from(navigation.querySelectorAll("button[phx-value-page]"), button => Number(button.getAttribute("phx-value-page"))))

        for (const [side, omitted] of [["before", firstPage > 1], ["after", lastTarget > lastPage]]) {
          if (!omitted) continue
          const gap = document.createElement("span")
          gap.className = "inline-grid grid-cols-[1fr] place-items-center min-h-11 min-w-11 text-subcontent"
          gap.dataset.cinderPaginationGap = side
          const dots = document.createElement("span")
          dots.setAttribute("aria-hidden", "true")
          dots.textContent = "…"
          const label = document.createElement("span")
          label.className = "sr-only"
          label.textContent = side === "before" ? "Earlier pages" : "Later pages"
          gap.append(dots, label)
          if (side === "before") pages[0].before(gap)
          else pages.at(-1).after(gap)
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
        this.topPagination?.remove()
        this.topPagination = top
        if (restoreFocus) {
          focusTarget = Array.from(top.querySelectorAll("button")).find(button =>
            !button.disabled && button.textContent === focused.textContent && button.getAttribute("phx-click") === focused.getAttribute("phx-click")
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
        if (focusTarget.tagName !== "BUTTON") focusTarget.setAttribute("tabindex", "-1")
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

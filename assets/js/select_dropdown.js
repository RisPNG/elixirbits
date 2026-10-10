const SelectDropdown = {
  mounted() {
    this.schedulePosition = () => {
      cancelAnimationFrame(this.positionFrame)
      this.positionFrame = requestAnimationFrame(() => {
        this.positionFrame = null
        this.positionDropdown()
      })
    }
    this.onScroll = event => {
      if (!this.el.querySelector("ul.select-dropdown")?.contains(event.target)) {
        this.schedulePosition()
      }
    }
    this.observer = new MutationObserver(this.schedulePosition)
    this.observer.observe(this.el, {
      childList: true,
      subtree: true,
      attributes: true,
      attributeFilter: ["class", "popover", "style"],
    })
    this.resizeObserver = new ResizeObserver(this.schedulePosition)
    this.resizeObserver.observe(this.el)
    document.addEventListener("scroll", this.onScroll, true)
    window.addEventListener("resize", this.schedulePosition)
    this.positionDropdown()
  },

  updated() {
    this.positionDropdown()
  },

  destroyed() {
    this.observer.disconnect()
    this.resizeObserver.disconnect()
    cancelAnimationFrame(this.positionFrame)
    document.removeEventListener("scroll", this.onScroll, true)
    window.removeEventListener("resize", this.schedulePosition)
    const dropdown = this.el.querySelector("ul.select-dropdown")
    if (dropdown?.matches(":popover-open")) dropdown.hidePopover()
  },

  positionDropdown() {
    const input = this.el.querySelector("input[type=text]")
    const dropdown = this.el.querySelector("ul.select-dropdown")
    if (!input || !dropdown) return

    this.observer.disconnect()
    const bounds = input.getBoundingClientRect()
    const minWidth = Number(this.el.dataset.dropdownMinWidth || 0) * parseFloat(getComputedStyle(document.documentElement).fontSize)
    const width = Math.min(
      Math.max(bounds.width, minWidth),
      window.innerWidth - 16,
    )
    dropdown.style.width = `${width}px`
    dropdown.style.maxHeight = ""
    if (dropdown.popover !== "manual") dropdown.popover = "manual"
    if (!dropdown.matches(":popover-open")) dropdown.showPopover({source: input})

    const style = getComputedStyle(dropdown)
    const height = Math.min(
      dropdown.scrollHeight + parseFloat(style.borderTopWidth) + parseFloat(style.borderBottomWidth),
      parseFloat(style.maxHeight),
    )
    const below = Math.max(0, window.innerHeight - bounds.bottom - 12)
    const above = Math.max(0, bounds.top - 12)
    const openAbove = height > below && above > below
    const availableHeight = openAbove ? above : below
    dropdown.style.maxHeight = `${Math.min(parseFloat(style.maxHeight), availableHeight)}px`
    dropdown.style.left = `${Math.max(8, Math.min(bounds.left, window.innerWidth - width - 8))}px`
    dropdown.style.top = `${openAbove ? bounds.top - 4 - Math.min(height, availableHeight) : bounds.bottom + 4}px`
    this.observer.observe(this.el, {
      childList: true,
      subtree: true,
      attributes: true,
      attributeFilter: ["class", "popover", "style"],
    })
  },
}

export default SelectDropdown

const SelectDropdown = {
  mounted() {
    this.observer = new MutationObserver(() => this.synchronize())
    this.observer.observe(this.el, {childList: true, subtree: true, attributes: true, attributeFilter: ["popover"]})
    this.synchronize()
  },

  updated() {
    this.synchronize()
  },

  destroyed() {
    this.observer.disconnect()
    const dropdown = this.el.querySelector("ul.select-dropdown")
    if (dropdown?.matches(":popover-open")) dropdown.hidePopover()
  },

  synchronize() {
    const input = this.el.querySelector("input[type=text]")
    const dropdown = this.el.querySelector("ul.select-dropdown")
    if (!input || !dropdown) return
    if (dropdown.popover !== "manual") dropdown.popover = "manual"
    if (!dropdown.matches(":popover-open")) dropdown.showPopover({source: input})
  },
}

export default SelectDropdown

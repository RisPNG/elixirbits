import {PetalPopover, flipDecision} from "../../deps/petal_components/assets/js/petal_components"

const PopoverPlacement = {
  ...PetalPopover,

  mounted() {
    this.onSource = event => {
      if (event.newState !== "open") return
      this.source = event.source
      this.el.style.visibility = ""
    }
    this.el.addEventListener("beforetoggle", this.onSource)
    PetalPopover.mounted.call(this)
  },

  position() {
    const id = CSS.escape(this.el.id)
    const anchor = this.source?.isConnected ? this.source :
      this.el.ownerDocument.querySelector(`[popovertarget="${id}"], [aria-controls="${id}"]`)
    if (!anchor) return

    const control = anchor.getBoundingClientRect()
    const viewport = this.viewport()
    const right = viewport.left + viewport.width
    const bottom = viewport.top + viewport.height
    const offscreen = control.right < viewport.left || control.left > right || control.bottom < viewport.top || control.top > bottom
    this.el.style.visibility = offscreen ? "hidden" : ""
    if (offscreen) return

    this.el.style.setProperty("--popover-anchor-width", `${control.width}px`)
    this.el.style.maxWidth = `${Math.max(0, viewport.width - 16)}px`
    const style = getComputedStyle(this.el)
    const {flip, room} = flipDecision({
      triggerTop: control.top,
      triggerBottom: control.bottom,
      panelHeight: this.el.scrollHeight + this.el.offsetHeight - this.el.clientHeight,
      viewportTop: viewport.top,
      viewportHeight: viewport.height,
      gap: parseFloat(style.marginTop) || 0,
    })
    const width = this.el.offsetWidth
    const alignEnd = this.el.dataset.popoverAlign === "end"
    const alignRight = style.direction === "rtl" ? !alignEnd : alignEnd
    const preferred = alignRight ? control.right - width : control.left
    const alternate = alignRight ? control.left : control.right - width
    const min = viewport.left + 8
    const max = right - width - 8
    const left = (preferred < min || preferred > max) && alternate >= min && alternate <= max ? alternate : preferred

    this.el.style.setProperty("--popover-room", `${Math.max(0, room)}px`)
    this.el.style.top = flip ? "auto" : `${control.bottom}px`
    this.el.style.bottom = flip ? `${this.el.ownerDocument.documentElement.clientHeight - control.top}px` : "auto"
    this.el.style.left = `${Math.max(min, Math.min(left, max))}px`
  },

  destroyed() {
    this.el.removeEventListener("beforetoggle", this.onSource)
    PetalPopover.destroyed.call(this)
  },
}

export default globalThis.CSS?.supports?.("position-area", "block-end") === false ? PopoverPlacement : {}

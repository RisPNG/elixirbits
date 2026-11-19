import {PetalPopover, flipDecision} from "../../deps/petal_components/assets/js/petal_components.js"

export const hasAnchorPositioning = globalThis.CSS?.supports?.("position-area", "block-end") !== false

export function slidePopover(panel, fromTop) {
  if (fromTop == null || !panel.animate) return

  const style = getComputedStyle(panel)
  const time = style.getPropertyValue("--motion-duration").trim()
  const duration = parseFloat(time) * (time.endsWith("ms") ? 1 : 1000)
  if (!duration) return

  panel.getAnimations().find(animation => animation.id === "popover-slide")?.cancel()
  const offset = fromTop - panel.getBoundingClientRect().top
  if (!offset) return

  const easing = style.getPropertyValue("--motion-ease").trim()
  panel.animate([{translate: `0 ${offset}px`}, {translate: "0 0"}], {id: "popover-slide", duration, easing})
}

const PopoverPlacement = {
  ...PetalPopover,

  mounted() {
    if (hasAnchorPositioning && this.el.hasAttribute("data-calendar-popover")) return

    this.onSource = event => {
      if (event.newState !== "open") return
      this.source = event.source
      this.el.style.visibility = ""
      this.top = null
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
    const wasFlipped = this.el.hasAttribute("data-flip")
    const previousTop = this.top

    if (hasAnchorPositioning) {
      this.top = this.el.offsetTop
      const flip = this.top < control.top
      const fromTop = previousTop != null && flip !== wasFlipped ?
        previousTop + this.el.getBoundingClientRect().top - this.top : null
      this.el.toggleAttribute("data-flip", flip)
      if (fromTop != null) slidePopover(this.el, fromTop)
      return
    }

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
    const fromTop = previousTop != null && flip !== wasFlipped ? this.el.getBoundingClientRect().top : null
    this.el.toggleAttribute("data-flip", flip)
    this.el.style.top = flip ? "auto" : `${control.bottom}px`
    this.el.style.bottom = flip ? `${this.el.ownerDocument.documentElement.clientHeight - control.top}px` : "auto"
    this.el.style.left = `${Math.max(min, Math.min(left, max))}px`
    this.top = this.el.offsetTop
    if (fromTop != null) slidePopover(this.el, fromTop)
  },

  destroyed() {
    if (!this.onSource) return
    this.el.removeEventListener("beforetoggle", this.onSource)
    PetalPopover.destroyed.call(this)
  },
}

export default PopoverPlacement

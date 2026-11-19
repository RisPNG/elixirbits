function clipToEntryCell(left, top, extraWidth = 0, extraHeight = 0) {
  return `inset(${Math.max(0, top)}px ${Math.max(0, extraWidth - left)}px ${Math.max(0, extraHeight - top)}px ${Math.max(0, left)}px)`
}

export default function initViewMotion() {
  const root = document.documentElement
  const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)")
  let nextMotion
  let pageTarget
  let pendingPatch
  let activeMotion

  window.addEventListener("phx:swipe", ({detail}) => {
    nextMotion = {id: detail.id, type: detail.direction, swipe: true}
  })
  window.addEventListener("phx:resize-entry", ({detail}) => {
    nextMotion = {id: detail.id, type: detail.type, index: detail.index}
  })
  window.addEventListener("phx:page-loading-start", ({detail}) => {
    if (detail.kind === "redirect") pageTarget = detail.to
  })
  window.addEventListener("phx:page-loading-stop", ({detail}) => {
    if (detail.kind === "redirect" && pageTarget === detail.to) pageTarget = undefined
  })
  window.addEventListener("phx:navigate", ({detail}) => {
    if (detail.pop && !detail.patch) pageTarget = detail.href
  })

  return start => {
    const motion = nextMotion || (pageTarget && {id: "dashboard-page", type: "page"})
    nextMotion = undefined
    pageTarget = undefined

    if (pendingPatch) {
      activeMotion?.transition.skipTransition()
      pendingPatch()
    }

    if (!motion || reducedMotion.matches) return start()

    const scope = document.getElementById(motion.id)
    if (!scope) return start()
    const entry = motion.index === undefined ? null : `[data-entry-index="${motion.index}"]`

    activeMotion?.clear()

    if (motion.type === "shrink") {
      const panelSelector = ":scope [data-entry-index]:not(:scope [data-entry-index] [data-entry-index])"
      const panels = scope.querySelectorAll(panelSelector)
      const item = Array.from(panels).find(panel => Number(panel.dataset.entryIndex) === motion.index)
      if (!item?.getClientRects().length) return start()

      const form = scope.closest("form") || scope
      const wasInert = form.inert
      form.inert = true
      item.classList.add("motion-grow", "motion-shrink")
      const apply = slide => {
        if (pendingPatch !== apply) return
        pendingPatch = undefined

        const beforeGroup = slide && scope.getBoundingClientRect()
        const positions = new Map()
        if (beforeGroup) {
          for (const panel of panels) {
            if (panel === item || !panel.getClientRects().length) continue
            const index = Number(panel.dataset.entryIndex)
            const {left, top, width, height} = panel.getBoundingClientRect()
            positions.set(index > motion.index ? index - 1 : index, {
              left: left - beforeGroup.left, top: top - beforeGroup.top, width, height,
            })
          }
        }

        item.classList.remove("motion-grow", "motion-shrink")
        form.inert = wasInert
        start()

        if (!beforeGroup) return
        const updated = document.getElementById(motion.id)
        if (!updated) return
        const origin = updated.getBoundingClientRect()
        const moves = []
        for (const panel of updated.querySelectorAll(panelSelector)) {
          const before = positions.get(Number(panel.dataset.entryIndex))
          if (!before || !panel.getClientRects().length) continue
          const {left, top, width, height} = panel.getBoundingClientRect()
          const x = before.left - (left - origin.left)
          const y = before.top - (top - origin.top)
          if (x || y) moves.push({panel, x, y, width, height, before})
        }

        const losesHeight = beforeGroup.height > origin.height
        if (!moves.length && !losesHeight) return
        const crossesColumns = moves.some(({x}) => x !== 0)
        const leaveEnd = 0.45
        const style = getComputedStyle(updated)
        const duration = parseFloat(style.getPropertyValue("--motion-duration"))
        const easing = style.getPropertyValue("--motion-ease").trim()
        const timing = {duration, easing}
        if (losesHeight) {
          const from = {minHeight: `${beforeGroup.height}px`, alignContent: "start"}
          const to = {minHeight: `${origin.height}px`, alignContent: "start"}
          updated.animate(crossesColumns ? [from, {...from, offset: leaveEnd}, to] : [from, to], timing)
        }
        for (const {panel, x, y, width, height, before} of moves) {
          const from = {translate: `${x}px ${y}px`}
          const to = {translate: "0 0"}
          if (crossesColumns) {
            const portion = Math.min(1, width / (4 * Math.abs(x)), height / (4 * Math.abs(y)))
            const stepX = x * portion
            const stepY = y * portion
            const extraWidth = width - before.width
            const extraHeight = height - before.height
            panel.animate([
              {...from, opacity: 1, clipPath: clipToEntryCell(0, 0, extraWidth, extraHeight)},
              {translate: `${x - stepX}px ${y - stepY}px`, opacity: 0, offset: leaveEnd, clipPath: clipToEntryCell(stepX, stepY, extraWidth, extraHeight)},
              {translate: `${stepX}px ${stepY}px`, opacity: 0, offset: 1 - leaveEnd, clipPath: clipToEntryCell(-stepX, -stepY)},
              {...to, opacity: 1, clipPath: "inset(0)"},
            ], timing)
          } else {
            panel.animate([from, to], timing)
          }
        }
      }

      pendingPatch = apply
      Promise.allSettled(item.getAnimations().map(animation => animation.finished)).then(() => apply(true))
      return
    }

    if (!document.startViewTransition) return start()

    const marks = new Map()
    const mark = (element, attribute) => {
      if (!element?.getClientRects().length) return
      element.setAttribute(attribute, "")
      marks.set(element, attribute)
    }
    const capture = (container, phase) => {
      if (motion.type === "grow" && phase === "before") return

      if (motion.type === "page") {
        mark(container, phase === "before" ? "data-page-outgoing" : "data-page-incoming")
      } else if (motion.swipe) {
        const panel = Array.from(container?.querySelectorAll("[data-swipe-panel]") || [])
          .find(element => element.getClientRects().length)
        mark(panel, "data-motion-pane")
        mark(container?.querySelector("[data-tab-indicator]"), "data-motion-indicator")
      } else if (entry) {
        mark(container?.querySelector(entry), "data-motion-pane")
      } else {
        mark(container, "data-motion-pane")
      }
    }

    root.dataset.viewMotion = motion.type
    capture(scope, "before")

    const apply = () => {
      if (pendingPatch !== apply) return
      pendingPatch = undefined
      start()
      if (activeMotion?.transition === transition) capture(document.getElementById(motion.id), "after")
    }
    const clear = () => {
      if (activeMotion?.transition !== transition) return
      transition.skipTransition()
      for (const [element, attribute] of marks) element.removeAttribute(attribute)
      delete root.dataset.viewMotion
      activeMotion = undefined
    }

    pendingPatch = apply
    const transition = document.startViewTransition(apply)
    activeMotion = {transition, clear}
    transition.ready.catch(() => {})
    transition.finished.then(clear, clear)
  }
}

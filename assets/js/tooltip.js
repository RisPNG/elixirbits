const OFFSET = 14

export default function initTooltips() {
  const tip = document.createElement("div")
  tip.id = "elixirbits-tooltip"
  tip.className = "tooltip-floating"
  tip.setAttribute("role", "tooltip")
  tip.hidden = true
  document.body.appendChild(tip)

  let target = null
  let described = null
  let focused = null
  let dismissed = null
  let anchorX = 0
  let anchorY = 0
  const nativeSources = new Map()

  const hide = () => {
    if (described) {
      const descriptions = (described.getAttribute("aria-describedby") || "")
        .split(/\s+/).filter(id => id && id !== tip.id)
      if (descriptions.length) described.setAttribute("aria-describedby", descriptions.join(" "))
      else described.removeAttribute("aria-describedby")
    }
    target = null
    described = null
    tip.hidden = true
  }

  const reveal = (el, control, x, y) => {
    const native = el?.getAttribute("title")
    if (native != null) {
      const source = nativeSources.get(el) || {title: native, text: null, label: null}
      source.title = native
      if (!el.dataset.tooltip || el.dataset.tooltip === source.text) {
        el.dataset.tooltip = native
        source.text = native
      } else {
        source.text = null
      }
      if ((source.label !== null && el.getAttribute("aria-label") === source.label) ||
        (!el.getAttribute("aria-label") && !el.getAttribute("aria-labelledby") && !el.textContent.trim())) {
        el.setAttribute("aria-label", el.dataset.tooltip)
        source.label = el.dataset.tooltip
      }
      nativeSources.set(el, source)
      el.removeAttribute("title")
    }
    const text = el?.dataset.tooltip
    if (!text || el === dismissed) return hide()

    if (target !== el || described !== control) hide()
    target = el
    described = control
    anchorX = x
    anchorY = y
    if (tip.textContent !== text) tip.textContent = text
    tip.hidden = false
    const descriptions = new Set((control.getAttribute("aria-describedby") || "").split(/\s+/).filter(Boolean))
    descriptions.add(tip.id)
    const ids = [...descriptions].join(" ")
    if (control.getAttribute("aria-describedby") !== ids) control.setAttribute("aria-describedby", ids)

    const {offsetWidth: width, offsetHeight: height} = tip
    tip.style.left = `${Math.max(0, Math.min(x + OFFSET, window.innerWidth - width))}px`
    tip.style.top = `${Math.max(0, y + OFFSET + height > window.innerHeight ? y - OFFSET - height : y + OFFSET)}px`
  }

  const onMove = event => {
    const el = event.target.closest?.("[data-tooltip], [title]")
    if (el !== dismissed) dismissed = null
    if (focused) return
    reveal(el, el, event.clientX, event.clientY)
  }

  const onFocus = event => {
    const owner = event.target.closest?.("[data-tooltip], [title]")
    focused = owner ? {owner, control: event.target} : null
    dismissed = null
    if (focused) {
      const bounds = focused.control.getBoundingClientRect()
      reveal(focused.owner, focused.control, bounds.left, bounds.bottom)
    } else hide()
  }

  const onBlur = () => {
    focused = null
    dismissed = null
    hide()
  }

  const onKey = event => {
    if (event.key === "Escape") {
      dismissed = target
      hide()
    }
  }

  const observer = new MutationObserver(() => {
    nativeSources.forEach((source, el) => {
      if (!el.isConnected) {
        if ((source.text === null || el.dataset.tooltip === source.text) && el.getAttribute("title") == null) {
          el.setAttribute("title", source.title)
        }
        if (source.text !== null && el.dataset.tooltip === source.text) delete el.dataset.tooltip
        if (source.label !== null && el.getAttribute("aria-label") === source.label) el.removeAttribute("aria-label")
        nativeSources.delete(el)
      }
    })
    if ((focused && (!focused.owner.isConnected || !focused.control.isConnected)) ||
      (target && (!target.isConnected || !described.isConnected))) onBlur()
    else if (target) {
      const bounds = focused?.control.getBoundingClientRect()
      reveal(target, described, bounds?.left ?? anchorX, bounds?.bottom ?? anchorY)
    }
  })
  observer.observe(document.body, {childList: true, subtree: true, attributes: true, attributeFilter: ["data-tooltip", "title", "aria-describedby"]})

  const listeners = [
    [document, "mousemove", onMove],
    [document, "focusin", onFocus],
    [document, "focusout", onBlur],
    [document, "keydown", onKey],
    [document, "mousedown", hide],
    [document, "mouseleave", hide],
    [document, "scroll", hide, true],
    [window, "blur", onBlur],
    [window, "phx:page-loading-start", onBlur],
  ]
  listeners.forEach(([surface, name, handler, capture]) => surface.addEventListener(name, handler, capture))

  return () => {
    onBlur()
    observer.disconnect()
    listeners.forEach(([surface, name, handler, capture]) => surface.removeEventListener(name, handler, capture))
    nativeSources.forEach((source, el) => {
      if ((source.text === null || el.dataset.tooltip === source.text) && el.getAttribute("title") == null) {
        el.setAttribute("title", source.title)
      }
      if (source.text !== null && el.dataset.tooltip === source.text) delete el.dataset.tooltip
      if (source.label !== null && el.getAttribute("aria-label") === source.label) el.removeAttribute("aria-label")
    })
    nativeSources.clear()
    tip.remove()
  }
}

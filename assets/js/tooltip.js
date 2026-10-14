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
  let hovered = null
  let focused = null
  let dismissed = null
  let anchorX = 0
  let anchorY = 0
  const nativeSources = new Map()
  let observed = new Set()

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

  const resolveTooltip = (control, includeChildren = false) => {
    if (!control || control === tip || tip.contains(control)) return null
    const explicit = control.closest?.("[data-tooltip], [title]")
    if (explicit) {
      const native = explicit.getAttribute("title")
      if (native != null) {
        const source = nativeSources.get(explicit) || {title: native, text: null, label: null}
        source.title = native
        if (!explicit.dataset.tooltip || explicit.dataset.tooltip === source.text) {
          explicit.dataset.tooltip = native
          source.text = native
        } else {
          source.text = null
        }
        if ((source.label !== null && explicit.getAttribute("aria-label") === source.label) ||
          (!explicit.getAttribute("aria-label") && !explicit.getAttribute("aria-labelledby") && !explicit.textContent.trim())) {
          explicit.setAttribute("aria-label", explicit.dataset.tooltip)
          source.label = explicit.dataset.tooltip
        }
        nativeSources.set(explicit, source)
        explicit.removeAttribute("title")
      }
      return explicit.dataset.tooltip ? {owner: explicit, text: explicit.dataset.tooltip} : null
    }
    if (control.matches("input[type=password], input[type=file]")) return null

    const candidates = [control]
    if (includeChildren) candidates.push(...control.querySelectorAll("*"))
    for (let ancestor = control.parentElement; ancestor && ancestor !== document.body; ancestor = ancestor.parentElement) {
      candidates.push(ancestor)
    }
    for (const owner of candidates) {
      if (owner.matches("input[type=password], input[type=file]")) continue
      const style = getComputedStyle(owner)
      if (style.overflowX === "auto" || style.overflowX === "scroll" ||
        style.overflowY === "auto" || style.overflowY === "scroll") continue
      const clipsX = (style.overflowX === "hidden" || style.overflowX === "clip") && owner.scrollWidth > owner.clientWidth
      const clipsY = (style.overflowY === "hidden" || style.overflowY === "clip" || Number(style.webkitLineClamp) > 0) && owner.scrollHeight > owner.clientHeight
      if (!clipsX && !clipsY) continue

      let text = owner.matches("input, textarea") ? owner.value : owner.innerText
      if (!text.trim()) continue
      if (owner.matches("input, textarea")) {
        if (style.textTransform === "uppercase") text = text.toUpperCase()
        else if (style.textTransform === "lowercase") text = text.toLowerCase()
      }
      return {owner, text}
    }
    return null
  }

  const reveal = (source, control, x, y) => {
    const {owner: el, text} = source || {}
    if (!text || el === dismissed) return hide()

    if (target !== el || described !== control) hide()
    target = el
    described = control
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

  const refresh = () => {
    const focusedSource = resolveTooltip(focused, true)
    const source = focusedSource || resolveTooltip(hovered)
    const control = focusedSource ? focused : source?.owner
    const bounds = focusedSource && focused.getBoundingClientRect()
    reveal(source, control, bounds?.left ?? anchorX, bounds?.bottom ?? anchorY)

    const elements = new Set()
    for (const control of [hovered, focused]) {
      for (let el = control; el && el !== document.body; el = el.parentElement) elements.add(el)
    }
    if (focused) focused.querySelectorAll("*").forEach(el => elements.add(el))
    if (source) elements.add(source.owner)
    if (elements.size !== observed.size || [...elements].some(el => !observed.has(el))) {
      resizeObserver.disconnect()
      elements.forEach(el => resizeObserver.observe(el))
      observed = elements
    }
  }

  const onMove = event => {
    hovered = event.target
    anchorX = event.clientX
    anchorY = event.clientY
    if (resolveTooltip(hovered)?.owner !== dismissed) dismissed = null
    refresh()
  }

  const onFocus = event => {
    focused = event.target
    dismissed = null
    refresh()
  }

  const onBlur = () => {
    hovered = null
    focused = null
    dismissed = null
    resizeObserver.disconnect()
    observed.clear()
    hide()
  }

  const onKey = event => {
    if (event.key === "Escape") {
      dismissed = target
      hide()
    }
  }

  const resizeObserver = new ResizeObserver(refresh)
  const observer = new MutationObserver((records) => {
    if (records.length && records.every(record => record.target === tip || tip.contains(record.target))) return
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
    if ((hovered && !hovered.isConnected) || (focused && !focused.isConnected) ||
      (target && (!target.isConnected || !described.isConnected))) onBlur()
    else if (hovered || focused) refresh()
  })
  observer.observe(document.body, {childList: true, characterData: true, subtree: true, attributes: true, attributeFilter: ["data-tooltip", "title", "aria-describedby", "class", "style", "value", "type", "hidden"]})

  const listeners = [
    [document, "mousemove", onMove],
    [document, "focusin", onFocus],
    [document, "focusout", onBlur],
    [document, "keydown", onKey],
    [document, "input", refresh],
    [document, "change", refresh],
    [document, "mousedown", onBlur],
    [document, "mouseleave", onBlur],
    [document, "scroll", onBlur, true],
    [window, "resize", refresh],
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

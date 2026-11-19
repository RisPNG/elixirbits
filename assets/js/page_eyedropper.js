const missingPixelWarnings = new Set(["image-fallback", "canvas-tainted", "embed-fallback", "iframe-cross-origin", "iframe-failed"])
const missingPixelMessage = "This part of the page can't be sampled. Choose another spot."

export async function pickPageColor(button, signal) {
  const overlay = document.createElement("div")
  overlay.dataset.pageEyedropper = ""
  overlay.setAttribute("role", "dialog")
  overlay.setAttribute("aria-label", button.getAttribute("aria-label"))
  overlay.setAttribute("aria-modal", "true")
  overlay.className = "fixed inset-0 z-50 m-0 h-auto max-h-none w-auto max-w-none cursor-crosshair touch-none overflow-visible border-0 bg-transparent p-0"
  overlay.innerHTML = `
    <div class="pointer-events-none absolute inset-x-0 bottom-4 grid justify-items-center px-4">
      <div class="pointer-events-auto grid grid-cols-[1fr_auto] items-center gap-3 rounded-default border border-outline bg-primary px-3 py-2 text-sm text-content shadow">
        <p role="status">Click or tap a color on the page.</p>
        <button type="button" class="button-base cursor-pointer rounded-default px-2 py-1 text-brand">Cancel</button>
      </div>
    </div>`

  const status = overlay.querySelector("[role=status]")
  const cancel = overlay.querySelector("button")
  const listeners = new AbortController()
  const options = {signal: listeners.signal}
  const renderer = import("@zumer/snapdom")
  renderer.catch(() => {})
  let reading = false

  const result = new Promise((resolve, reject) => {
    const dismiss = () => resolve(null)
    const viewportChanged = () => { if (reading) dismiss() }
    signal.addEventListener("abort", dismiss, options)
    window.addEventListener("blur", dismiss, options)
    window.addEventListener("resize", viewportChanged, options)
    window.addEventListener("scroll", viewportChanged, {...options, capture: true})
    window.visualViewport?.addEventListener("resize", viewportChanged, options)
    window.visualViewport?.addEventListener("scroll", viewportChanged, options)
    window.addEventListener("keydown", event => {
      if (event.key === "Escape") {
        event.preventDefault()
        event.stopImmediatePropagation()
        dismiss()
      } else if (event.key === "Tab") {
        event.preventDefault()
        cancel.focus({preventScroll: true})
      }
    }, {...options, capture: true})

    overlay.addEventListener("click", async event => {
      event.stopPropagation()
      if (event.target === cancel) return dismiss()
      if (reading || event.target !== overlay || event.button !== 0) return

      overlay.style.pointerEvents = "none"
      const target = document.elementFromPoint(event.clientX, event.clientY)
      overlay.style.removeProperty("pointer-events")
      if (!target || (target.matches("iframe, object, embed") && !target.contentDocument)) {
        status.textContent = missingPixelMessage
        return
      }

      const clip = {x: event.clientX + window.scrollX, y: event.clientY + window.scrollY, width: 1, height: 1}
      reading = true
      status.textContent = "Reading page color..."
      try {
        const {snapdom} = await renderer
        if (options.signal.aborted) return
        const capture = await snapdom(document.documentElement, {
          clip, dpr: 1, exclude: "[data-page-eyedropper]", excludeMode: "remove",
        })
        if (options.signal.aborted) return
        if (!capture.warnings.some(({code}) => missingPixelWarnings.has(code))) {
          const canvas = await capture.toCanvas()
          const [r, g, b, alpha] = canvas.getContext("2d").getImageData(0, 0, 1, 1).data
          if (alpha === 255) return resolve({r, g, b, a: 1})
        }
        status.textContent = missingPixelMessage
      } catch (error) {
        reject(error)
      } finally {
        reading = false
      }
    }, options)
  })

  try {
    if (overlay.showPopover) overlay.setAttribute("popover", "manual")
    document.body.append(overlay)
    overlay.showPopover?.()
    cancel.focus({preventScroll: true})
    return await result
  } finally {
    listeners.abort()
    const restoreFocus = overlay.contains(document.activeElement)
    overlay.remove()
    if (restoreFocus && button.isConnected) button.focus({preventScroll: true})
  }
}

const formatDuration = (totalSeconds) => {
  const s = Math.max(0, Math.floor(totalSeconds))
  if (!Number.isFinite(s)) return "0:00"
  if (s >= 86400) {
    const days = Math.floor(s / 86400)
    const hours = Math.floor((s % 86400) / 3600)
    return `${days}d ${hours}h`
  }
  const hours = Math.floor(s / 3600)
  const minutes = Math.floor((s % 3600) / 60)
  const seconds = s % 60
  return hours > 0
    ? `${hours}:${String(minutes).padStart(2, "0")}:${String(seconds).padStart(2, "0")}`
    : `${minutes}:${String(seconds).padStart(2, "0")}`
}

// Writes the current value into one timer element. Recomputes from the absolute `data-target` every call (never increments), so the display is always correct even after the tab was backgrounded. Only ever touches textContent + a data attribute, so there is no injection surface.
const renderTimer = (el) => {
  const target = new Date(el.dataset.target).getTime()
  const mode = el.dataset.mode || "elapsed"
  const delta = (Date.now() - target) / 1000

  if (mode === "countdown" && delta < 0) {
    el.textContent = `in ${formatDuration(-delta)}`
    el.removeAttribute("data-overdue")
  } else if (mode === "countdown") {
    el.textContent = `+${formatDuration(delta)}`
    el.setAttribute("data-overdue", "")
  } else {
    el.textContent = formatDuration(delta)
    el.removeAttribute("data-overdue")
  }
}

// One shared requestAnimationFrame loop updates every LiveTimer. It runs at the display refresh rate, but updates the timers only once per second. The browser pauses the loop while the tab is hidden, and the timers resume from their absolute target times when it becomes visible again. Detached elements are removed from the registry, so cleanup still happens if `destroyed` is not called.
const timers = new Set()
let rafId = null
let lastTick = 0

const tick = (now) => {
  rafId = requestAnimationFrame(tick)
  if (now - lastTick < 1000) return
  lastTick = now

  timers.forEach((el) => {
    if (el.isConnected) renderTimer(el)
    else timers.delete(el)
  })

  if (timers.size === 0) {
    cancelAnimationFrame(rafId)
    rafId = null
  }
}

const LiveTimer = {
  mounted() {
    renderTimer(this.el)
    timers.add(this.el)
    if (rafId === null) {
      lastTick = performance.now() - 1000
      rafId = requestAnimationFrame(tick)
    }
  },
  updated() {
    renderTimer(this.el)
  },
  destroyed() {
    timers.delete(this.el)
    if (timers.size === 0) {
      cancelAnimationFrame(rafId)
      rafId = null
    }
  },
}

export default LiveTimer

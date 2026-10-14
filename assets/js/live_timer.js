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

// Recomputes from the absolute `data-target` every call so delayed ticks and background tabs cannot accumulate drift.
const renderTimer = (el) => {
  const target = new Date(el.dataset.target).getTime()
  const mode = el.dataset.mode || "elapsed"
  const delta = (Date.now() - target) / 1000

  if (mode === "countdown" && delta < 0) {
    el.textContent = `in ${formatDuration(-delta)}`
  } else if (mode === "countdown") {
    el.textContent = `+${formatDuration(delta)}`
  } else {
    el.textContent = formatDuration(delta)
  }
}

// One shared interval updates every LiveTimer once per second while visible. Visibility changes refresh the timers immediately, and detached elements are removed even if `destroyed` is not called.
const timers = new Set()
let intervalId = null

const tick = () => {
  if (document.hidden) return

  timers.forEach((el) => {
    if (el.isConnected) renderTimer(el)
    else timers.delete(el)
  })

  if (timers.size === 0) {
    clearInterval(intervalId)
    intervalId = null
    document.removeEventListener("visibilitychange", tick)
  }
}

const LiveTimer = {
  mounted() {
    renderTimer(this.el)
    timers.add(this.el)
    if (intervalId === null) {
      intervalId = setInterval(tick, 1000)
      document.addEventListener("visibilitychange", tick)
    }
  },
  updated() {
    renderTimer(this.el)
  },
  destroyed() {
    timers.delete(this.el)
    if (timers.size === 0) {
      clearInterval(intervalId)
      intervalId = null
      document.removeEventListener("visibilitychange", tick)
    }
  },
}

export default LiveTimer

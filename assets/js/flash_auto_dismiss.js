const FlashAutoDismiss = {
  mounted() {
    this.flashEvent = this.handleEvent("flash:replace", ({kind}) => {
      if (this.el.dataset.flashKey !== kind) return

      for (const notice of document.querySelectorAll("[data-flash-notice]")) {
        if (notice !== this.el) this.js().hide(notice, {time: 0})
      }
      this.js().show(this.el, {display: "flex", time: 0})
      this.updated()
    })
    this.updated()
  },

  updated() {
    window.clearTimeout(this.timeout)
    const duration = Number.parseInt(this.el.dataset.duration, 10)

    if (duration > 0) {
      this.timeout = window.setTimeout(() => this.el.click(), duration)
    }
  },

  disconnected() {
    window.clearTimeout(this.timeout)
  },

  destroyed() {
    window.clearTimeout(this.timeout)
    this.removeHandleEvent(this.flashEvent)
  },
}

export default FlashAutoDismiss

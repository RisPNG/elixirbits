const FlashAutoDismiss = {
  mounted() {
    const duration = Number.parseInt(this.el.dataset.duration, 10)

    if (duration > 0) {
      this.timeout = window.setTimeout(() => this.el.click(), duration)
    }
  },

  destroyed() {
    window.clearTimeout(this.timeout)
  },
}

export default FlashAutoDismiss

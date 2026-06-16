const Tooltip = {
  mounted() {
    this.tip = document.createElement("div")
    this.tip.className = "tooltip-floating"
    this.tip.hidden = true
    this.tip.textContent = this.el.dataset.tooltip || ""
    document.body.appendChild(this.tip)

    this.offset = 14

    this.show = () => {
      this.tip.hidden = false
    }

    this.move = (e) => {
      const {offsetWidth: w, offsetHeight: h} = this.tip
      let x = e.clientX + this.offset
      let y = e.clientY + this.offset
      if (x + w > window.innerWidth) x = e.clientX - this.offset - w
      if (y + h > window.innerHeight) y = e.clientY - this.offset - h
      this.tip.style.left = `${Math.max(0, x)}px`
      this.tip.style.top = `${Math.max(0, y)}px`
    }

    this.hide = () => {
      this.tip.hidden = true
    }

    this.el.addEventListener("mouseenter", this.show)
    this.el.addEventListener("mousemove", this.move)
    this.el.addEventListener("mouseleave", this.hide)
  },

  updated() {
    this.tip.textContent = this.el.dataset.tooltip || ""
  },

  destroyed() {
    this.tip.remove()
  },
}

export default Tooltip

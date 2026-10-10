const PasswordVisibility = {
  mounted() {
    this.visible = false
    this.onClick = event => {
      event.preventDefault()
      event.stopPropagation()

      this.visible = !this.visible
      this.apply()
      this.input?.focus()
    }
    this.onPointerDown = event => {
      event.preventDefault()
    }

    this.bind()
    this.apply()
  },

  updated() {
    this.bind()
    this.apply()
  },

  destroyed() {
    if (this.button) {
      this.button.removeEventListener("pointerdown", this.onPointerDown)
      this.button.removeEventListener("mousedown", this.onPointerDown)
      this.button.removeEventListener("click", this.onClick)
    }
  },

  bind() {
    this.input = this.el.querySelector("input")
    this.showIcon = this.el.querySelector("[data-password-show-icon]")
    this.hideIcon = this.el.querySelector("[data-password-hide-icon]")

    const button = this.el.querySelector("[data-password-toggle]")

    if (button !== this.button) {
      if (this.button) {
        this.button.removeEventListener("pointerdown", this.onPointerDown)
        this.button.removeEventListener("mousedown", this.onPointerDown)
        this.button.removeEventListener("click", this.onClick)
      }

      this.button = button

      if (this.button) {
        this.button.addEventListener("pointerdown", this.onPointerDown)
        this.button.addEventListener("mousedown", this.onPointerDown)
        this.button.addEventListener("click", this.onClick)
      }
    }
  },

  apply() {
    if (!this.input || !this.button) {
      return
    }

    this.button.disabled = this.input.disabled
    this.input.type = this.visible ? "text" : "password"
    this.button.setAttribute("aria-label", this.visible ? "Hide password" : "Show password")
    this.button.setAttribute("aria-pressed", this.visible ? "true" : "false")

    if (this.showIcon) {
      this.showIcon.hidden = this.visible
    }

    if (this.hideIcon) {
      this.hideIcon.hidden = !this.visible
    }
  },
}

export default PasswordVisibility

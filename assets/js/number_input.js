const NumberInput = {
  mounted() {
    this.onClick = event => {
      const button = event.target.closest("[data-number-step]")
      if (!button || !this.el.contains(button)) return
      event.preventDefault()
      if (this.input.disabled || this.input.readOnly || this.input.step.toLowerCase() === "any") return

      const previous = this.input.value
      if (button.dataset.numberStep === "1") this.input.stepUp()
      else this.input.stepDown()

      if (this.input.value !== previous) {
        this.input.dispatchEvent(new Event("input", {bubbles: true}))
        this.input.dispatchEvent(new Event("blur"))
      }
    }
    this.onPointerDown = event => {
      if (event.target.closest("[data-number-step]")) event.preventDefault()
    }
    this.el.addEventListener("click", this.onClick)
    this.el.addEventListener("pointerdown", this.onPointerDown)
    this.input = this.el.querySelector("input[type=number]")
  },

  updated() {
    this.input = this.el.querySelector("input[type=number]")
  },

  destroyed() {
    this.el.removeEventListener("click", this.onClick)
    this.el.removeEventListener("pointerdown", this.onPointerDown)
  },
}

export default NumberInput

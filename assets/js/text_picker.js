const TextPicker = {
  mounted() {
    this.onChange = () => {
      const input = this.el.querySelector("input")
      const display = this.el.querySelector("[data-text-picker-value]")
      if (input.type === "file") {
        // LiveView clears the native FileList after tracking the selected files.
        if (input.files.length > 0) {
          this.fileNames = Array.from(input.files, file => file.name).join(", ")
        }
        display.textContent = this.fileNames || input.placeholder
      } else {
        display.textContent = input.value
      }
    }
    this.el.addEventListener("input", this.onChange)
    this.el.addEventListener("change", this.onChange)
    this.onChange()
  },

  updated() {
    this.onChange()
  },

  destroyed() {
    this.el.removeEventListener("input", this.onChange)
    this.el.removeEventListener("change", this.onChange)
  },
}

export default TextPicker

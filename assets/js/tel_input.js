const TelInput = {
  mounted() {
    this.countries = JSON.parse(this.el.dataset.countries)
    this.onInput = event => {
      if (event.target.name !== this.el.dataset.countryName && !event.target.hasAttribute("data-tel-number")) return
      const iso = this.el.querySelector(`select[name='${this.el.dataset.countryName}']`).value.toUpperCase()
      const number = this.el.querySelector("[data-tel-number]").value.trim()
      this.el.querySelector("[data-tel-composite]").value = `${this.countries[iso] || ""}${number}`
    }
    this.clearRoot = this.el.closest("[data-core-input]")
    this.onClear = event => {
      if (event.target !== this.clearRoot) return
      event.preventDefault()
      const number = this.el.querySelector("[data-tel-number]")
      if (this.clearRoot.dataset.inputClearable !== "true" || number.matches(":disabled") || number.readOnly) return
      const country = this.el.querySelector(`select[name='${this.el.dataset.countryName}']`)
      const composite = this.el.querySelector("[data-tel-composite]")
      country.value = ""
      number.value = ""
      composite.value = ""
      country.dispatchEvent(new Event("change"))
      composite.dispatchEvent(new Event("input", {bubbles: true}))
      composite.dispatchEvent(new Event("change", {bubbles: true}))
      number.dispatchEvent(new Event("blur"))
    }
    this.el.addEventListener("input", this.onInput, true)
    this.el.addEventListener("change", this.onInput, true)
    this.clearRoot.addEventListener("input:clear", this.onClear)
  },

  destroyed() {
    this.el.removeEventListener("input", this.onInput, true)
    this.el.removeEventListener("change", this.onInput, true)
    this.clearRoot.removeEventListener("input:clear", this.onClear)
  },
}

export default TelInput

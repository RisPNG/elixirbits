const TelInput = {
  mounted() {
    this.countries = JSON.parse(this.el.dataset.countries)
    this.onInput = event => {
      if (event.target.name !== this.el.dataset.countryName && !event.target.hasAttribute("data-tel-number")) return
      const iso = this.el.querySelector(`select[name='${this.el.dataset.countryName}']`).value.toUpperCase()
      const number = this.el.querySelector("[data-tel-number]").value.trim()
      this.el.querySelector("[data-tel-composite]").value = `${this.countries[iso] || ""}${number}`
    }
    this.el.addEventListener("input", this.onInput, true)
    this.el.addEventListener("change", this.onInput, true)
  },

  destroyed() {
    this.el.removeEventListener("input", this.onInput, true)
    this.el.removeEventListener("change", this.onInput, true)
  },
}

export default TelInput

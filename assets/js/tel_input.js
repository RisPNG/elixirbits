const TelInput = {
  mounted() {
    this.wrapper = this.el
    this.countries = JSON.parse(this.wrapper.dataset.countries || "{}")
    this.countryName = this.wrapper.dataset.countryName
    this.composite = this.wrapper.querySelector("[data-tel-composite]")
    this.numberInput = this.wrapper.querySelector("[data-tel-number]")
    this.isoInput = () => this.wrapper.querySelector(`input[name='${this.countryName}']`)

    this.expectedDisplay = () => {
      const iso = (this.isoInput()?.value || "").toUpperCase()
      return this.countries[iso] || ""
    }

    this.overrideTextInput = () => {
      const ti = this.wrapper.querySelector('div[phx-hook="LiveSelect"] input[type="text"]')
      if (!ti || ti.__telOverridden) return

      const expectedDisplay = this.expectedDisplay.bind(this)
      const orig = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, "value")
      Object.defineProperty(ti, "value", {
        configurable: true,
        get() { return orig.get.call(this) },
        set(v) {
          const expected = expectedDisplay()
          if (expected && v !== expected) {
            orig.set.call(this, expected)
          } else {
            orig.set.call(this, v)
          }
        }
      })
      ti.addEventListener("blur", () => {
        const expected = expectedDisplay()
        if (orig.get.call(ti) !== expected) {
          orig.set.call(ti, expected)
        }
      })
      ti.__telOverridden = true
    }

    this.recompose = () => {
      const iso = (this.isoInput()?.value || "").toUpperCase()
      const dial = this.countries[iso] || ""
      const number = (this.numberInput.value || "").trim()
      this.composite.value = number || dial ? `${dial}${number}` : ""
    }

    this.numberInput.addEventListener("input", this.recompose)
    this.numberInput.addEventListener("change", this.recompose)

    this.wrapper.addEventListener("input", (e) => {
      if (e.target.name === this.countryName || e.target.hasAttribute("data-live-select-empty")) {
        this.recompose()
      }
    }, true)

    this.overrideTextInput()
    const ti = this.wrapper.querySelector('div[phx-hook="LiveSelect"] input[type="text"]')
    if (ti) {
      const expected = this.expectedDisplay()
      if (expected && ti.value !== expected) ti.value = expected
    }
  },

  updated() {
    this.overrideTextInput()
    const ti = this.wrapper.querySelector('div[phx-hook="LiveSelect"] input[type="text"]')
    if (ti && document.activeElement !== ti) {
      const expected = this.expectedDisplay()
      if (expected && ti.value !== expected) ti.value = expected
    }
  }
}

export default TelInput

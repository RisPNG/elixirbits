export default function initInputControls() {
  const selectedRadios = new WeakMap()
  const controls = {
    refresh(field) {
      if (!field?.matches("[data-core-input][data-input-type]")) return
      let inputs = Array.from(field.querySelectorAll("[data-input-value]"))
        .filter(input => input.matches("input, select, textarea") && input.closest("[data-core-input]") === field)
      if (!inputs.length) inputs = Array.from(field.querySelectorAll(".core-selection-input > .pc-combo-box__select"))
        .filter(input => input.closest("[data-core-input]") === field)
      const radio = field.dataset.inputType === "radio"
      const format = field.dataset.inputType === "color" && field.querySelector("[data-color-space-select] select")
      const hasValue = radio
        ? inputs.some(input => input.checked)
        : inputs.some(input => input.type === "file" ? input.files.length > 0 : input.multiple ? Array.from(input.selectedOptions).some(option => option.value !== "") : input.value !== "") || !!format?.value
      if (field.dataset.inputHasValue !== String(hasValue)) field.dataset.inputHasValue = String(hasValue)
      for (const input of inputs) if (radio) selectedRadios.set(input, input.checked)
      for (const button of field.querySelectorAll("[data-input-clear]")) {
        if (button.closest("[data-core-input]") === field) button.hidden = field.dataset.inputClearable !== "true" || !hasValue || inputs.every(input => input.matches(":disabled"))
      }
    },

    onInput(event) {
      controls.refresh(event.target.closest("[data-core-input]"))
    },

    onPointerDown(event) {
      if (event.target.closest("[data-input-clear]")) event.preventDefault()
    },

    onReset(event) {
      setTimeout(() => {
        const fields = new Set(Array.from(event.target.elements, input => input.closest("[data-core-input]")))
        for (const field of fields) controls.refresh(field)
      }, 0)
    },

    onActivation(event) {
      const keyboard = event.type === "keydown"
      if (keyboard && event.key !== " ") return
      const radio = event.target.closest("input[type=radio][data-input-value]")
      if (keyboard && !radio) return
      const button = event.target.closest("[data-input-clear]")
      const field = (radio || button)?.closest("[data-core-input]")
      if (!field || field.dataset.inputClearable !== "true") return
      if (radio) {
        if (radio.matches(":disabled")) return
        if (keyboard && event.repeat) {
          event.preventDefault()
          return
        }
        if (!selectedRadios.get(radio)) return
        event.preventDefault()
        setTimeout(() => {
          radio.checked = false
          radio.dispatchEvent(new Event("input", {bubbles: true}))
          radio.dispatchEvent(new Event("change", {bubbles: true}))
          radio.dispatchEvent(new Event("blur"))
          controls.refresh(field)
        }, 0)
        return
      }
      event.preventDefault()
      const input = Array.from(field.querySelectorAll("[data-input-value]"))
        .find(input => input.matches("input, select, textarea") && input.closest("[data-core-input]") === field) ||
        Array.from(field.querySelectorAll(".core-selection-input > .pc-combo-box__select"))
          .find(input => input.closest("[data-core-input]") === field)
      if (!input || input.matches(":disabled")) return
      const clearing = new CustomEvent("input:clear", {bubbles: true, cancelable: true})
      if (field.dispatchEvent(clearing)) {
        if (input.tagName === "SELECT") {
          for (const option of input.options) option.selected = !input.multiple && option.value === ""
        } else input.value = ""
        input.dispatchEvent(new Event("input", {bubbles: true}))
        input.dispatchEvent(new Event("change", {bubbles: true}))
        input.dispatchEvent(new Event("blur"))
      }
      const focus = field.dataset.inputType === "tel" ? field.querySelector("[data-tel-number]") :
        input.tagName === "SELECT" ? input.closest(".pc-combo-box")?.querySelector("[data-pc-combo-trigger]") || input : input
      focus.focus({preventScroll: true})
      controls.refresh(field)
    },

    destroyed() {
      observer.disconnect()
      document.removeEventListener("input", controls.onInput)
      document.removeEventListener("change", controls.onInput)
      document.removeEventListener("pointerdown", controls.onPointerDown)
      document.removeEventListener("click", controls.onActivation, true)
      document.removeEventListener("keydown", controls.onActivation, true)
      document.removeEventListener("reset", controls.onReset)
    },
  }
  document.addEventListener("input", controls.onInput)
  document.addEventListener("change", controls.onInput)
  document.addEventListener("pointerdown", controls.onPointerDown)
  document.addEventListener("click", controls.onActivation, true)
  document.addEventListener("keydown", controls.onActivation, true)
  document.addEventListener("reset", controls.onReset)
  for (const field of document.querySelectorAll("[data-core-input][data-input-type]")) controls.refresh(field)
  const observer = new MutationObserver(records => {
    const fields = new Set()
    for (const record of records) {
      const parent = record.target.closest?.("[data-core-input]")
      if (parent) fields.add(parent)
      if (record.type === "attributes") {
        for (const field of record.target.querySelectorAll("[data-core-input][data-input-type]")) fields.add(field)
      }
      for (const node of record.addedNodes) {
        if (node.nodeType !== 1) continue
        if (node.matches("[data-core-input][data-input-type]")) fields.add(node)
        for (const field of node.querySelectorAll("[data-core-input][data-input-type]")) fields.add(field)
      }
    }
    for (const field of fields) controls.refresh(field)
  })
  observer.observe(document.documentElement, {childList: true, subtree: true, attributes: true, attributeFilter: ["value", "checked", "selected", "disabled", "readonly", "data-input-clearable", "data-input-has-value"]})
  return controls
}

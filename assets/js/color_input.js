const colorForms = new WeakMap()

const ColorInput = {
  mounted() {
    this.revision = 0
    this.onInput = event => {
      if (!this.editable || this.applying || event.target !== this.input) return
      this.value = this.input.value
      this.pending?.resolve(null)
      this.pending = null
      this.revision++
      this.draft = true
      this.error = ""
      this.validationVisible = false
      this.preview = null
      this.renderColor()
    }
    this.onSpaceSelection = event => {
      if (!this.editable || event.target.name !== this.el.dataset.colorSpaceName) return
      event.stopPropagation()
      if (!this.selectionIntent || this.input.disabled || this.input.readOnly) {
        event.target.value = this.format
        if (this.state.format === this.format && document.activeElement !== this.spaceText) this.spaceText.value = this.state.label
        return
      }
      this.selectionIntent = false
      const format = event.target.value
      if (!format) return
      this.format = format
      this.revision++
      this.requestColor("convert")
    }
    this.onColorChanged = event => {
      if (event.target !== this.picker) return
      event.stopPropagation()
      if (this.updatingPicker || !this.editable || this.input.disabled || this.input.readOnly) return
      const rgba = event.detail.value
      const alphaChanged = this.editingAlpha || rgba.a !== Math.round((this.state.rgba?.a ?? 1) * 100) / 100
      this.revision++
      this.error = ""
      this.preview = {rgba, swatch: `rgb(${rgba.r} ${rgba.g} ${rgba.b} / ${rgba.a})`}
      this.renderColor()
      this.requestColor("pick", {rgba, alpha_changed: alphaChanged})
    }
    this.onInteraction = event => {
      const path = event.composedPath()
      if (path.includes(this.picker)) {
        this.editingAlpha = path.some(node => node.getAttribute?.("part") === "alpha")
      } else if (this.spaceSelect?.contains(event.target)) {
        if (path.some(node => node.hasAttribute?.("data-idx")) || (event.type === "keydown" && event.key === "Enter")) {
          this.selectionIntent = true
        }
      }
    }
    this.onBlur = event => {
      if (this.editable && !this.applying && event.target === this.input && this.draft) this.requestColor("validate")
    }
    this.onBeforeToggle = event => {
      if (event.target !== this.popover || event.newState !== "open") return
      if (!this.editable || this.input.disabled || this.input.readOnly) {
        event.preventDefault()
      } else if (this.draft || this.pending) {
        event.preventDefault()
        if (this.opening) return
        this.opening = true
        const revision = this.revision
        const pending = this.pending?.promise || this.requestColor("validate")
        pending.then(reply => {
          this.opening = false
          if (this.destroyedInput || this.revision !== revision) return
          if (reply && !this.draft && !this.pending) this.popover.showPopover()
          else this.input.focus()
        })
      }
    }
    this.onToggle = event => {
      if (event.target !== this.popover) return
      if (this.popover.matches(":popover-open")) {
        this.positionPicker()
        document.addEventListener("scroll", this.onScroll, true)
        window.addEventListener("resize", this.onViewportChange)
      } else {
        document.removeEventListener("scroll", this.onScroll, true)
        window.removeEventListener("resize", this.onViewportChange)
        cancelAnimationFrame(this.positionFrame)
        this.positionFrame = null
        this.editingAlpha = false
      }
    }
    this.onViewportChange = () => {
      cancelAnimationFrame(this.positionFrame)
      this.positionFrame = requestAnimationFrame(() => {
        this.positionFrame = null
        this.positionPicker()
      })
    }
    this.onScroll = event => {
      if (!this.popover.contains(event.target)) this.onViewportChange()
    }

    this.el.addEventListener("input", this.onInput)
    this.el.addEventListener("input", this.onSpaceSelection, true)
    this.el.addEventListener("change", this.onInput)
    this.el.addEventListener("color-changed", this.onColorChanged)
    this.el.addEventListener("blur", this.onBlur, true)
    this.el.addEventListener("mousedown", this.onInteraction, true)
    this.el.addEventListener("touchstart", this.onInteraction, true)
    this.el.addEventListener("keydown", this.onInteraction, true)
    this.el.addEventListener("beforetoggle", this.onBeforeToggle, true)
    this.el.addEventListener("toggle", this.onToggle, true)
    this.synchronize()
  },

  updated() {
    this.synchronize()
  },

  destroyed() {
    this.destroyedInput = true
    this.pending?.resolve(null)
    this.pending = null
    if (this.liveSocket?.isConnected()) this.pushEvent("color_input", {id: this.el.id, selector_id: this.el.dataset.colorSpaceId, operation: "release"}, () => {})
    this.el.removeEventListener("input", this.onInput)
    this.el.removeEventListener("input", this.onSpaceSelection, true)
    this.el.removeEventListener("change", this.onInput)
    this.el.removeEventListener("color-changed", this.onColorChanged)
    this.el.removeEventListener("blur", this.onBlur, true)
    this.el.removeEventListener("mousedown", this.onInteraction, true)
    this.el.removeEventListener("touchstart", this.onInteraction, true)
    this.el.removeEventListener("keydown", this.onInteraction, true)
    this.el.removeEventListener("beforetoggle", this.onBeforeToggle, true)
    this.el.removeEventListener("toggle", this.onToggle, true)
    if (this.form) {
      const shared = colorForms.get(this.form)
      shared.hooks.delete(this)
      if (!shared.hooks.size) {
        this.form.removeEventListener("submit", shared.listener, true)
        colorForms.delete(this.form)
      }
    }
    document.removeEventListener("scroll", this.onScroll, true)
    window.removeEventListener("resize", this.onViewportChange)
    cancelAnimationFrame(this.positionFrame)
    if (this.popover?.matches(":popover-open")) this.popover.hidePopover()
  },

  synchronize() {
    this.editable = this.el.dataset.colorEditable === "true"
    this.input = this.el.querySelector("[data-color-value]")
    this.picker = this.el.querySelector("[data-color-picker]")
    this.picker?.shadowRoot?.querySelector("[part='alpha']")?.setAttribute("aria-valuemax", "100")
    this.trigger = this.el.querySelector("[data-color-trigger]")
    this.swatch = this.el.querySelector("[data-color-swatch]")
    this.formatLabel = this.el.querySelector("[data-color-format]")
    this.spaceInput = this.editable ? this.el.querySelector(`input[name='${this.el.dataset.colorSpaceName}']`) : null
    this.spaceSelect = this.el.querySelector("[data-color-space-select]")
    this.spaceText = this.spaceSelect?.querySelector("input[type=text]")
    this.errorText = this.el.querySelector("[data-color-error]")
    const popover = this.el.querySelector("[data-color-popover]")
    if (popover !== this.popover) {
      if (this.popover?.matches(":popover-open")) this.popover.hidePopover()
      document.removeEventListener("scroll", this.onScroll, true)
      window.removeEventListener("resize", this.onViewportChange)
      cancelAnimationFrame(this.positionFrame)
      this.popover = popover
    }
    const form = this.editable ? this.input.form : null
    if (form !== this.form) {
      if (this.form) {
        const shared = colorForms.get(this.form)
        shared.hooks.delete(this)
        if (!shared.hooks.size) {
          this.form.removeEventListener("submit", shared.listener, true)
          colorForms.delete(this.form)
        }
      }
      this.form = form
      if (form) {
        let shared = colorForms.get(form)
        if (!shared) {
          shared = {hooks: new Set(), submitting: false, replaying: false}
          shared.listener = async event => {
            if (shared.replaying) return
            const hooks = [...shared.hooks].filter(hook => !hook.input.disabled && !hook.input.readOnly)
            const invalid = hooks.find(hook => !hook.draft && !hook.pending && !hook.input.validity.valid)
            if (invalid) {
              event.preventDefault()
              event.stopImmediatePropagation()
              invalid.validationVisible = true
              invalid.renderColor()
              invalid.input.focus()
              return
            }
            if (!hooks.some(hook => hook.draft || hook.pending)) return
            event.preventDefault()
            event.stopImmediatePropagation()
            if (shared.submitting) return
            shared.submitting = true
            const submitter = event.submitter
            try {
              while (shared.hooks.size) {
                const current = [...shared.hooks].filter(hook => !hook.input.disabled && !hook.input.readOnly)
                for (const hook of current) if (hook.draft && !hook.pending) hook.requestColor("validate")
                const pending = current.flatMap(hook => hook.pending ? [hook.pending.promise] : [])
                if (!pending.length) break
                const replies = await Promise.all(pending)
                if (replies.some(reply => reply?.failed)) return
              }
              const invalid = [...shared.hooks].find(hook => !hook.input.disabled && !hook.input.readOnly && !hook.input.validity.valid)
              if (invalid) {
                invalid.validationVisible = true
                invalid.renderColor()
                invalid.input.focus()
              } else if (shared.hooks.size) {
                shared.replaying = true
                form.requestSubmit(submitter?.form === form ? submitter : undefined)
                shared.replaying = false
              }
            } finally {
              shared.submitting = false
            }
          }
          colorForms.set(form, shared)
          form.addEventListener("submit", shared.listener, true)
        }
        shared.hooks.add(this)
      }
    }

    const incoming = JSON.parse(this.el.dataset.colorState)
    const value = this.editable ? this.input.value : this.input.textContent
    if (!this.editable) {
      this.pending?.resolve(null)
      this.revision++
      this.pending = null
      this.draft = false
    }
    if (!this.editable || !this.state || (!this.draft && !this.pending && value !== this.value)) {
      this.state = incoming
      this.value = incoming.value
      this.format = incoming.format
      this.error = incoming.valid ? "" : incoming.error
      this.validationVisible = !!this.error
      this.draft = false
      this.preview = null
      if (this.editable) this.input.value = this.value
    } else if (this.editable && value !== this.value) {
      this.input.value = this.value
    }
    this.renderColor()
  },

  requestColor(operation, detail = {}) {
    if (!this.editable || this.input.disabled || this.input.readOnly) return Promise.resolve(null)
    const input = this.input
    this.pending?.resolve(null)
    const request = {revision: this.revision, value: input.value, format: this.format, draft: this.draft, operation}
    this.pending = request
    request.promise = new Promise(resolve => {
      request.resolve = resolve
      this.pushEvent("color_input", {id: this.el.id, selector_id: this.el.dataset.colorSpaceId, value: request.value, format: request.format, operation, ...detail}).then(reply => {
        if (this.destroyedInput || this.pending !== request || this.revision !== request.revision || this.input !== input || input.value !== request.value) {
          if (this.pending === request) {
            this.pending = null
            this.draft = true
          }
          resolve(null)
          return
        }
        this.pending = null
        this.draft = false
        this.validationVisible = true
        if (reply.valid) {
          this.state = reply
          this.value = reply.value
          this.format = reply.format
          this.error = ""
          this.preview = null
          input.value = reply.value
          if (this.spaceInput) this.spaceInput.value = reply.format
          if (this.spaceText) this.spaceText.value = reply.label
          this.renderColor()
          if (operation !== "validate" || request.draft || reply.format !== request.format) {
            this.applying = true
            input.dispatchEvent(new Event("input", {bubbles: true}))
            input.dispatchEvent(new Event("blur"))
            this.applying = false
          }
        } else {
          this.error = reply.error
          this.preview = null
          this.renderColor()
        }
        resolve(reply)
      }, () => {
        if (this.destroyedInput || this.pending !== request || this.revision !== request.revision || this.input !== input || input.value !== request.value) {
          if (this.pending === request) {
            this.pending = null
            this.draft = true
          }
          resolve(null)
          return
        }
        this.pending = null
        this.draft = true
        this.validationVisible = true
        this.error = "The color could not be checked. Try again."
        this.preview = null
        this.renderColor()
        resolve({failed: true})
      })
    })
    return request.promise
  },

  renderColor() {
    if (this.formatLabel) this.formatLabel.textContent = this.state.label
    const preview = this.preview || (!this.error && this.state)
    this.el.toggleAttribute("data-color-empty", !preview?.swatch)
    if (preview?.swatch) this.swatch.style.setProperty("--input-color", preview.swatch)
    else this.swatch.style.removeProperty("--input-color")
    if (!this.editable) return

    const requiredEmpty = this.input.required && !this.value.trim()
    const error = this.validationVisible ? this.error || (requiredEmpty ? "Enter a color." : "") : ""
    this.input.setCustomValidity(this.error || (requiredEmpty ? "Enter a color." : ""))
    this.input.setAttribute("aria-invalid", error || this.el.dataset.colorServerInvalid === "true" ? "true" : "false")
    this.errorText.textContent = error
    this.errorText.hidden = !error || this.el.dataset.colorServerInvalid === "true"

    const unavailable = this.input.disabled || this.input.readOnly
    this.trigger.disabled = unavailable
    this.spaceText.disabled = unavailable
    if (unavailable && this.popover.matches(":popover-open")) this.popover.hidePopover()
    if (preview?.rgba) {
      this.updatingPicker = true
      this.picker.color = preview.rgba
      this.updatingPicker = false
    }
    if (this.popover.matches(":popover-open")) this.positionPicker()
  },

  positionPicker() {
    if (!this.popover?.matches(":popover-open")) return
    const bounds = this.trigger.getBoundingClientRect()
    this.popover.style.maxWidth = `${Math.max(0, window.innerWidth - 16)}px`
    this.popover.style.maxHeight = ""
    const width = this.popover.getBoundingClientRect().width
    const style = getComputedStyle(this.popover)
    const height = this.popover.scrollHeight + parseFloat(style.borderTopWidth) + parseFloat(style.borderBottomWidth)
    const below = Math.max(0, window.innerHeight - bounds.bottom - 12)
    const above = Math.max(0, bounds.top - 12)
    const openAbove = height > below && above > below
    const availableHeight = openAbove ? above : below
    this.popover.style.maxHeight = `${availableHeight}px`
    this.popover.style.left = `${Math.max(8, Math.min(bounds.left, window.innerWidth - width - 8))}px`
    this.popover.style.top = `${openAbove ? bounds.top - 4 - Math.min(height, availableHeight) : bounds.bottom + 4}px`
  },
}

export default ColorInput

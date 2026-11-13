const pad = (n) => String(n).padStart(2, "0")

const parseInitial = (mode, value) => {
  if (!value) return {dates: [], time: ""}
  if (mode === "date" || mode === "datetime-local") {
    const m = mode === "date"
      ? value.match(/^(\d{4}-\d{2}-\d{2})$/)
      : value.match(/^(\d{4}-\d{2}-\d{2})[T ]((?:[01]\d|2[0-3]):[0-5]\d)(?::[0-5]\d(?:\.\d+)?)?$/)
    if (!m) return {dates: [], time: ""}
    const day = new Date(`${m[1]}T00:00:00Z`)
    if (Number.isNaN(day.getTime()) || day.toISOString().slice(0, 10) !== m[1]) return {dates: [], time: ""}
    return {dates: [m[1]], time: m[2] || "", year: day.getUTCFullYear(), month: day.getUTCMonth()}
  }
  if (mode === "time") {
    const m = value.match(/^((?:[01]\d|2[0-3]):[0-5]\d)(?::[0-5]\d(?:\.\d+)?)?$/)
    return m ? {dates: [], time: m[1]} : {dates: [], time: ""}
  }
  if (mode === "week") {
    const m = value.match(/^(\d{4})-W(\d{2})$/)
    if (!m) return {dates: [], time: ""}
    const year = parseInt(m[1], 10)
    const week = parseInt(m[2], 10)
    const simple = new Date(Date.UTC(year, 0, 4 + (week - 1) * 7))
    const dow = simple.getUTCDay()
    const monday = new Date(simple)
    monday.setUTCDate(simple.getUTCDate() - ((dow + 6) % 7))
    return {dates: [], time: "", year: monday.getUTCFullYear(), month: monday.getUTCMonth(), selectedWeek: {year, week}}
  }
  if (mode === "month") {
    const m = value.match(/^(\d{4})-(\d{2})$/)
    return m ? {year: parseInt(m[1], 10), month: parseInt(m[2], 10) - 1} : {}
  }
  return {dates: [], time: ""}
}

const setValue = (input, value) => {
  if (input.matches(":disabled")) return
  input.value = value
  input.setAttribute("value", value)
  input.dispatchEvent(new Event("input", {bubbles: true}))
  input.dispatchEvent(new Event("change", {bubbles: true}))
}

const VCalendar = {
  async mounted() {
    const input = this.el
    this.popover = document.getElementById(`${input.id}-calendar`)
    input.value = input.dataset.vcValue ?? input.value
    input.setAttribute("value", input.value)
    this.value = input.value
    this.serverValue = input.dataset.vcValue ?? input.value
    this.serverTimezone = input.dataset.vcTimezone
    this.serverToday = input.dataset.vcToday
    this.clearRoot = input.closest("[data-core-input]")
    this.onInput = event => {
      if (event.target !== input || input.value === this.value) return
      this.value = input.value
      if (input.value) return
      this.selectedWeek = null
      this.calendar?.set({selectedDates: [], selectedTime: "00:00"}, {year: false, month: false, dates: true, time: true, locale: false})
      if (this.popover.matches(":popover-open")) this.popover.hidePopover()
    }
    this.onClear = event => {
      if (event.target !== this.clearRoot) return
      event.preventDefault()
      if (this.clearRoot.dataset.inputClearable !== "true" || input.matches(":disabled")) return
      setValue(input, "")
      input.dispatchEvent(new Event("blur"))
    }
    input.addEventListener("input", this.onInput)
    input.addEventListener("change", this.onInput)
    this.clearRoot.addEventListener("input:clear", this.onClear)
    const {Calendar, time, weeks} = await import("vanilla-calendar-pro")
    if (this.disposed) return
    const serverValue = input.dataset.vcValue ?? input.value
    if (serverValue !== this.serverValue) {
      input.value = serverValue
      input.setAttribute("value", serverValue)
      this.value = serverValue
    }
    this.serverValue = serverValue
    this.serverTimezone = input.dataset.vcTimezone
    this.serverToday = input.dataset.vcToday
    const mode = input.dataset.vcMode
    const initial = parseInitial(mode, input.value)

    this.selectedWeek = initial.selectedWeek ?? null

    const markWeek = (main) => {
      if (!main) return
      main.querySelectorAll("[data-vc-week-number]").forEach(el => {
        el.removeAttribute("data-vc-week-selected")
      })
      if (this.selectedWeek == null) return
      main.querySelectorAll("[data-vc-week-number]").forEach(el => {
        if (Number(el.dataset.vcWeekNumber) === this.selectedWeek.week && Number(el.dataset.vcWeekYear) === this.selectedWeek.year) {
          el.setAttribute("data-vc-week-selected", "")
        }
      })
    }

    this.weekObserver = null

    const onRender = (self) => {
      const main = self?.context?.mainElement
      if (main instanceof HTMLElement && main.dataset.vc === "calendar") {
        main.setAttribute("role", "dialog")
        markWeek(main)
        this.positionPopover()
        if (mode === "week" && !this.weekObserver) {
          this.weekObserver = new MutationObserver(() => markWeek(main))
          this.weekObserver.observe(main, {childList: true, subtree: true})
        }
      }
    }

    const base = {
      inputMode: false,
      selectedTheme: this.popover.dataset.vcTheme,
      labels: {application: this.popover.getAttribute("aria-label")},
      ...(input.dataset.vcToday ? {dateToday: input.dataset.vcToday} : {}),
      onInit: onRender,
      onUpdate: onRender,
    }

    const opts =
      mode === "date" ? {
        ...base,
        type: "default",
        selectionDatesMode: "single",
        selectedDates: initial.dates,
        selectedYear: initial.year,
        selectedMonth: initial.month,
        onClickDate: (self) => {
          const [d] = self.context.selectedDates
          if (d) setValue(input, d)
          this.popover.hidePopover()
        },
      }
      : mode === "datetime-local" ? {
        ...base,
        extensions: [time],
        type: "default",
        selectionDatesMode: "single",
        selectionTimeMode: 24,
        selectedDates: initial.dates,
        selectedTime: initial.time || "00:00",
        selectedYear: initial.year,
        selectedMonth: initial.month,
        onClickDate: (self) => {
          const [d] = self.context.selectedDates
          const t = self.context.selectedTime || "00:00"
          if (d) setValue(input, `${d}T${t}`)
        },
        onChangeTime: (self) => {
          const [d] = self.context.selectedDates
          const t = self.context.selectedTime || "00:00"
          if (d) setValue(input, `${d}T${t}`)
        },
      }
      : mode === "time" ? {
        ...base,
        extensions: [time],
        type: "default",
        selectionDatesMode: false,
        selectionMonthsMode: false,
        selectionYearsMode: false,
        selectionTimeMode: 24,
        selectedTime: initial.time || "00:00",
        onChangeTime: (self) => {
          setValue(input, self.context.selectedTime || "00:00")
        },
      }
      : mode === "week" ? {
        ...base,
        extensions: [weeks],
        type: "default",
        selectionDatesMode: false,
        enableWeekNumbers: true,
        selectedYear: initial.year,
        selectedMonth: initial.month,
        onClickWeekNumber: (self, weekNumber, year) => {
          this.selectedWeek = {year, week: weekNumber}
          markWeek(self?.context?.mainElement)
          setValue(input, `${year}-W${pad(weekNumber)}`)
          this.popover.hidePopover()
        },
      }
      : {
        ...base,
        type: "month",
        selectionDatesMode: false,
        selectionMonthsMode: true,
        selectedYear: initial.year,
        selectedMonth: initial.month,
        onClickMonth: (self) => {
          const y = self.context.selectedYear
          const m = self.context.selectedMonth
          if (y != null && m != null) setValue(input, `${y}-${pad(m + 1)}`)
          this.popover.hidePopover()
        },
      }

    this.calendar = new Calendar(this.popover, opts)
    this.calendar.init()

    this.viewport = window.visualViewport
    this.onReposition = () => this.positionPopover()
    this.onClick = () => {
      if (!input.matches(":disabled") && !this.popover.matches(":popover-open")) {
        this.popover.showPopover({source: input})
        this.positionPopover()
      }
    }
    this.onKeydown = event => {
      if (input.matches(":disabled") || !["ArrowUp", "ArrowDown", "ArrowLeft", "ArrowRight"].includes(event.key)) return
      this.onClick()
      const control = [...this.popover.querySelectorAll("button, input, [tabindex]")].find(el =>
        el.tabIndex >= 0 && !el.matches(":disabled") && el.getAttribute("aria-disabled") !== "true" && el.getClientRects().length,
      )
      if (control) {
        event.preventDefault()
        control.focus({preventScroll: true})
      }
    }
    this.onBeforeToggle = event => {
      if (event.newState === "open" && input.matches(":disabled")) {
        event.preventDefault()
        return
      }
      input.setAttribute("aria-expanded", String(event.newState === "open"))
      if (event.newState === "open") {
        window.addEventListener("scroll", this.onReposition, true)
        window.addEventListener("resize", this.onReposition)
        this.viewport?.addEventListener("scroll", this.onReposition)
        this.viewport?.addEventListener("resize", this.onReposition)
      } else {
        window.removeEventListener("scroll", this.onReposition, true)
        window.removeEventListener("resize", this.onReposition)
        this.viewport?.removeEventListener("scroll", this.onReposition)
        this.viewport?.removeEventListener("resize", this.onReposition)
        this.popover.removeAttribute("data-flip")
        this.popover.style.maxHeight = ""
      }
    }
    input.addEventListener("click", this.onClick)
    input.addEventListener("keydown", this.onKeydown)
    this.popover.addEventListener("beforetoggle", this.onBeforeToggle)
  },
  positionPopover() {
    if (!this.popover.matches(":popover-open")) return
    const control = this.el.getBoundingClientRect()
    const height = this.popover.scrollHeight + this.popover.offsetHeight - this.popover.clientHeight
    const style = getComputedStyle(this.popover)
    const gap = (parseFloat(style.marginTop) || 0) + (parseFloat(style.marginBottom) || 0)
    const viewportTop = window.visualViewport?.offsetTop || 0
    const viewportHeight = window.visualViewport?.height || window.innerHeight
    const below = viewportTop + viewportHeight - control.bottom - gap
    const above = control.top - viewportTop - gap
    const flip = below < height && above > below
    this.popover.toggleAttribute("data-flip", flip)
    this.popover.style.maxHeight = `${Math.max(flip ? above : below, 0)}px`
  },
  updated() {
    if (!this.calendar) return
    const input = this.el
    if (input.matches(":disabled") && this.popover.matches(":popover-open")) this.popover.hidePopover()
    const value = input.dataset.vcValue ?? input.value
    const timezone = input.dataset.vcTimezone
    const today = input.dataset.vcToday
    const selectionChanged = value !== this.serverValue || timezone !== this.serverTimezone
    const todayChanged = today !== this.serverToday
    this.serverValue = value
    this.serverTimezone = timezone
    this.serverToday = today
    if (!selectionChanged && !todayChanged) return

    if (!selectionChanged) {
      this.calendar.set({dateToday: today}, {year: false, month: false, dates: false, time: false, locale: false})
      return
    }

    input.value = value
    this.value = value
    input.setAttribute("value", value)
    const initial = parseInitial(input.dataset.vcMode, value)
    this.selectedWeek = initial.selectedWeek ?? null
    this.calendar.set({
      selectedDates: initial.dates ?? [],
      selectedTime: initial.time || "00:00",
      selectedYear: initial.year,
      selectedMonth: initial.month,
      dateToday: today,
    }, {year: true, month: true, dates: true, time: true, locale: false})
  },
  destroyed() {
    this.disposed = true
    this.el.removeEventListener("click", this.onClick)
    this.el.removeEventListener("keydown", this.onKeydown)
    this.el.removeEventListener("input", this.onInput)
    this.el.removeEventListener("change", this.onInput)
    this.clearRoot.removeEventListener("input:clear", this.onClear)
    this.popover.removeEventListener("beforetoggle", this.onBeforeToggle)
    window.removeEventListener("scroll", this.onReposition, true)
    window.removeEventListener("resize", this.onReposition)
    this.viewport?.removeEventListener("scroll", this.onReposition)
    this.viewport?.removeEventListener("resize", this.onReposition)
    if (this.popover.matches(":popover-open")) this.popover.hidePopover()
    this.weekObserver?.disconnect()
    this.calendar?.destroy()
  },
}

export default VCalendar

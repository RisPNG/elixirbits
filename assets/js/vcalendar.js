import {Calendar} from "vanilla-calendar-pro"

const pad = (n) => String(n).padStart(2, "0")

const parseInitial = (mode, value) => {
  if (!value) return {dates: [], time: ""}
  if (mode === "date") {
    return /^\d{4}-\d{2}-\d{2}$/.test(value) ? {dates: [value], time: ""} : {dates: [], time: ""}
  }
  if (mode === "datetime-local") {
    const m = value.match(/^(\d{4}-\d{2}-\d{2})[T ](\d{2}:\d{2})/)
    return m ? {dates: [m[1]], time: m[2]} : {dates: [], time: ""}
  }
  if (mode === "time") {
    return /^\d{2}:\d{2}$/.test(value) ? {dates: [], time: value} : {dates: [], time: ""}
  }
  if (mode === "week") {
    const m = value.match(/^(\d{4})-W(\d{2})$/)
    if (!m) return {dates: [], time: ""}
    const year = parseInt(m[1], 10)
    const week = parseInt(m[2], 10)
    const simple = new Date(Date.UTC(year, 0, 1 + (week - 1) * 7))
    const dow = simple.getUTCDay()
    const monday = new Date(simple)
    monday.setUTCDate(simple.getUTCDate() - ((dow + 6) % 7))
    return {dates: [], time: "", year: monday.getUTCFullYear(), month: monday.getUTCMonth(), week}
  }
  if (mode === "month") {
    const m = value.match(/^(\d{4})-(\d{2})$/)
    return m ? {year: parseInt(m[1], 10), month: parseInt(m[2], 10) - 1} : {}
  }
  return {dates: [], time: ""}
}

const setValue = (input, value) => {
  input.value = value
  input.dispatchEvent(new Event("input", {bubbles: true}))
  input.dispatchEvent(new Event("change", {bubbles: true}))
}

if (typeof HTMLElement !== "undefined" && !HTMLElement.prototype._vcFocusPatched) {
  HTMLElement.prototype._vcFocusPatched = true
  const origFocus = HTMLElement.prototype.focus
  HTMLElement.prototype.focus = function(opts) {
    if (this.closest && this.closest("[data-vc=calendar]")) {
      return origFocus.call(this, { ...(opts || {}), preventScroll: true })
    }
    return origFocus.call(this, opts)
  }
}

const VCalendar = {
  mounted() {
    const input = this.el
    const mode = input.dataset.vcMode
    const initial = parseInitial(mode, input.value)

    let selectedWeek = initial.week ?? null

    const markWeek = (main) => {
      if (!main) return
      main.querySelectorAll("[data-vc-week-number]").forEach(el => {
        el.removeAttribute("data-vc-week-selected")
      })
      if (selectedWeek == null) return
      main.querySelectorAll("[data-vc-week-number]").forEach(el => {
        if (parseInt(el.textContent.trim(), 10) === selectedWeek) {
          el.setAttribute("data-vc-week-selected", "")
        }
      })
    }

    this.weekObserver = null

    const markMode = (self) => {
      const main = self?.context?.mainElement
      if (main && main instanceof HTMLElement) {
        main.setAttribute("data-vc-mode", mode)
        main.classList.add(`vc-mode-${mode}`)
        const w = input.offsetWidth
        if (w > 0) {
          main.style.minWidth = `${w}px`
          main.style.width = `${w}px`
        }
        markWeek(main)
        if (mode === "week" && !this.weekObserver) {
          this.weekObserver = new MutationObserver(() => markWeek(main))
          this.weekObserver.observe(main, {childList: true, subtree: true})
        }
      }
    }

    const base = {
      inputMode: true,
      openOnFocus: false,
      positionToInput: ["bottom", "left"],
      onInit: markMode,
      onShow: markMode,
      onUpdate: markMode,
    }

    const opts =
      mode === "date" ? {
        ...base,
        type: "default",
        selectionDatesMode: "single",
        selectedDates: initial.dates,
        onClickDate: (self) => {
          const [d] = self.context.selectedDates
          if (d) setValue(input, d)
          self.hide()
        },
      }
      : mode === "datetime-local" ? {
        ...base,
        type: "default",
        selectionDatesMode: "single",
        selectionTimeMode: 24,
        selectedDates: initial.dates,
        selectedTime: initial.time || "00:00",
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
        type: "default",
        selectionDatesMode: false,
        enableWeekNumbers: true,
        selectedYear: initial.year,
        selectedMonth: initial.month,
        onClickWeekNumber: (self, weekNumber, year) => {
          selectedWeek = weekNumber
          markWeek(self?.context?.mainElement)
          setValue(input, `${year}-W${pad(weekNumber)}`)
          self.hide()
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
          self.hide()
        },
      }

    this.calendar = new Calendar(input, opts)
    this.calendar.init()
  },
  destroyed() {
    this.weekObserver?.disconnect()
    this.calendar?.destroy()
  },
}

export default VCalendar

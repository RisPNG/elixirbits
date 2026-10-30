import test from "node:test"
import assert from "node:assert/strict"
import {readFile} from "node:fs/promises"

const loadHook = async () => {
  const source = await readFile(new URL("../js/flash_auto_dismiss.js", import.meta.url), "utf8")
  return (await import(`data:text/javascript;base64,${Buffer.from(source).toString("base64")}`)).default
}

test("replacement messages reset dismissal even when the text and kind are identical", async () => {
  const originalWindow = globalThis.window
  const originalDocument = globalThis.document
  const timers = new Map()
  const events = new Map()
  let nextTimer = 0
  let clicks = 0
  const notice = {dataset: {duration: "5000", flashKey: "info"}, click() { clicks++ }}
  const connection = {hidden: false}

  globalThis.window = {
    setTimeout(callback, duration) {
      const id = ++nextTimer
      timers.set(id, {callback, duration})
      return id
    },
    clearTimeout(id) { timers.delete(id) },
  }
  globalThis.document = {querySelectorAll: () => [notice, connection]}

  try {
    const hook = await loadHook()
    const context = {
      ...hook,
      el: notice,
      handleEvent(name, callback) { events.set(name, callback); return name },
      removeHandleEvent(name) { events.delete(name) },
      js() {
        return {
          hide(element) { element.hidden = true },
          show(element) { element.hidden = false },
        }
      },
    }

    context.mounted()
    const firstTimer = context.timeout
    assert.equal(timers.get(firstTimer).duration, 5000)

    events.get("flash:replace")({kind: "error"})
    assert.equal(context.timeout, firstTimer)

    events.get("flash:replace")({kind: "info"})
    assert.equal(timers.has(firstTimer), false)
    assert.equal(timers.size, 1)
    assert.equal(connection.hidden, true)
    assert.equal(notice.hidden, false)

    const replacementTimer = context.timeout
    events.get("flash:replace")({kind: "info"})
    assert.equal(timers.has(replacementTimer), false)
    assert.equal(timers.size, 1)

    notice.dataset.duration = "1200"
    context.updated()
    assert.equal(timers.get(context.timeout).duration, 1200)
    const timer = timers.get(context.timeout)
    timers.delete(context.timeout)
    timer.callback()
    assert.equal(clicks, 1)

    context.destroyed()
    assert.equal(timers.size, 0)
    assert.equal(events.size, 0)
  } finally {
    globalThis.window = originalWindow
    globalThis.document = originalDocument
  }
})

test("disconnecting cancels stale dismissal and only a new flash restarts it", async () => {
  const originalWindow = globalThis.window
  const originalDocument = globalThis.document
  const timers = new Map()
  let nextTimer = 0
  let replace
  const notice = {dataset: {duration: "8000", flashKey: "error"}, click() {}}

  globalThis.window = {
    setTimeout(callback, duration) {
      const id = ++nextTimer
      timers.set(id, {callback, duration})
      return id
    },
    clearTimeout(id) { timers.delete(id) },
  }
  globalThis.document = {querySelectorAll: () => [notice]}

  try {
    const hook = await loadHook()
    const context = {
      ...hook,
      el: notice,
      handleEvent(_name, callback) { replace = callback; return "replacement" },
      removeHandleEvent() {},
      js() { return {hide() {}, show(element) { element.hidden = false }} },
    }

    context.mounted()
    context.disconnected()
    notice.hidden = true
    assert.equal(timers.size, 0)
    assert.equal(notice.hidden, true)

    replace({kind: "error"})
    assert.equal(timers.size, 1)
    assert.equal(notice.hidden, false)
    assert.equal(timers.get(context.timeout).duration, 8000)

    notice.dataset.duration = "0"
    context.updated()
    assert.equal(timers.size, 0)
    context.destroyed()
  } finally {
    globalThis.window = originalWindow
    globalThis.document = originalDocument
  }
})

import test from "node:test"
import assert from "node:assert/strict"
import {readFile} from "node:fs/promises"
import {runInNewContext} from "node:vm"

const template = await readFile(new URL("../../lib/elixirbits_web/components/layouts/root.html.heex", import.meta.url), "utf8")
const script = template.match(/<script>\s*([\s\S]*?)<\/script>/)[1]

function openPage({saved, initial, dark = false, reduced = false, supported = true} = {}) {
  const attributes = new Map(initial ? [["data-theme", initial]] : [])
  const storage = new Map(saved ? [["phx:theme", saved]] : [])
  const listeners = new Map()
  const transitions = []
  const document = {
    documentElement: {
      getAttribute: name => attributes.get(name) ?? null,
      hasAttribute: name => attributes.has(name),
      setAttribute: (name, value) => attributes.set(name, value),
      removeAttribute: name => attributes.delete(name),
    },
  }

  if (supported) {
    document.startViewTransition = update => {
      const ready = Promise.withResolvers()
      const finished = Promise.withResolvers()
      const transition = {
        ready: ready.promise,
        finished: finished.promise,
        skipped: false,
        skipTransition() {
          this.skipped = true
          ready.reject(new Error("Transition skipped"))
        },
        update() {
          update()
          if (!this.skipped) ready.resolve()
        },
        finish() {
          finished.resolve()
        },
      }
      transitions.push(transition)
      return transition
    }
  }

  runInNewContext(script, {
    document,
    localStorage: {
      getItem: name => storage.get(name) ?? null,
      setItem: (name, value) => storage.set(name, value),
      removeItem: name => storage.delete(name),
    },
    window: {
      matchMedia: query => ({matches: query.includes("color-scheme") ? dark : reduced}),
      addEventListener: (name, callback) => listeners.set(name, callback),
    },
  })

  return {
    attributes,
    storage,
    transitions,
    choose(theme) {
      listeners.get("phx:set-theme")({target: {dataset: {phxTheme: theme}}})
    },
    synchronize(theme, key = "phx:theme") {
      listeners.get("storage")({key, newValue: theme})
    },
  }
}

test("applies the stored theme before paint and preserves an existing root theme", () => {
  const saved = openPage({saved: "dark"})
  assert.equal(saved.attributes.get("data-theme"), "dark")
  assert.equal(saved.transitions.length, 0)

  const system = openPage({dark: true})
  assert.equal(system.attributes.has("data-theme"), false)
  assert.equal(system.storage.has("phx:theme"), false)
  assert.equal(system.transitions.length, 0)

  const existing = openPage({saved: "light", initial: "dark"})
  assert.equal(existing.attributes.get("data-theme"), "dark")
  assert.equal(existing.storage.get("phx:theme"), "light")
})

test("user choices persist immediately and change the page inside the native transition", async () => {
  const page = openPage({saved: "light"})
  page.choose("dark")

  assert.equal(page.storage.get("phx:theme"), "dark")
  assert.equal(page.attributes.get("data-theme"), "light")
  assert.equal(page.transitions.length, 1)

  const [transition] = page.transitions
  transition.update()
  assert.equal(page.attributes.get("data-theme"), "dark")
  transition.finish()
  await transition.finished

  page.choose("light")
  assert.equal(transition.skipped, false)
  assert.equal(page.transitions.length, 2)
})

test("equivalent explicit and system themes update the choice without animating", () => {
  const page = openPage({saved: "dark", dark: true})
  page.choose("system")
  assert.equal(page.attributes.has("data-theme"), false)
  assert.equal(page.storage.has("phx:theme"), false)
  assert.equal(page.transitions.length, 0)

  page.choose("dark")
  assert.equal(page.attributes.get("data-theme"), "dark")
  assert.equal(page.storage.get("phx:theme"), "dark")
  assert.equal(page.transitions.length, 0)
})

test("reduced motion and unsupported browsers change themes immediately", () => {
  for (const options of [{reduced: true}, {supported: false}]) {
    const page = openPage({...options, saved: "light"})
    page.choose("dark")
    assert.equal(page.attributes.get("data-theme"), "dark")
    assert.equal(page.storage.get("phx:theme"), "dark")
    assert.equal(page.transitions.length, 0)
  }
})

test("a skipped pending callback cannot overwrite the latest user choice", async () => {
  const page = openPage({saved: "light"})
  page.choose("dark")
  const [older] = page.transitions
  page.choose("system")

  assert.equal(older.skipped, true)
  assert.equal(page.attributes.has("data-theme"), false)
  assert.equal(page.storage.has("phx:theme"), false)

  older.update()
  older.finish()
  await older.finished
  assert.equal(page.attributes.has("data-theme"), false)
  assert.equal(page.transitions.length, 1)
})

test("finishing an older animation does not lose a newer pending transition", async () => {
  const page = openPage({saved: "light"})
  page.choose("dark")
  const [older] = page.transitions
  older.update()
  page.choose("light")
  const newer = page.transitions[1]

  older.finish()
  await older.finished
  page.choose("dark")
  assert.equal(newer.skipped, true)

  newer.update()
  newer.finish()
  await newer.finished
  assert.equal(page.attributes.get("data-theme"), "dark")
  assert.equal(page.storage.get("phx:theme"), "dark")
})

test("storage changes synchronize immediately and supersede pending user transitions", async () => {
  const page = openPage({saved: "light"})
  page.choose("dark")
  const [pending] = page.transitions
  page.synchronize("light")
  assert.equal(pending.skipped, true)

  pending.update()
  pending.finish()
  await pending.finished
  assert.equal(page.attributes.get("data-theme"), "light")
  assert.equal(page.storage.get("phx:theme"), "light")

  page.synchronize("dark", "unrelated")
  assert.equal(page.attributes.get("data-theme"), "light")
  page.synchronize(null)
  assert.equal(page.attributes.has("data-theme"), false)
  assert.equal(page.storage.has("phx:theme"), false)
  assert.equal(page.transitions.length, 1)
})

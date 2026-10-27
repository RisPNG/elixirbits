import test from "node:test"
import assert from "node:assert/strict"
import {readFile} from "node:fs/promises"
import {runInNewContext} from "node:vm"

test("page loading uses the current theme colors on every navigation", async () => {
  const source = await readFile(new URL("../js/app.js", import.meta.url), "utf8")
  const window = new EventTarget()
  const root = {}
  const calls = []
  let colors = {
    "--color-brand": " rgb(86, 63, 242) ",
    "--color-dark": " rgb(0 0 0 / 0.16) ",
  }

  runInNewContext(source.replace(/^import .*$/gm, ""), {
    window,
    document: {
      documentElement: root,
      querySelector: () => ({getAttribute: () => "csrf-token"}),
    },
    getComputedStyle: element => {
      assert.equal(element, root)
      return {getPropertyValue: name => colors[name]}
    },
    topbar: {
      config: config => calls.push(["config", config.barColors[0], config.shadowColor]),
      show: delay => calls.push(["show", delay]),
      hide: () => calls.push(["hide"]),
    },
    Socket: class {},
    LiveSocket: class { connect() {} },
    PetalComboBox: {},
    colocatedHooks: {},
    FlashAutoDismiss: {},
    VCalendar: {},
    TelInput: {},
    PasswordVisibility: {},
    LiveTimer: {},
    UploadPdfPreview: {},
    FileInput: {},
    FilePreview: {},
    ColorInput: {},
    NumberInput: {},
    CinderPagination: {},
    initTooltips: () => {},
    process: {env: {NODE_ENV: "test"}},
  })

  assert.deepEqual(calls, [])
  window.dispatchEvent(new Event("phx:page-loading-start"))
  window.dispatchEvent(new Event("phx:page-loading-stop"))

  colors = {
    "--color-brand": " rgb(103, 85, 255) ",
    "--color-dark": " rgb(12 14 18 / 0.16) ",
  }
  window.dispatchEvent(new Event("phx:page-loading-start"))
  window.dispatchEvent(new Event("phx:page-loading-stop"))

  assert.deepEqual(calls, [
    ["config", "rgb(86, 63, 242)", "rgb(0 0 0 / 0.16)"],
    ["show", 300],
    ["hide"],
    ["config", "rgb(103, 85, 255)", "rgb(12 14 18 / 0.16)"],
    ["show", 300],
    ["hide"],
  ])
})

import {getFileURLForUpload} from "phoenix_live_view"

const UploadPdfPreview = {
  async mounted() {
    this.disposed = false
    const canvas = this.el.querySelector("canvas")
    const status = this.el.querySelector("[data-pdf-status]")

    try {
      const pdfjs = await import("pdfjs-dist")
      if (this.disposed) return

      pdfjs.GlobalWorkerOptions.workerSrc = new URL("./pdf.worker.js", import.meta.url).href
      const url = this.el.dataset.pdfUrl || (this.objectUrl = getFileURLForUpload(
        document.getElementById(this.el.dataset.uploadRef),
        this.el.dataset.entryRef,
      ))
      this.loadingTask = pdfjs.getDocument({
        url,
        cMapUrl: new URL("./cmaps/", import.meta.url).href,
        cMapPacked: true,
        standardFontDataUrl: new URL("./standard_fonts/", import.meta.url).href,
        wasmUrl: new URL("./wasm/", import.meta.url).href,
        iccUrl: new URL("./iccs/", import.meta.url).href,
      })

      const pdf = await this.loadingTask.promise
      if (this.disposed) return
      const page = await pdf.getPage(1)
      if (this.disposed) return

      const original = page.getViewport({scale: 1})
      const size = parseFloat(getComputedStyle(this.el).height) * Math.min(window.devicePixelRatio, 2)
      const scale = size / Math.max(original.width, original.height)
      const viewport = page.getViewport({scale})
      canvas.width = Math.ceil(viewport.width)
      canvas.height = Math.ceil(viewport.height)
      this.renderTask = page.render({canvas, viewport})
      await this.renderTask.promise
      if (this.disposed) return

      canvas.hidden = false
      status.hidden = true
    } catch (error) {
      if (!this.disposed) {
        status.textContent = error.name === "PasswordException" ? "PDF is password protected." : "PDF preview unavailable."
      }
    } finally {
      this.renderTask = null
      const task = this.loadingTask
      this.loadingTask = null
      await task?.destroy()
      if (this.objectUrl) {
        URL.revokeObjectURL(this.objectUrl)
        this.objectUrl = null
      }
    }
  },
  destroyed() {
    this.disposed = true
    this.renderTask?.cancel()
    const task = this.loadingTask
    this.loadingTask = null
    task?.destroy().catch(() => {})
    if (this.objectUrl) {
      URL.revokeObjectURL(this.objectUrl)
      this.objectUrl = null
    }
    const canvas = this.el.querySelector("canvas")
    canvas.width = 0
    canvas.height = 0
  },
}

export default UploadPdfPreview

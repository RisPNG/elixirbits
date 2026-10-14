import {getFileURLForUpload} from "phoenix_live_view"

const UploadPdfPreview = {
  async mounted() {
    this.disposed = false
    this.objectUrl = null
    const viewer = this.el.querySelector("[data-pdf-viewer]")
    const open = this.el.querySelector("[data-pdf-open]")
    const status = this.el.querySelector("[data-pdf-status]")

    try {
      let url = this.el.dataset.pdfUrl
      if (url?.startsWith("data:")) {
        const blob = await (await fetch(url)).blob()
        if (this.disposed) return
        url = this.objectUrl = URL.createObjectURL(blob)
      } else if (!url) {
        url = this.objectUrl = getFileURLForUpload(
          document.getElementById(this.el.dataset.uploadRef),
          this.el.dataset.entryRef,
        )
      }

      open.href = url
      open.hidden = false
      if (navigator.pdfViewerEnabled) {
        viewer.src = url
        viewer.hidden = false
        status.hidden = true
      } else {
        status.textContent = "Open this PDF in your browser."
      }
    } catch {
      if (!this.disposed) status.textContent = "PDF preview unavailable."
    }
  },

  destroyed() {
    this.disposed = true
    this.el.querySelector("[data-pdf-viewer]").removeAttribute("src")
    if (this.objectUrl) {
      URL.revokeObjectURL(this.objectUrl)
      this.objectUrl = null
    }
  },
}

export default UploadPdfPreview

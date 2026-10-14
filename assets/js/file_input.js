import {getFileURLForUpload} from "phoenix_live_view"

const fileInputs = new Map()

const FileInput = {
  mounted() {
    this.input = this.el.querySelector("[data-file-input]")
    this.inputId = this.input.id
    this.focused = document.activeElement === this.input && this.input.matches(":focus-visible")
    this.selection = this.el.dataset.fileSelection
    this.editorConfig = this.el.dataset.fileEditor
    this.files = Array.from(this.input.files || [])
    this.fileKeys = new WeakMap()
    this.nextFileKey = 0
    for (const file of this.files) this.fileKeys.set(file, `local-${++this.nextFileKey}`)
    this.fileNames = this.files.map(file => file.name).join(", ")
    const display = this.el.querySelector("[data-file-name]")
    this.placeholder = display?.dataset.fileDefaultName || display?.textContent || this.input.placeholder
    this.sequence = 0
    this.uploadUrls = new Map()
    this.replacements = new Map()
    this.registeredRefs = new Set(JSON.parse(this.el.dataset.fileEntryRefs))
    this.disposed = false
    this.onSelection = event => {
      if (event.target !== this.input || this.handoff || this.input.disabled) return
      if (event.type === "change" && this.ignoreNativeChange) {
        event.stopImmediatePropagation()
        this.ignoreNativeChange = false
        return
      }
      if (event.type === "input") this.ignoreNativeChange = false
      const selected = Array.from(this.input.files || [])
      if (!selected.length) return
      if (this.selection === "multiple") {
        this.sequence++
        this.editor?.destroy()
        this.fetchController?.abort()
        this.fetchController = null
        this.preparing = false
        this.files = this.el.dataset.fileUploadName ? Array.from(new Set([...this.files, ...selected])) : selected
        for (const file of this.files) if (!this.fileKeys.has(file)) this.fileKeys.set(file, `local-${++this.nextFileKey}`)
        this.fileNames = this.files.map(file => file.name).join(", ")
        const error = this.el.querySelector("[data-file-error]")
        if (error) error.hidden = true
        this.updatePreview()
      } else {
        event.stopImmediatePropagation()
        if (event.type === "input") this.ignoreNativeChange = true
        const transfer = new DataTransfer()
        for (const file of this.files) transfer.items.add(file)
        this.input.files = transfer.files
        this.receiveSelection(selected[0])
        if (event.type === "input") this.ignoreNativeChange = true
      }
    }
    this.onDrop = event => {
      if (this.input.disabled || this.selection === "multiple" || !event.dataTransfer?.files.length) return
      event.preventDefault()
      event.stopImmediatePropagation()
      this.receiveSelection(event.dataTransfer.files[0])
    }
    this.onSubmit = event => {
      if (this.preparing) {
        event.preventDefault()
        event.stopImmediatePropagation()
      }
    }
    this.onReset = () => {
      if (this.el.dataset.fileUploadName) this.resetSelection()
      else this.clearSelection(false)
    }
    this.onClick = event => {
      const previous = event.target.closest("[data-file-previous]")
      const next = event.target.closest("[data-file-next]")
      if ((previous || next) && this.items.length) {
        event.preventDefault()
        const index = this.items.findIndex(item => item.key === this.activeKey)
        const active = this.items[(index + (previous ? -1 : 1) + this.items.length) % this.items.length]
        this.activeKey = active.key
        this.activeFile = active.file || null
        this.updatePreview()
      } else if (event.target.closest("[data-file-edit]") && !this.input.disabled) {
        event.preventDefault()
        const element = event.target.closest("[data-file-item]")
        this.editSelection(element?.dataset.fileKey || this.activeKey)
      } else if (event.target.closest("[data-file-clear]") && !this.input.disabled) {
        event.preventDefault()
        if (this.el.dataset.fileUploadName) {
          const active = this.items.find(item => item.key === this.activeKey)
          active?.element?.querySelector("button[phx-click='cancel_upload'], button[phx-click='remove_upload']")?.click()
        } else this.clearSelection()
      }
    }
    this.onFocus = event => {
      if (event.target !== this.input) return
      this.focused = event.type === "focusin" && this.input.matches(":focus-visible")
      this.updatePreview()
    }
    this.el.addEventListener("input", this.onSelection, true)
    this.el.addEventListener("change", this.onSelection, true)
    this.el.addEventListener("drop", this.onDrop, true)
    this.el.addEventListener("click", this.onClick)
    this.el.addEventListener("focusin", this.onFocus)
    this.el.addEventListener("focusout", this.onFocus)
    this.form = this.input.form
    this.form?.addEventListener("submit", this.onSubmit, true)
    this.form?.addEventListener("reset", this.onReset)
    this.binding = fileInputs.get(this.inputId) || {owner: null, preview: null}
    this.binding.owner = this
    fileInputs.set(this.inputId, this.binding)
    this.updatePreview()
  },

  receiveSelection(file) {
    const maxEntries = Number(this.el.dataset.fileMaxEntries)
    if (this.selection === "singles" && maxEntries && this.files.length >= maxEntries) {
      const error = this.el.querySelector("[data-file-error]")
      error.textContent = "Cancel a selected file before adding another."
      error.hidden = false
      return
    }
    const editor = JSON.parse(this.el.dataset.fileEditor)
    if (editor && this.el.dataset.filePreview === "true" && ["image/png", "image/jpeg", "image/gif", "image/webp"].includes(file.type)) this.prepareSelection(file, editor)
    else this.acceptSelection(file)
  },

  editSelection(key) {
    const editor = JSON.parse(this.el.dataset.fileEditor)
    if (!editor || this.el.dataset.filePreview !== "true" || this.selection === "multiple" || this.input.disabled) return
    const item = this.items.find(item => item.key === key)
    if (!item || !["image/png", "image/jpeg", "image/gif", "image/webp"].includes(item.type)) return
    const file = item.file || item.ref && this.files.find(file => file._phxRef === item.ref)
    if (file) this.prepareSelection(file, editor, {file, ref: item.ref})
    else if (item.url) this.prepareSelection(item.url, editor, {url: item.url, name: item.name, type: item.type})
    else if (item.ref) {
      const url = getFileURLForUpload(this.input, item.ref)
      if (url) this.prepareSelection(url, editor, {ref: item.ref, name: item.name, type: item.type, temporaryUrl: url})
    }
  },

  async prepareSelection(file, options, source = null) {
    const sequence = ++this.sequence
    this.editor?.destroy()
    this.fetchController?.abort()
    this.fetchController = null
    this.preparing = true
    const error = this.el.querySelector("[data-file-error]")
    if (error) error.hidden = true
    try {
      if (typeof file === "string") {
        this.fetchController = new AbortController()
        const response = await fetch(file, {signal: this.fetchController.signal})
        if (!response.ok) throw new Error("The saved image could not be opened.")
        const blob = await response.blob()
        file = new File([blob], source.name, {type: source.type})
      }
      const {default: ImageEditor} = await import("./image_editor")
      if (this.disposed || sequence !== this.sequence || this.input.disabled) return
      this.editor = new ImageEditor()
      const accepted = await this.editor.edit(file, {
        ...(options === true ? {} : options),
        template: this.el.querySelector("[data-file-editor-template]"),
      })
      if (this.disposed || sequence !== this.sequence || this.input.disabled || !accepted) return
      const maxSize = Number(this.el.dataset.fileMaxSize)
      if (maxSize && accepted.size > maxSize) throw new Error("The edited image exceeds the file size limit.")
      const replacing = this.files.find(file => file === source?.file || source?.ref && file._phxRef === source.ref)
      const maxEntries = Number(this.el.dataset.fileMaxEntries)
      if (this.selection === "singles" && !replacing && maxEntries && this.files.length >= maxEntries) throw new Error("Cancel a selected file before adding another.")
      if (source?.ref && this.el.dataset.fileUploadName) {
        const target = this.input.getAttribute("phx-target")
        const payload = {ref: source.ref, upload: this.el.dataset.fileUploadName}
        if (target) {
          const replies = await this.pushEventTo(target, "cancel_upload", payload)
          const failure = replies.find(reply => reply.status === "rejected")
          if (failure) throw failure.reason
        } else await this.pushEvent("cancel_upload", payload)
        if (this.disposed || sequence !== this.sequence || this.input.disabled) return
      }
      this.acceptSelection(accepted, source)
    } catch (failure) {
      if (this.disposed || sequence !== this.sequence) return
      this.editor?.destroy()
      if (error) {
        error.textContent = failure.message || "The image could not be prepared."
        error.hidden = false
      }
    } finally {
      if (source?.temporaryUrl) URL.revokeObjectURL(source.temporaryUrl)
      if (sequence === this.sequence) {
        this.preparing = false
        this.fetchController = null
      }
    }
  },

  acceptSelection(file, source = null) {
    if (this.input.disabled) return
    this.sequence++
    this.editor?.destroy()
    this.fetchController?.abort()
    this.fetchController = null
    this.preparing = false
    this.ignoreNativeChange = false
    const index = this.files.findIndex(file => file === source?.file || source?.ref && file._phxRef === source.ref)
    const storedUrl = source?.url || this.replacements.get(this.files[index])
    if (this.selection === "single") {
      this.files = [file]
      this.replacements.clear()
    } else if (index >= 0) {
      this.replacements.delete(this.files[index])
      this.files[index] = file
    } else this.files.push(file)
    if (storedUrl) this.replacements.set(file, storedUrl)
    this.fileKeys.set(file, `local-${++this.nextFileKey}`)
    this.activeFile = file
    const error = this.el.querySelector("[data-file-error]")
    if (error) error.hidden = true
    this.handoffSelection()
  },

  handoffSelection(emit = true) {
    const transfer = new DataTransfer()
    for (const file of this.files) transfer.items.add(file)
    this.input.files = transfer.files
    this.fileNames = this.files.map(file => file.name).join(", ")
    if (emit) {
      this.handoff = true
      try {
        this.input.dispatchEvent(new Event("input", {bubbles: true}))
        this.input.dispatchEvent(new Event("change", {bubbles: true}))
      } finally {
        this.handoff = false
      }
    }
    if (this.activeFile) this.activeKey = this.activeFile._phxRef || this.fileKeys.get(this.activeFile)
    this.updatePreview()
  },

  clearSelection(emit = true) {
    this.sequence++
    this.editor?.destroy()
    this.fetchController?.abort()
    this.fetchController = null
    this.preparing = false
    this.ignoreNativeChange = false
    const file = emit && this.selection === "singles" ? this.items.find(item => item.key === this.activeKey)?.file : null
    if (file) {
      this.files = this.files.filter(selected => selected !== file)
      this.replacements.delete(file)
    } else {
      this.files = []
      this.replacements.clear()
    }
    this.activeFile = null
    this.input.value = ""
    const error = this.el.querySelector("[data-file-error]")
    if (error) error.hidden = true
    this.handoffSelection(emit)
  },

  async resetSelection() {
    const sequence = ++this.sequence
    this.editor?.destroy()
    this.fetchController?.abort()
    this.fetchController = null
    this.preparing = true
    this.ignoreNativeChange = false
    const error = this.el.querySelector("[data-file-error]")
    if (error) error.hidden = true
    const refs = new Set([...JSON.parse(this.el.dataset.fileEntryRefs), ...this.files.map(file => file._phxRef).filter(ref => ref !== undefined)])
    const canceled = new Set()
    try {
      for (const ref of refs) {
        const target = this.input.getAttribute("phx-target")
        const payload = {ref, upload: this.el.dataset.fileUploadName}
        if (target) {
          const replies = await this.pushEventTo(target, "cancel_upload", payload)
          const failure = replies.find(reply => reply.status === "rejected")
          if (failure) throw failure.reason
        } else await this.pushEvent("cancel_upload", payload)
        if (this.disposed || sequence !== this.sequence) return
        canceled.add(ref)
      }
      this.clearSelection(false)
    } catch (failure) {
      if (this.disposed || sequence !== this.sequence) return
      this.files = this.files.map(file => {
        if (!canceled.has(file._phxRef)) return file
        const restored = new File([file], file.name, {type: file.type, lastModified: file.lastModified})
        this.fileKeys.set(restored, this.fileKeys.get(file))
        if (this.replacements.has(file)) {
          this.replacements.set(restored, this.replacements.get(file))
          this.replacements.delete(file)
        }
        if (this.activeFile === file) this.activeFile = restored
        return restored
      })
      this.handoffSelection()
      if (error) {
        error.textContent = "The selected files could not be reset. Try again."
        error.hidden = false
      }
    } finally {
      if (sequence === this.sequence) this.preparing = false
    }
  },

  updatePreview() {
    const portal = this.el.querySelector("template[data-phx-portal]")
    const source = portal?.content || this.el
    const surface = this.binding.preview?.el || (!portal ? this.el.querySelector("[data-file-collection]") || this.el : null)
    if (surface) {
      surface.dataset.fileFocused = String(this.focused)
      surface.dataset.fileMode = this.el.dataset.fileMode
      if (surface !== this.el) surface.hidden = this.el.dataset.fileMode?.startsWith("hidden") || this.el.dataset.filePreview !== "true" && this.selection !== "multiple"
    }
    const links = surface?.querySelectorAll("[data-file-open][data-entry-ref]") || []
    const refs = new Set(Array.from(links, link => link.dataset.entryRef))
    for (const [ref, url] of this.uploadUrls) {
      if (!refs.has(ref)) {
        URL.revokeObjectURL(url)
        this.uploadUrls.delete(ref)
      }
    }
    for (const link of links) {
      const ref = link.dataset.entryRef
      let url = this.uploadUrls.get(ref)
      if (!url) {
        url = getFileURLForUpload(this.input, ref)
        if (url) this.uploadUrls.set(ref, url)
      }
      if (url) link.href = url
    }
    const metadata = this.el.querySelector("[data-file-replacements]")
    if (metadata) {
      const fields = []
      for (const [file, url] of this.replacements) {
        const input = document.createElement("input")
        input.type = "hidden"
        input.name = `${this.el.dataset.fileUploadName || this.input.name.replace(/\[\]$/, "")}_replacements[${file._phxRef || this.fileKeys.get(file)}]`
        input.value = url
        fields.push(input)
      }
      if (this.el.dataset.fileUploadName) {
        for (const file of this.files) {
          if (file._phxRef !== undefined) {
            const input = document.createElement("input")
            input.type = "hidden"
            input.name = `${this.el.dataset.fileUploadName}_order[]`
            input.value = file._phxRef
            fields.push(input)
          }
        }
      }
      metadata.replaceChildren(...fields)
    }
    const display = this.el.querySelector("[data-file-name]")
    const readonly = this.el.querySelector("[data-file-readonly-name]")
    const elements = Array.from(source.querySelectorAll("[data-file-item]"))
    const faces = new Map(Array.from(surface?.querySelectorAll("[data-file-item]") || [], element => [element.dataset.fileKey, element]))
    const hiddenUrls = new Set(this.replacements.values())
    const hasPending = this.files.length > 0 || elements.some(element => element.dataset.fileEntryRef)
    const items = []
    const stored = []
    const pending = new Map()
    for (const element of elements) {
      const url = element.dataset.fileUrl
      const replaced = url && (hiddenUrls.has(url) || this.selection === "single" && hasPending)
      const name = element.querySelector("[data-file-filename]")?.textContent.trim() || element.querySelector("[data-file-caption]")?.textContent.trim() || element.dataset.fileItemName
      const item = {key: element.dataset.fileKey, element: faces.get(element.dataset.fileKey), url, ref: element.dataset.fileEntryRef, type: element.dataset.fileContentType, name}
      if (item.ref) pending.set(item.ref, item)
      else if (this.selection !== "single" || !hasPending) stored.push(item)
      if (item.element) {
        item.element.hidden = !!replaced
        item.element.classList.toggle("hidden", !!replaced)
      }
    }
    for (const file of this.files) {
      const key = file._phxRef || this.fileKeys.get(file)
      const item = pending.get(file._phxRef) || {key, type: file.type, name: file.name}
      item.file = file
      pending.delete(file._phxRef)
      const source = this.replacements.get(file)
      let slot = source ? stored.findIndex(item => item.url === source) : -1
      if (slot < 0) {
        slot = this.items?.findIndex(previous => previous.file === file || previous.key === key) ?? -1
        if (slot >= stored.length) slot = -1
      }
      if (slot >= 0) {
        if (stored[slot].element) {
          stored[slot].element.hidden = true
          stored[slot].element.classList.toggle("hidden", true)
        }
        stored[slot] = item
      } else items.push(item)
    }
    items.unshift(...stored)
    items.push(...pending.values())
    const previousIndex = this.items?.findIndex(item => item.key === this.activeKey) ?? 0
    this.items = items
    if (!items.some(item => item.key === this.activeKey)) this.activeKey = items[Math.max(0, Math.min(previousIndex, items.length - 1))]?.key
    const active = items.find(item => item.key === this.activeKey)
    this.activeFile = active?.file || null
    const carousel = this.selection === "singles"
    const preview = this.el.dataset.filePreview === "true"
    const filenameMode = !preview && this.selection !== "multiple"
    const count = `${items.length} ${items.length === 1 ? "file" : "files"}`
    if (display) display.textContent = carousel && preview ? count : (filenameMode ? active?.name : this.fileNames) || display.dataset.fileDefaultName || this.placeholder
    if (readonly) readonly.textContent = carousel && preview ? count : (filenameMode ? active?.name : this.fileNames) || readonly.dataset.fileDefaultName || this.placeholder
    const position = `${items.findIndex(item => item.key === this.activeKey) + 1}/${items.length}`
    for (const element of new Set([...this.el.querySelectorAll("[data-file-position]"), ...(surface?.querySelectorAll("[data-file-position]") || [])])) element.textContent = position
    for (const item of items) {
      if (item.element) {
        const hidden = carousel && item.key !== this.activeKey
        item.element.hidden = hidden
        item.element.classList.toggle("hidden", hidden)
      }
    }
    for (const button of new Set([...this.el.querySelectorAll("[data-file-previous], [data-file-next]"), ...(surface?.querySelectorAll("[data-file-previous], [data-file-next]") || [])])) {
      if (button.dataset.fileCycleInput !== undefined) button.disabled = items.length < 2
      else button.hidden = !carousel || items.length < 2
    }
    const file = !this.el.dataset.fileUploadName && (carousel ? active?.file : this.files[0])
    const clear = this.el.querySelector("[data-file-clear]")
    if (clear) clear.hidden = this.input.disabled || (this.el.dataset.fileUploadName ? !active?.element?.querySelector("button[phx-click='cancel_upload'], button[phx-click='remove_upload']") : !file)
    if (!this.el.dataset.fileUploadName) {
      for (const stored of surface?.querySelectorAll("[data-file-stored]") || []) {
        if (stored.dataset.fileItem === undefined) stored.hidden = this.selection === "single" && this.files.length > 0
      }
    }
    const enabled = this.el.dataset.filePreview === "true" && this.selection !== "multiple"
    const region = surface?.querySelector("[data-file-preview-region]")
    const container = surface?.querySelector("[data-file-preview-container]") || region
    if (container) container.hidden = !file || !enabled
    if (this.previewRegion && this.previewRegion !== region) {
      this.previewRegion.querySelector("[data-file-preview-image]").removeAttribute("src")
      this.previewRegion.querySelector("[data-file-preview-pdf]").removeAttribute("src")
      this.previewRegion.querySelector("[data-file-preview-open]").removeAttribute("href")
    }
    if (!region) {
      if (this.objectUrl) URL.revokeObjectURL(this.objectUrl)
      this.objectUrl = null
      this.previewFile = this.previewRegion = null
      return
    }
    const image = region.querySelector("[data-file-preview-image]")
    const pdf = region.querySelector("[data-file-preview-pdf]")
    const open = region.querySelector("[data-file-preview-open]")
    const name = region.querySelector("[data-file-preview-name]")
    const caption = region.querySelector("[data-file-preview-caption]")
    const edit = region.querySelector("[data-file-edit]")
    if (edit) {
      edit.disabled = this.input.disabled
      edit.hidden = !file || !enabled || this.input.disabled || !JSON.parse(this.el.dataset.fileEditor) || !["image/png", "image/jpeg", "image/gif", "image/webp"].includes(file.type)
    }
    const previewAs = this.el.dataset.filePreviewAs || "thumbnail"
    if (caption) {
      caption.textContent = file?.name || ""
      caption.hidden = !file || !enabled || previewAs !== "thumbnail" || !(file.type.startsWith("image/") || file.type === "application/pdf")
    }
    if (this.previewFile === file && this.previewEnabled === enabled && this.previewRegion === region && this.previewAs === previewAs) return
    image.removeAttribute("src")
    pdf.removeAttribute("src")
    open.removeAttribute("href")
    image.hidden = pdf.hidden = open.hidden = true
    if (this.objectUrl) URL.revokeObjectURL(this.objectUrl)
    this.objectUrl = null
    this.previewFile = file
    this.previewEnabled = enabled
    this.previewRegion = region
    this.previewAs = previewAs
    if (!file || !enabled) return
    this.objectUrl = URL.createObjectURL(file)
    name.textContent = file.name
    name.hidden = true
    if (previewAs === "tag") {
      name.hidden = false
      open.href = this.objectUrl
      open.hidden = false
    } else if (file.type.startsWith("image/")) {
      image.src = this.objectUrl
      image.hidden = false
    } else if (file.type === "application/pdf") {
      open.href = this.objectUrl
      open.hidden = false
      if (navigator.pdfViewerEnabled) {
        pdf.src = this.objectUrl
        pdf.hidden = false
      }
    } else {
      open.href = this.objectUrl
      open.hidden = false
      name.hidden = false
    }
  },

  updated() {
    const input = this.el.querySelector("[data-file-input]")
    const selection = this.el.dataset.fileSelection
    const editorConfig = this.el.dataset.fileEditor
    if (input !== this.input || input.disabled || selection !== this.selection || editorConfig !== this.editorConfig || this.el.dataset.filePreview !== "true") {
      this.sequence++
      this.editor?.destroy()
      this.fetchController?.abort()
      this.fetchController = null
      this.preparing = false
      this.ignoreNativeChange = false
    }
    this.input = input
    this.selection = selection
    this.editorConfig = editorConfig
    if (this.el.dataset.fileUploadName) {
      const refs = new Set(JSON.parse(this.el.dataset.fileEntryRefs))
      for (const ref of refs) this.registeredRefs.add(ref)
      if (!this.preparing) {
        this.files = this.files.filter(file => !this.registeredRefs.has(file._phxRef) || refs.has(file._phxRef))
        for (const file of this.replacements.keys()) if (!this.files.includes(file)) this.replacements.delete(file)
        this.fileNames = this.files.map(file => file.name).join(", ")
      }
    }
    this.updatePreview()
  },

  destroyed() {
    this.disposed = true
    this.sequence++
    this.editor?.destroy()
    this.fetchController?.abort()
    this.fetchController = null
    this.el.removeEventListener("input", this.onSelection, true)
    this.el.removeEventListener("change", this.onSelection, true)
    this.el.removeEventListener("drop", this.onDrop, true)
    this.el.removeEventListener("click", this.onClick)
    this.el.removeEventListener("focusin", this.onFocus)
    this.el.removeEventListener("focusout", this.onFocus)
    this.form?.removeEventListener("submit", this.onSubmit, true)
    this.form?.removeEventListener("reset", this.onReset)
    if (this.binding.owner === this) {
      this.binding.owner = null
      if (this.binding.preview) this.binding.preview.el.hidden = true
      else fileInputs.delete(this.inputId)
      if (this.previewRegion) {
        this.previewRegion.querySelector("[data-file-preview-image]").removeAttribute("src")
        this.previewRegion.querySelector("[data-file-preview-pdf]").removeAttribute("src")
        this.previewRegion.querySelector("[data-file-preview-open]").removeAttribute("href")
      }
    }
    if (this.objectUrl) URL.revokeObjectURL(this.objectUrl)
    this.objectUrl = null
    for (const url of this.uploadUrls.values()) URL.revokeObjectURL(url)
    this.uploadUrls.clear()
    this.previewFile = this.previewRegion = this.activeFile = null
    this.replacements.clear()
    this.files = this.items = []
  },
}

export const FilePreview = {
  mounted() {
    this.inputId = this.el.dataset.fileInputId
    this.disposed = false
    this.binding = fileInputs.get(this.inputId) || {owner: null, preview: null}
    this.binding.preview = this
    fileInputs.set(this.inputId, this.binding)
    this.onClick = event => {
      if (this.el.dataset.fileDetached === "true") this.binding.owner?.onClick(event)
    }
    this.onDrop = event => {
      if (this.el.dataset.fileDetached === "true") this.binding.owner?.onDrop(event)
    }
    this.el.addEventListener("click", this.onClick)
    this.el.addEventListener("drop", this.onDrop, true)
    this.refreshOwner()
  },

  refreshOwner() {
    if (this.refreshing) return
    this.refreshing = true
    queueMicrotask(() => {
      this.refreshing = false
      if (this.disposed) return
      const owner = this.binding.owner
      if (owner && !owner.disposed) owner.updatePreview()
      else this.el.hidden = true
    })
  },

  updated() {
    this.refreshOwner()
  },

  reconnected() {
    this.refreshOwner()
  },

  destroyed() {
    this.disposed = true
    this.el.removeEventListener("click", this.onClick)
    this.el.removeEventListener("drop", this.onDrop, true)
    if (this.binding.preview === this) {
      this.binding.preview = null
      const owner = this.binding.owner
      if (owner && !owner.disposed) queueMicrotask(() => {
        if (!owner.disposed) owner.updatePreview()
      })
      else fileInputs.delete(this.inputId)
    }
  },
}

export default FileInput

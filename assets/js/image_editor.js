/*!
cropperjs@2.3.0, @cropper/elements@2.3.0, @cropper/utils@2.3.0, @cropper/element@2.3.0, @cropper/element-canvas@2.3.0, @cropper/element-crosshair@2.3.0, @cropper/element-grid@2.3.0, @cropper/element-handle@2.3.0, @cropper/element-image@2.3.0, @cropper/element-selection@2.3.0, @cropper/element-shade@2.3.0, @cropper/element-viewer@2.3.0, super-image-cropper (RisPNG fork), gifuct-js@2.1.2, js-binary-schema-parser@2.0.3, image-type@4.1.0, file-type@10.11.0

The MIT License (MIT)

Copyright 2015-present Chen Fengyuan
Copyright (c) 2022 陌小路
Copyright (c) 2015 Matt Way
Copyright (c) Sindre Sorhus <sindresorhus@gmail.com> (sindresorhus.com)

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
*/

import Cropper from "cropperjs"
import {SuperImageCropper} from "super-image-cropper"

export default class ImageEditor {
  edit(file, options) {
    this.destroy()
    this.file = file
    this.options = options === true ? {} : options
    this.adjustingImage = false
    this.dialog = document.createElement("dialog")
    this.dialog.className = "file-editor"
    const dialog = this.dialog
    this.dialog.setAttribute("aria-label", "Edit image")
    this.dialog.innerHTML = `
      <h2>Edit image</h2>
      <div class="file-editor-canvas"></div>
      <div class="file-editor-actions">
        <button type="button" class="button-neutral" data-editor-action="rotate-left" aria-label="Rotate left">Rotate left</button>
        <button type="button" class="button-neutral" data-editor-action="rotate-right" aria-label="Rotate right">Rotate right</button>
        <button type="button" class="button-neutral" data-editor-action="flip-horizontal">Flip horizontally</button>
        <button type="button" class="button-neutral" data-editor-action="flip-vertical">Flip vertically</button>
        <button type="button" class="button-neutral" data-editor-action="reset">Reset</button>
      </div>
      <p class="file-editor-status" role="status" aria-live="polite">Loading image...</p>
      <p class="file-editor-error" role="alert" hidden></p>
      <div class="file-editor-actions">
        <button type="button" class="button-neutral" data-editor-action="cancel">Cancel</button>
        <button type="button" class="button-primary" data-editor-action="confirm" disabled>Use image</button>
      </div>`
    document.body.appendChild(dialog)
    dialog.showModal()
    for (const button of dialog.querySelectorAll("[data-editor-action]")) button.disabled = button.dataset.editorAction !== "cancel"
    this.url = URL.createObjectURL(file)
    const image = document.createElement("img")
    image.alt = "Image to edit"
    image.src = this.url
    dialog.querySelector(".file-editor-canvas").appendChild(image)
    const ratio = this.options.ratio ?? (this.options.width && this.options.height ? this.options.width / this.options.height : NaN)
    this.cropper = new Cropper(image, {
      template: `
        <cropper-canvas>
          <cropper-image rotatable scalable translatable initial-fit="contain"></cropper-image>
          <cropper-shade hidden theme-color="var(--color-dark)"></cropper-shade>
          <cropper-handle action="select" plain></cropper-handle>
          <cropper-selection initial-coverage="0.8" ${Number.isNaN(ratio) ? "" : `aspect-ratio="${ratio}"`} min-inset="0" movable resizable precise outlined theme-color="var(--color-brand)">
            <cropper-grid role="grid" covered theme-color="var(--color-content)"></cropper-grid>
            <cropper-crosshair centered theme-color="var(--color-content)"></cropper-crosshair>
            <cropper-handle action="move" theme-color="var(--color-light)"></cropper-handle>
            <cropper-handle action="n-resize" theme-color="var(--color-brand)"></cropper-handle>
            <cropper-handle action="e-resize" theme-color="var(--color-brand)"></cropper-handle>
            <cropper-handle action="s-resize" theme-color="var(--color-brand)"></cropper-handle>
            <cropper-handle action="w-resize" theme-color="var(--color-brand)"></cropper-handle>
            <cropper-handle action="ne-resize" theme-color="var(--color-brand)"></cropper-handle>
            <cropper-handle action="nw-resize" theme-color="var(--color-brand)"></cropper-handle>
            <cropper-handle action="se-resize" theme-color="var(--color-brand)"></cropper-handle>
            <cropper-handle action="sw-resize" theme-color="var(--color-brand)"></cropper-handle>
          </cropper-selection>
        </cropper-canvas>`,
    })
    const cropperImage = this.cropper.getCropperImage()
    const selection = this.cropper.getCropperSelection()
    const canvas = this.cropper.getCropperCanvas()
    cropperImage.addEventListener("change", event => {
      if (this.dialog !== dialog || this.adjustingImage || !selection.width || !selection.height) return
      const {x, y, width, height} = event.detail
      const tolerance = 1e-6
      if (x > selection.x + tolerance || y > selection.y + tolerance || x + width < selection.x + selection.width - tolerance || y + height < selection.y + selection.height - tolerance) event.preventDefault()
    })
    selection.addEventListener("change", event => {
      if (this.dialog !== dialog) return
      const imageRect = cropperImage.getBoundingClientRect()
      const canvasRect = canvas.getBoundingClientRect()
      const {x, y, width, height} = event.detail
      const tolerance = 1e-6
      if (x < imageRect.left - canvasRect.left - tolerance || y < imageRect.top - canvasRect.top - tolerance || x + width > imageRect.right - canvasRect.left + tolerance || y + height > imageRect.bottom - canvasRect.top + tolerance) event.preventDefault()
    })
    cropperImage.$ready().then(() => {
      if (this.dialog !== dialog) return
      this.fitCropSelection()
      for (const button of dialog.querySelectorAll("[data-editor-action]")) button.disabled = false
      dialog.querySelector(".file-editor-status").textContent = "Choose the area to keep."
    }).catch(() => {
      if (this.dialog !== dialog) return
      const alert = dialog.querySelector(".file-editor-error")
      alert.textContent = "The image could not be opened."
      alert.hidden = false
      dialog.querySelector(".file-editor-status").textContent = "Choose another image or cancel."
    })
    dialog.addEventListener("cancel", event => {
      event.preventDefault()
      this.destroy()
    })
    dialog.addEventListener("click", event => {
      const action = event.target.closest("[data-editor-action]")?.dataset.editorAction
      if (!action || this.dialog !== dialog) return
      if (action === "cancel") this.destroy()
      else if (action === "rotate-left" || action === "rotate-right") {
        this.adjustingImage = true
        cropperImage.$rotate(action === "rotate-left" ? "-90deg" : "90deg")
        this.adjustingImage = false
        this.fitCropSelection()
      }
      else if (action === "flip-horizontal") cropperImage.$scale(-1, 1)
      else if (action === "flip-vertical") cropperImage.$scale(1, -1)
      else if (action === "reset") {
        this.adjustingImage = true
        cropperImage.$resetTransform().$center("contain")
        this.adjustingImage = false
        selection.$reset()
        this.fitCropSelection()
      }
      else if (action === "confirm") this.prepareImage()
    })
    return new Promise(resolve => { this.resolve = resolve })
  }

  fitCropSelection() {
    const canvas = this.cropper.getCropperCanvas().getBoundingClientRect()
    const image = this.cropper.getCropperImage().getBoundingClientRect()
    const selection = this.cropper.getCropperSelection()
    const left = Math.max(0, image.left - canvas.left)
    const top = Math.max(0, image.top - canvas.top)
    const right = Math.min(canvas.width, image.right - canvas.left)
    const bottom = Math.min(canvas.height, image.bottom - canvas.top)
    let width = Math.min(selection.width, right - left)
    let height = Math.min(selection.height, bottom - top)
    if (Number.isFinite(selection.aspectRatio)) {
      if (width / height > selection.aspectRatio) width = height * selection.aspectRatio
      else height = width / selection.aspectRatio
    }
    const x = Math.min(Math.max(selection.x, left), right - width)
    const y = Math.min(Math.max(selection.y, top), bottom - height)
    selection.$change(x, y, width, height)
  }

  async prepareImage() {
    const selection = this.cropper.getCropperSelection()
    if (!selection.width || !selection.height) return
    const dialog = this.dialog
    const canvas = this.cropper.getCropperCanvas()
    canvas.disabled = true
    for (const button of dialog.querySelectorAll("[data-editor-action]")) button.disabled = button.dataset.editorAction !== "cancel"
    const status = dialog.querySelector(".file-editor-status")
    const alert = dialog.querySelector(".file-editor-error")
    alert.hidden = true
    status.textContent = "Preparing image..."
    const processor = this.processor = new SuperImageCropper()
    const processing = this.processing = new AbortController()
    try {
      const blob = await processor.crop({
        src: this.url,
        cropperInstance: this.cropper,
        outputWidth: this.options.width,
        outputHeight: this.options.height,
        signal: processing.signal,
        outputType: "blob",
      })
      if (this.dialog !== dialog) return
      const extension = {"image/gif": "gif", "image/png": "png", "image/jpeg": "jpg", "image/webp": "webp"}[blob.type]
      const name = this.file.name.replace(/\.[^.]+$/, "") + `.${extension}`
      const file = new File([blob], name, {type: blob.type, lastModified: Date.now()})
      const resolve = this.resolve
      this.resolve = null
      this.destroy()
      resolve(file)
    } catch (error) {
      if (this.dialog !== dialog) return
      alert.textContent = error.message || "The image could not be prepared."
      alert.hidden = false
      status.textContent = "Adjust the image or try again."
      canvas.disabled = false
      for (const button of dialog.querySelectorAll("[data-editor-action]")) button.disabled = false
    } finally {
      if (this.processor === processor) {
        processor.destroy()
        this.processor = this.processing = null
      }
    }
  }

  destroy() {
    this.processing?.abort()
    this.processor?.destroy()
    this.processor = this.processing = null
    this.cropper?.destroy()
    this.cropper = null
    this.dialog?.close()
    this.dialog?.remove()
    this.dialog = null
    if (this.url) URL.revokeObjectURL(this.url)
    this.url = null
    this.file = null
    this.resolve?.(null)
    this.resolve = null
  }
}

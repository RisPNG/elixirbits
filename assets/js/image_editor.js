/*!
cropperjs@2.3.1, @cropper/elements@2.3.1, @cropper/utils@2.3.1, @cropper/element@2.3.1, @cropper/element-canvas@2.3.1, @cropper/element-crosshair@2.3.1, @cropper/element-grid@2.3.1, @cropper/element-handle@2.3.1, @cropper/element-image@2.3.1, @cropper/element-selection@2.3.1, @cropper/element-shade@2.3.1, @cropper/element-viewer@2.3.1, super-image-cropper (RisPNG fork), gifuct-js@2.1.2, js-binary-schema-parser@2.0.3, image-type@4.1.0, file-type@10.11.0, @jsquash/webp@1.5.0, libwebp

@jsquash/webp (Apache-2.0) and libwebp (BSD-3-Clause) notices are included in the cropper package and generated bundles.

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
    this.options = options
    this.adjustingImage = false
    this.dialog = document.importNode(options.template.content, true).querySelector("dialog")
    const dialog = this.dialog
    this.url = URL.createObjectURL(file)
    const image = dialog.querySelector("[data-editor-source]")
    image.src = this.url
    dialog.querySelector("cropper-image").setAttribute("src", this.url)
    const ratio = this.options.ratio ?? (this.options.width && this.options.height ? this.options.width / this.options.height : NaN)
    if (!Number.isNaN(ratio)) dialog.querySelector("cropper-selection").setAttribute("aspect-ratio", ratio)
    document.body.appendChild(dialog)
    dialog.showModal()
    this.cropper = new Cropper(image, {
      container: dialog.querySelector(".file-editor-canvas"),
      template: null,
    })
    const cropperImage = this.cropper.getCropperImage()
    const selection = this.cropper.getCropperSelection()
    const canvas = this.cropper.getCropperCanvas()
    const ratioInput = dialog.querySelector("[data-editor-action=aspect-ratio]")
    let initialCrop
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
      const {x, y, width, height} = selection
      initialCrop = {x, y, width, height}
      for (const control of dialog.querySelectorAll("[data-editor-action]")) control.disabled = false
      dialog.querySelector("[data-editor-status]").textContent = "Choose the area to keep."
    }).catch(() => {
      if (this.dialog !== dialog) return
      const alert = dialog.querySelector("[data-editor-error]")
      alert.textContent = "The image could not be opened."
      alert.hidden = false
      dialog.querySelector("[data-editor-status]").textContent = "Choose another image or cancel."
    })
    dialog.addEventListener("cancel", event => {
      event.preventDefault()
      this.destroy()
    })
    ratioInput?.addEventListener("change", () => {
      selection.aspectRatio = Number(ratioInput.value)
      if (selection.aspectRatio > 0) this.fitCropSelection(selection, true)
    })
    dialog.addEventListener("click", event => {
      const action = event.target.closest("button[data-editor-action]")?.dataset.editorAction
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
        if (ratioInput) {
          ratioInput.value = ""
          selection.aspectRatio = 0
        }
        this.fitCropSelection(initialCrop)
      }
      else if (action === "confirm") this.prepareImage()
    })
    return new Promise(resolve => { this.resolve = resolve })
  }

  fitCropSelection(region = this.cropper.getCropperSelection(), preserveCenter = false) {
    const canvas = this.cropper.getCropperCanvas().getBoundingClientRect()
    const image = this.cropper.getCropperImage().getBoundingClientRect()
    const selection = this.cropper.getCropperSelection()
    const left = Math.max(0, image.left - canvas.left)
    const top = Math.max(0, image.top - canvas.top)
    const right = Math.min(canvas.width, image.right - canvas.left)
    const bottom = Math.min(canvas.height, image.bottom - canvas.top)
    const span = Math.max(region.width, region.height)
    let width = Math.min(preserveCenter ? span : region.width, right - left)
    let height = Math.min(preserveCenter ? span : region.height, bottom - top)
    if (selection.aspectRatio > 0) {
      if (width / height > selection.aspectRatio) width = height * selection.aspectRatio
      else height = width / selection.aspectRatio
    }
    const x = preserveCenter ? region.x + (region.width - width) / 2 : region.x
    const y = preserveCenter ? region.y + (region.height - height) / 2 : region.y
    selection.$change(Math.min(Math.max(x, left), right - width), Math.min(Math.max(y, top), bottom - height), width, height)
  }

  async prepareImage() {
    const selection = this.cropper.getCropperSelection()
    if (!selection.width || !selection.height) return
    const dialog = this.dialog
    const canvas = this.cropper.getCropperCanvas()
    canvas.disabled = true
    for (const control of dialog.querySelectorAll("[data-editor-action]")) control.disabled = control.dataset.editorAction !== "cancel"
    const status = dialog.querySelector("[data-editor-status]")
    const alert = dialog.querySelector("[data-editor-error]")
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
      for (const control of dialog.querySelectorAll("[data-editor-action]")) control.disabled = false
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
    this.options = null
    this.resolve?.(null)
    this.resolve = null
  }
}

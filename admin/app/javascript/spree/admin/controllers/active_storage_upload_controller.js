import { Controller } from '@hotwired/stimulus'

import Uppy from '@uppy/core'
import Dashboard from '@uppy/dashboard'
import ImageEditor from '@uppy/image-editor'
import ActiveStorageUpload from 'spree/admin/helpers/uppy_active_storage'

export default class extends Controller {
  static targets = ['thumb', 'toolbar', 'remove', 'placeholder']

  static values = {
    fieldName: String,
    thumbWidth: Number,
    thumbHeight: Number,
    autoSubmit: Boolean,
    multiple: { type: Boolean, default: false },
    crop: { type: Boolean, default: false },
    allowedFileTypes: { type: Array, default: [] },
    closeAfterFinish: { type: Boolean, default: true },
    inline: { type: Boolean, default: false }
  }

  connect() {
    this.uppy = new Uppy({
      autoProceed: true,
      allowMultipleUploads: false,
      restrictions: {
        allowedFileTypes: this.allowedFileTypesValue.length ? this.allowedFileTypesValue : undefined
      },
      debug: true
    })

    this.uppy.use(ActiveStorageUpload, {
      directUploadUrl: document.querySelector("meta[name='direct-upload-url']").getAttribute('content'),
      crop: this.cropValue
    })

    let dashboardOptions = {}
    if (this.cropValue == true) {
      dashboardOptions = {
        autoOpen: 'imageEditor'
      }
    }

    if (this.inlineValue == true) {
      dashboardOptions.inline = true
      dashboardOptions.closeAfterFinish = false
      dashboardOptions.target = this.element
    }

    this.uppy.use(Dashboard, dashboardOptions)

    if (this.cropValue == true) {
      this.uppy.use(ImageEditor, {
        cropperOptions: {
          aspectRatio: this.thumbWidthValue / this.thumbHeightValue
        }
      })
    }

    this.uppy.on('file-editor:complete', (updatedFile) => {
      console.log('File editing complete:', updatedFile)

      this.handleUI(updatedFile)

      this.uppy.getPlugin('Dashboard').closeModal()
    })

    this.uppy.on('upload-success', (file, response) => {
      this.handleUI(file, response)
    })

    this.uppy.on('dashboard:modal-closed', () => {
      this.uppy.clear()
    })
  }

  open(event) {
    event.preventDefault()
    this.uppy.getPlugin('Dashboard').openModal()
  }

  remove(event) {
    event.preventDefault()

    if (window.confirm('Are you sure?')) {
      if (this.hasThumbTarget) {
        // handle thumb preview
        this.thumbTarget.style = 'display: none !important'
        this.thumbTarget.dataset.imageSignedId = null
        this.thumbTarget.src = ''
      }

      // hide toolbar if attached
      if (this.hasToolbarTarget) {
        this.toolbarTarget.style = 'display: none !important'
      }

      // mark for removal (on the backend)
      if (this.hasRemoveTarget) {
        this.removeTarget.value = '1'
      }

      if (this.hasPlaceholderTarget) {
        this.placeholderTarget.style.display = null
      }

      if (this.autoSubmitValue == true) {
        this.element.closest('form').requestSubmit()
      }

      this.uppy.clear()
    }
  }

  handleUI(file, response = null) {
    this.placeholderTarget.style = 'display: none !important'

    const signedId = response?.signed_id || file.response?.signed_id

    if (signedId?.length) {
      if (this.hasThumbTarget) {
        this.thumbTarget.src = URL.createObjectURL(file.data)
        this.thumbTarget.style.display = null
        this.thumbTarget.dataset.imageSignedId = signedId
        this.thumbTarget.width = this.thumbWidthValue
        this.thumbTarget.height = this.thumbHeightValue
      }

      // Remove existing hidden field for this file, if any
      const existingField = this.element.querySelector(`input[name="${this.fieldNameValue}"]`)
      if (existingField) {
        existingField.remove()
      }

      const hiddenField = document.createElement('input')

      hiddenField.setAttribute('type', 'hidden')
      hiddenField.setAttribute('value', signedId)

      if (this.multipleValue) {
        hiddenField.setAttribute('name', `${this.fieldNameValue}[]`)
      } else {
        hiddenField.setAttribute('name', this.fieldNameValue)
      }

      this.element.appendChild(hiddenField)
    }

    // show toolbar if attached
    if (this.hasToolbarTarget) {
      this.toolbarTarget.style.display = null
    }

    if (this.hasRemoveTarget) {
      this.removeTarget.value = null
    }

    if (this.autoSubmitValue == true) {
      this.element.closest('form').requestSubmit()
    }
  }
}

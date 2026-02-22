import { Controller } from '@hotwired/stimulus'
import { post } from '@rails/request.js'
import Uppy from '@uppy/core'
import Dashboard from '@uppy/dashboard'
import ActiveStorageUpload from 'spree/admin/helpers/uppy_active_storage'

export default class extends Controller {
  static values = {
    assetClass: { type: String, default: 'Spree::Image' },
    viewableId: String,
    viewableType: String,
    multiple: { type: Boolean, default: false },
    type: { type: String, default: 'image' },
    allowedFileTypes: { type: Array, default: [] },
    adminAssetsPath: String
  }

  connect() {
    this.uppy = new Uppy({
      autoProceed: true,
      allowMultipleUploads: this.multipleValue,
      debug: true,
      restrictions: {
        allowedFileTypes: this.allowedFileTypesValue.length ? this.allowedFileTypesValue : undefined
      }
    })

    this.uppy.use(ActiveStorageUpload, {
      directUploadUrl: document.querySelector("meta[name='direct-upload-url']").getAttribute('content')
    })

    this.uppy.use(Dashboard, {
      closeAfterFinish: true
    })

    this.uppy.on('upload-success', (file, response) => {
      this.handleSuccessResult(response)
    })
  }

  open(event) {
    event.preventDefault()
    this.uppy.getPlugin('Dashboard').openModal()
  }

  handleSuccessResult(response) {
    post(this.adminAssetsPathValue, {
      body: JSON.stringify({
        asset: {
          type: this.assetClassValue,
          viewable_type: this.viewableTypeValue,
          viewable_id: this.viewableIdValue,
          attachment: response.signed_id
        }
      }),
      responseKind: 'turbo-stream'
    })
  }
}

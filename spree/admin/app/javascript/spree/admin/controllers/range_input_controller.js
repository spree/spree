import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ 'input', 'preview' ]

  updatePreview() {
    this.previewTarget.innerHTML = this.inputTarget.value
  }
}

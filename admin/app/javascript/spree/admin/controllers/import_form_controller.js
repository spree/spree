import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button"]

  connect() {
    this.element.addEventListener('active-storage-upload:success', this.enableButton.bind(this))
    this.element.addEventListener('active-storage-upload:error', this.disableButton.bind(this))
  }

  disconnect() {
    this.element.removeEventListener('active-storage-upload:success', this.enableButton.bind(this))
    this.element.removeEventListener('active-storage-upload:error', this.disableButton.bind(this))
  }

  enableButton(event) {
    if (this.hasButtonTarget) {
      this.buttonTarget.disabled = false
    }
  }

  disableButton(event) {
    if (this.hasButtonTarget) {
      this.buttonTarget.disabled = true
    }
  }
}
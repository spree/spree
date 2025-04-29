import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["button"]

  connect() {
    this.element.addEventListener('submit', this.toggleDisabledButton)
  }

  disconnect() {
    this.element.removeEventListener('submit', this.toggleDisabledButton)
  }

  toggleDisabledButton = () => {
    if (this.hasButtonTarget) {
      this.buttonTarget.disabled = !this.buttonTarget.disabled
    }
  }
}

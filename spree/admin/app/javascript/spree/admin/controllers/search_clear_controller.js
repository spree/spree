import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "clear"]

  inputTargetConnected() {
    this.toggleClearButton()
  }

  toggleClearButton() {
    const hasValue = this.inputTarget.value.length > 0
    this.clearTarget.classList.toggle("hidden", !hasValue)
  }

  clear() {
    this.inputTarget.value = ""
    this.toggleClearButton()
    // Dispatch a 'search' event to trigger auto-submit
    this.inputTarget.dispatchEvent(new Event("search", { bubbles: true }))
    this.inputTarget.focus()
  }
}

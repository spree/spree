import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["checkbox"]

  connect() {
    // Controller is ready
  }

  reset(event) {
    event.preventDefault()

    // Reset all checkboxes to their default state
    this.checkboxTargets.forEach(checkbox => {
      const isDefault = checkbox.dataset.default === "true"
      checkbox.checked = isDefault
    })
  }

  selectAll(event) {
    event.preventDefault()

    this.checkboxTargets.forEach(checkbox => {
      checkbox.checked = true
    })
  }

  deselectAll(event) {
    event.preventDefault()

    this.checkboxTargets.forEach(checkbox => {
      checkbox.checked = false
    })
  }
}

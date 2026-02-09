import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="row-link"
export default class extends Controller {
  static targets = ["link"]

  openLink(event) {
    if (event.target.tagName === 'A') return

    event.preventDefault()
    if (this.linkTarget.target === '_blank') {
      window.open(this.linkTarget.href, '_blank')
      return
    }

    window.Turbo.visit(this.linkTarget.href, { action: "advance" })
  }
}

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ 'from', 'to' ]

  replace() {
    this.fromTarget.classList.add('d-none')
    this.toTarget.classList.remove('d-none')
  }

  revert() {
    this.fromTarget.classList.remove('d-none')
    this.toTarget.classList.add('d-none')
  }
}

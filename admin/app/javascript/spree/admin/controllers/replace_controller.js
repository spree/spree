import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ 'from', 'to' ]

  replace() {
    this.fromTarget.classList.add('hidden')
    this.toTarget.classList.remove('hidden', 'd-none')
  }

  revert() {
    this.fromTarget.classList.remove('hidden', 'd-none')
    this.toTarget.classList.add('hidden')
  }
}

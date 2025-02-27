import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['container', 'spinner']

  disableCart() {
    this.containerTarget.classList.add('pointer-events-none', 'opacity-50')
    this.spinnerTarget.classList.remove('hidden')
  }
}

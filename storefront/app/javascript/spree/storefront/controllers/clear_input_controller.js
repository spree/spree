import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['input', 'button']

  connect() {
    this.inputTarget.addEventListener('input', this.toggleButton)
  }

  clear() {
    this.inputTarget.value = ''
    this.inputTarget.focus()
    this.toggleButton()
  }

  toggleButton = () => {
    if (this.inputTarget.value.trim().length) {
      this.buttonTarget.classList.remove('hidden')
    } else {
      this.buttonTarget.classList.add('hidden')
    }
  }
}

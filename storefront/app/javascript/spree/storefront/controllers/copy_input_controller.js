import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['input', 'copyButton']

  connect() {
    this.copyButtonTarget.addEventListener('click', this.copyText.bind(this))
  }

  disconnect() {
    this.copyButtonTarget.removeEventListener('click', this.copyText.bind(this))
  }

  async copyText() {
    this.inputTarget.select()
    this.inputTarget.setSelectionRange(0, 99999)
    await navigator.clipboard.writeText(this.inputTarget.value)
  }
}

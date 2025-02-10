import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['input', 'item']

  connect() {
    this.inputTarget.addEventListener('input', this.filter)
  }

  disconnect() {
    this.inputTarget.removeEventListener('input', this.filter)
  }

  filter = () => {
    const query = this.inputTarget.value.toLowerCase()
    this.itemTargets.forEach((el) => {
      const text = el.dataset.text.toLowerCase()
      if (text.includes(query)) {
        el.classList.remove('hidden')
      } else {
        el.classList.add('hidden')
      }
    })
  }
}

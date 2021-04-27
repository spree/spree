import { Controller } from 'stimulus'
import { useClickOutside } from 'stimulus-use'

export default class extends Controller {
  static targets = [ 'container', 'query' ]

  get query() {
    return this.queryTarget.value.trim()
  }

  connect() {
    useClickOutside(this)
  }

  toggle() {
    if (this.containerTarget.classList.contains('shown')) {
      this.hide()
    } else {
      document.querySelector('.header-spree').classList.add('above-overlay')
      document.getElementById('overlay').classList.add('shown')
      this.containerTarget.classList.add('shown')
      this.queryTarget.focus()
    }
  }

  submit(event) {
    if (!this.query) return event.preventDefault()

    this.hide()
  }

  hide() {
    document.querySelector('.header-spree').classList.remove('above-overlay')
    document.getElementById('overlay').classList.remove('shown')
    this.containerTarget.classList.remove('shown')
  }
}

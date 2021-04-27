import { Controller } from 'stimulus'

export default class extends Controller {
  static targets = [ 'quantity' ]

  get quantity() {
    return parseInt(this.quantityTarget.value) || 1
  }

  set quantity(value) {
    this.quantityTarget.value = parseInt(value) || 1
  }

  increase() {
    this.quantity = this.quantity + 1
  }

  decrease() {
    if (this.quantity > 1) this.quantity = this.quantity - 1
  }
}

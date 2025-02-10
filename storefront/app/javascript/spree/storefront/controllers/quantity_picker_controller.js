import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ 'quantity', 'increase', 'decrease' ]

  connect() {
    if (this.quantity <= 1) this.disableButton(this.decreaseTarget)
  }

  get quantity() {
    return parseInt(this.quantityTarget.value) || 1
  }

  get maxQuantity() {
    return parseInt(this.quantityTarget.max) || 9999
  }

  set quantity(value) {
    this.quantityTarget.value = parseInt(value) || 1
  }

  increase() {
    if (this.quantity < this.maxQuantity) this.quantity = this.quantity + 1
    if (this.quantity > 1) this.enableButton(this.decreaseTarget)
    if (this.quantity == this.maxQuantity && this.increaseTarget.type != 'submit') this.disableButton(this.increaseTarget)
  }

  decrease() {
    if (this.quantity > 1) this.quantity = this.quantity - 1
    if (this.quantity == 1 && this.decreaseTarget.type != 'submit') this.disableButton(this.decreaseTarget)
    if (this.quantity < this.maxQuantity) this.enableButton(this.increaseTarget)
  }

  disableButton(button) {
    button.setAttribute('disabled', 'disabled')
    button.classList.add('opacity-50', 'cursor-not-allowed')
  }

  enableButton(button) {
    button.removeAttribute('disabled')
    button.classList.remove('opacity-50', 'cursor-not-allowed')
  }
}

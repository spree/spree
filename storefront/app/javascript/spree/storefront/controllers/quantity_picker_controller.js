import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ 'quantity', 'increase', 'decrease' ]

  static values = {
    min: { type: Number, default: 1 },
    max: { type: Number, default: 9999 }
  }

  static classes = ['disabled']

  connect() {
    if (this.quantity <= this.minValue) this.disableButton(this.decreaseTarget)
  }

  get quantity() {
    return parseInt(this.quantityTarget.value) || this.minValue
  }

  get maxQuantity() {
    return parseInt(this.quantityTarget.max) || this.maxValue
  }

  set quantity(value) {
    this.quantityTarget.value = parseInt(value) || this.minValue
  }

  increase() {
    if (this.quantity < this.maxQuantity) this.quantity = this.quantity + 1
    if (this.quantity > this.minValue) this.enableButton(this.decreaseTarget)
    if (this.quantity == this.maxQuantity && this.increaseTarget.type != 'submit') this.disableButton(this.increaseTarget)
  }

  decrease() {
    if (this.quantity > this.minValue) this.quantity = this.quantity - 1
    if (this.quantity == this.minValue && this.decreaseTarget.type != 'submit') this.disableButton(this.decreaseTarget)
    if (this.quantity < this.maxQuantity) this.enableButton(this.increaseTarget)
  }

  disableButton(button) {
    button.setAttribute('disabled', 'disabled')
    button.classList.add(...this.disabledClasses)
  }

  enableButton(button) {
    button.removeAttribute('disabled')
    button.classList.remove(...this.disabledClasses)
  }
}

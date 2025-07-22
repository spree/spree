import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['promotionEmailField']

  connect() {
    this.element.addEventListener(
      'submit',
      this.copyEmailFieldToForm.bind(this)
    )
  }

  disconnect() {
    this.element.removeEventListener(
      'submit',
      this.copyEmailFieldToForm.bind(this)
    )
  }

  copyEmailFieldToForm(e) {
    const userEmailField = document.getElementById(
      'order_ship_address_attributes_email'
    )
    if (userEmailField) {
      this.promotionEmailFieldTarget.value = userEmailField.value
    }
  }
}

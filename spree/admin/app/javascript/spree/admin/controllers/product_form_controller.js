import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = [
    'trackInventoryCheckbox',
    'quantityForm',
    'pricesForm'
  ]

  static values = {
    hasVariants: Boolean
  }

  toggleQuantityTracked() {
    this.toggleQuantityFormVisibility()

    this.dispatch('toggle-quantity-tracked')
  }

  hasVariantsValueChanged() {
    this.toggleQuantityFormVisibility()
    this.togglePricesFormVisibility()
  }

  toggleQuantityFormVisibility() {
    if (this.hasQuantityFormTarget) {
      if (!this.hasVariantsValue && this.trackInventoryCheckboxTarget.checked) {
        this.quantityFormTarget.classList.remove('hidden', 'd-none')
      } else {
        this.quantityFormTarget.classList.add('hidden')
      }
    }
  }

  togglePricesFormVisibility() {
    if (this.hasPricesFormTarget) {
      if (this.hasVariantsValue) {
        this.pricesFormTarget.classList.add('hidden')
      } else {
        this.pricesFormTarget.classList.remove('hidden', 'd-none')
      }
    }
  }
}

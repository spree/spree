import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = [
    'trackInventoryCheckbox',
    'quantityForm',
    'availableOn',
    'makeActiveAt',
    'discontinueOn',
    'status',
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

  switchAvailabilityDatesFields(event) {
    let status = event.target.value
    if (status === 'draft') {
      this.show(this.availableOnTarget)
      this.show(this.makeActiveAtTarget)
    } else if (status === 'active') {
      this.show(this.availableOnTarget)
      this.hide(this.makeActiveAtTarget)
    } else {
      this.hide(this.availableOnTarget)
      this.hide(this.makeActiveAtTarget)
    }
  }

  show(element) {
    element.classList.remove('hidden', 'd-none')
  }

  hide(element) {
    element.classList.add('hidden')
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

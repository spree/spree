import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  connect() {
    this.observer = new MutationObserver((mutations) => {
      mutations.forEach((mutation) => {
        if (mutation.target.required) {
          mutation.target.disabled = true
        }
      })
    })

    this.hideForms()
    const selectedBillingAddressType = this.element.querySelector('[name="billing_address_type"]:checked')

    if (selectedBillingAddressType) {
      const selectedBillingAddressTypeFormName = selectedBillingAddressType.dataset.orderBillingAddressFormNameParam
      if (selectedBillingAddressTypeFormName) {
        this.showForm({ params: { formName: selectedBillingAddressTypeFormName } })
      }
    }
  }

  showForm({ params: { formName } }) {
    this.hideForms()
    this.observer.disconnect()

    const form = this.element.querySelector(`[data-form="${formName}"]`)
    form.classList.remove('hidden', 'd-none')
    form.querySelectorAll('input:required, select:required').forEach((input) => (input.disabled = false))
  }

  hideForms() {
    this.observer.observe(this.element, { subtree: true, attributes: true, attributeFilter: ['required'] })

    this.element.querySelectorAll('[data-form]').forEach((form) => form.classList.add('hidden'))
    this.element.querySelectorAll('input:required, select:required').forEach((input) => (input.disabled = true))
  }
}

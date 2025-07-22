import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ["list", "newAddressForm", "addressId", "submit"]

  select(event) {
    const radio = event.target
    if (radio.value == 0) {
      this.newAddressFormTarget.classList.remove('hidden')
      this.addressIdTarget.value = null
      this.submitTarget.setAttribute('disabled', true)
    } else {
      this.newAddressFormTarget.classList.add('hidden')
      this.addressIdTarget.value = radio.value
      this.submitTarget.removeAttribute('disabled')
    }

    Array.from(document.getElementsByClassName('address-book-actions')).forEach(
      (item) => item.classList.add('hidden')
    )
    const actions = Array.from(
      radio.parentElement.getElementsByClassName('address-book-actions')
    )
    if (actions.length > 0) {
      actions[0].classList.remove('hidden')
    }
  }
}

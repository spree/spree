import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ['shippingList', 'shippingRate', 'submit']

  connect() {
    document.addEventListener('turbo:submit-end', _event => {
      this.enableShippingRates();
      this.submitTarget.disabled = false
    });
  }

  update() {
    this.disableShippingRates();
    this.submitTarget.disabled = true

    // https://discuss.hotwired.dev/t/form-submit-with-turbo-streams-response-without-redirect/3290
    const oldAction = this.element.getAttribute("action")
    this.element.action = this.element.action + '?do_not_advance=true'
    Turbo.navigator.submitForm(this.element)
    this.element.action = oldAction
  }

  enableShippingRates() {
    this.shippingListTarget.classList.remove('opacity-50');
    this.shippingListTarget.classList.remove('cursor-wait');
    this.shippingRateTargets.forEach((shippingRate) => {
      shippingRate.style.pointerEvents = 'auto';
    });
  }

  disableShippingRates() {
    this.shippingListTarget.classList.add('opacity-50');
    this.shippingListTarget.classList.add('cursor-wait');
    this.shippingRateTargets.forEach((shippingRate) => {
      shippingRate.style.pointerEvents = 'none';
    });
  }
}

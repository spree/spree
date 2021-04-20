import { Controller } from 'stimulus'
import { makeClient } from '@spree/storefront-api-v2-sdk'

export default class extends Controller {
  static targets = [ 'code', 'resultText', 'resultIcon' ]

  get code() {
    return this.codeTarget.value.trim()
  }

  set code(value) {
    this.codeTarget.value = value
  }

  initialize() {
    this.apiClient = makeClient({
      host: window.SpreeAPI.storefrontHost
    })
  }

  async apply() {
    if (!this.code) return

    const orderToken = window.SpreeAPI.orderToken

    const response = await this.apiClient.cart.applyCouponCode({ orderToken }, {
      coupon_code: this.code
    })

    this.handleResponse(response)
  }

  async remove() {
    if (!this.code) return

    const orderToken = window.SpreeAPI.orderToken

    const response = await this.apiClient.cart.removeCouponCode({ orderToken }, this.code)

    this.handleResponse(response)
  }

  handleResponse(response) {
    if (response.isFail()) {
      this.handleError(response.fail().serverResponse.data.error)
    } else {
      this.handleSuccess()
    }
  }

  handleError(error) {
    this.code = null
    this.element.classList.add('error')
    this.resultTextTarget.classList.add('alert-error')
    this.resultTextTarget.innerHTML = error
    this.resultIconTarget.src = Spree.translations.coupon_code_error_icon
  }

  handleSuccess() {
    this.code = null
    this.element.classList.remove('error')
    this.resultTextTarget.classList.remove('alert-error')
    this.resultIconTarget.remove()
    this.resultTextTarget.classList.add('alert-success')
    this.resultTextTarget.innerHTML = Spree.translations.coupon_code_applied
    window.location.reload()
  }
}

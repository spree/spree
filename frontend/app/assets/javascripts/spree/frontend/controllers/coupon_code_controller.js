Spree.stimulus.register('coupon-code', class extends Stimulus.Controller {
  static targets = [ 'code', 'resultText', 'resultIcon' ]

  get code() {
    return this.codeTarget.value.trim()
  }

  set code(value) {
    this.codeTarget.value = value
  }

  apply() {
    if (!this.code) return

    SpreeAPI.Storefront.applyCouponCode(
      this.code,
      () => this.handleSuccess(),
      (error) => this.handleError(error)
    )
  }

  remove() {
    SpreeAPI.Storefront.removeCouponCode(
      this.code,
      () => this.handleSuccess(),
      (error) => this.handleError(error)
    )
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
})

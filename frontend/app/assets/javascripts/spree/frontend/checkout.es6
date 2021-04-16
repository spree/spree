//= require spree/frontend/coupon_manager

Spree.disableSaveOnClick = function () {
  console.warn('DEPRECATION: Spree.disableSaveOnClick() will be removed in Spree 5.0')
  $('form.edit_order').on('submit', function (event) {
    if ($(this).data('submitted') === true) {
      event.preventDefault()
    } else {
      $(this).data('submitted', true)
      $(this).find(':submit, :image').removeClass('primary').addClass('disabled')
    }
  })
}

Spree.enableSave = () => {
  const submitButton = document.getElementById('checkout-submit')
  if (submitButton) submitButton.disabled = false
}

Spree.ready(() => {
  Spree.Checkout = {}

  const checkoutForm = document.getElementsByClassName('checkout-form')[0]
  if (checkoutForm) {
    // coupon code manager
    const COUPON_CODE_ELEMENTS = {
      appliedCouponCodeField: $('#order_applied_coupon_code'),
      couponCodeField: $('#order_coupon_code'),
      couponStatus: $('#coupon_status'),
      couponButton: $('#shopping-cart-coupon-code-button'),
      removeCouponButton: $('#shopping-cart-remove-coupon-code-button')
    }

    // handle coupon code apply
    if (COUPON_CODE_ELEMENTS.couponButton && COUPON_CODE_ELEMENTS.couponButton[0]) {
      COUPON_CODE_ELEMENTS.couponButton[0].addEventListener('click', (event) => {
        if (COUPON_CODE_ELEMENTS.couponCodeField && COUPON_CODE_ELEMENTS.couponCodeField[0].value.trim().length > 0) {
          event.preventDefault()

          new CouponManager(COUPON_CODE_ELEMENTS).applyCoupon(
            () => location.reload(), // success callback
            () => Spree.enableSave()
          )
        }
      })
    }
    // apply when submitting form
    checkoutForm.addEventListener('submit', (event) => {
      if (COUPON_CODE_ELEMENTS.couponCodeField && COUPON_CODE_ELEMENTS.couponCodeField[0].value.trim().length > 0) {
        event.preventDefault()

        new CouponManager(COUPON_CODE_ELEMENTS).applyCoupon(
          () => checkoutForm.submit(), // success callback,
          () => setTimeout(() => Spree.enableSave(), 500) // failure callback
        )
      }
    })

    // handle coupon code removal
    if (COUPON_CODE_ELEMENTS.removeCouponButton && COUPON_CODE_ELEMENTS.removeCouponButton[0]) {
      COUPON_CODE_ELEMENTS.removeCouponButton[0].addEventListener('click', (event) => {
        event.preventDefault()

        new CouponManager(COUPON_CODE_ELEMENTS).removeCoupon(
          () => location.reload() // success callback
        )
      })
    }
  }
})

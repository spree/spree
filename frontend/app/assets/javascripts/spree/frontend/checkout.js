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

Spree.enableSave = function () {
  $('#checkout form').data('submitted', false).find(':submit, :image').attr('disabled', false).addClass('primary').removeClass('disabled')
}

Spree.ready(function () {
  Spree.Checkout = {}

  var checkoutForm = $('form.checkout-form')
  if (checkoutForm.length) {
    $('form.checkout-form #shopping-cart-coupon-code-button').off('click').on('click', function(event) {
      event.preventDefault()

      var input = {
        appliedCouponCodeField: $('#order_applied_coupon_code'),
        couponCodeField: $('#order_coupon_code'),
        couponStatus: $('#coupon_status'),
        couponButton: $('#shopping-cart-coupon-code-button'),
        removeCouponButton: $('#shopping-cart-remove-coupon-code-button')
      }

      if ($.trim(input.couponCodeField.val()).length && new CouponManager(input).applyCoupon()) {
        location.reload();
        return true
      } else {
        return false
      }
    })

    $('form.checkout-form #shopping-cart-remove-coupon-code-button').off('click').on('click', function(event) {
      var input = {
        appliedCouponCodeField: $('#order_applied_coupon_code'),
        couponCodeField: $('#order_coupon_code'),
        couponStatus: $('#coupon_status'),
        couponButton: $('#shopping-cart-coupon-code-button'),
        removeCouponButton: $('#shopping-cart-remove-coupon-code-button')
      }

      if (new CouponManager(input).removeCoupon()) {
        location.reload()
        return true
      } else {
        event.preventDefault()
        return false
      }
    })
  }

  return Spree.Checkout
})

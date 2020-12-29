/* global order_number, show_flash */
$(function () {
  $('[data-hook=adjustments_new_coupon_code] #add_coupon_code').click(function () {
    var couponCode = $('#coupon_code').val()
    if (couponCode.length === 0) {
      return
    }
    $.ajax({
      type: 'PUT',
      url: Spree.url(Spree.routes.apply_coupon_code(order_number)),
      data: {
        coupon_code: couponCode,
        token: Spree.api_key
      }
    }).done(function () {
      window.location.reload()
    }).fail(function (message) {
      if (message.responseJSON['error']) {
        show_flash('error', message.responseJSON['error'])
      } else {
        show_flash('error', 'There was a problem adding this coupon code.')
      }
    })
  })
})

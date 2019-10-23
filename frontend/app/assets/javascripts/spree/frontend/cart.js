//= require spree/frontend/coupon_manager

Spree.ready(function ($) {
  var formUpdateCart = $('form#update-cart')
  if (formUpdateCart.length) {
    $('form#update-cart a.delete').show().one('click', function () {
      $(this).parents('.line-item').first().find('input.line_item_quantity').val(0)
      $(this).parents('form').first().submit()
      return false
    })
  }
  formUpdateCart.submit(function (event) {
    var input = {
      couponCodeField: $('#order_coupon_code'),
      couponStatus: $('#coupon_status')
    }
    var updateButton = $('form#update-cart #update-button')
    updateButton.attr('disabled', true)
    if ($.trim(input.couponCodeField.val()).length > 0) {
      // eslint-disable-next-line no-undef
      if (new CouponManager(input).applyCoupon()) {
        this.submit()
        return true
      } else {
        updateButton.attr('disabled', false)
        event.preventDefault()
        return false
      }
    }
  })
})

Spree.fetch_cart = function () {
  return $.ajax({
    url: Spree.pathFor('cart_link')
  }).done(function (data) {
    return $('#link-to-cart').html(data)
  })
}

Spree.ensureCart = function (successCallback) {
  if (SpreeAPI.orderToken) {
    successCallback()
  } else {
    fetch(Spree.routes.ensure_cart, {
      method: 'POST',
      credentials: 'same-origin'
    }).then(function (response) {
      switch (response.status) {
        case 200:
          response.json().then(function (json) {
            SpreeAPI.orderToken = json.token
            successCallback()
          })
          break
      }
    })
  }
}

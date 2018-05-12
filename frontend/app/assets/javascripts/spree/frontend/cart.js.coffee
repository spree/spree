#= require spree/frontend/coupon_manager

Spree.ready ($) ->
  if ($ 'form#update-cart').length
    ($ 'form#update-cart a.delete').show().one 'click', ->
      ($ this).parents('.line-item').first().find('input.line_item_quantity').val 0
      ($ this).parents('form').first().submit()
      false

  ($ 'form#update-cart').submit (event) ->
    ($ 'form#update-cart #update-button').attr('disabled', true)
    input =
      couponCodeField: $('#order_coupon_code')
      couponStatus: $('#coupon_status')
    if $.trim(input.couponCodeField.val()).length > 0
      if new CouponManager(input).applyCoupon()
        @submit()
        return true
      else
        ($ 'form#update-cart #update-button').attr('disabled', false)
        event.preventDefault()
        return false

Spree.fetch_cart = ->
  $.ajax
    url: Spree.pathFor("cart_link"),
    success: (data) ->
      $('#link-to-cart').html data

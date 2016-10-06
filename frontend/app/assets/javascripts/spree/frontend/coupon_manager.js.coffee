class @CouponManager
  constructor: (@input) ->
    @couponCodeField = @input.couponCodeField
    @couponApplied = false
    @couponStatus = @input.couponStatus

  applyCoupon: ->
    @couponCode = $.trim($(@couponCodeField).val())
    if @couponCode != ''
      if @couponStatus.length == 0
        @couponStatus = $('<div/>', { id: 'coupon_status' })
        @couponCodeField.parent().append @couponStatus
      @createUrl()
      @couponStatus.removeClass()
      @sendRequest()
      @couponApplied
    else
      true

  createUrl: ->
    @url = Spree.url(Spree.routes.apply_coupon_code(Spree.current_order_id),
      order_token: Spree.current_order_token
      coupon_code: @couponCode)

  sendRequest: ->
    $.ajax
      async: false
      method: 'PUT'
      url: @url
      success: =>
        @couponCodeField.val ''
        @couponStatus.addClass('alert-success')
                     .html Spree.translations.coupon_code_applied
        @couponApplied = true
      error: (xhr) =>
        handler = JSON.parse(xhr.responseText)
        @couponStatus.addClass('alert-error').html handler['error']

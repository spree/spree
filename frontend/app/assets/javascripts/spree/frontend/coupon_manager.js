function CouponManager (input) {
  this.input = input
  this.appliedCouponCodeField = this.input.appliedCouponCodeField
  this.couponCodeField = this.input.couponCodeField
  this.couponApplied = false
  this.couponRemoved = false
  this.couponStatus = this.input.couponStatus
  this.couponButton = this.input.couponButton
  this.removeCouponButton = this.input.removeCouponButton
  this.couponErrorIcon = document.createElement("img")
  this.couponErrorIcon.src = Spree.translations.coupon_code_error_icon
}

CouponManager.prototype.applyCoupon = function (successCallback = null, failureCallback = null) {
  this.couponCode = $(this.couponCodeField).val().trim()
  if (this.couponCode !== '') {
    if (this.couponStatus.length === 0) {
      this.couponStatus = $('<div/>', {
        id: 'coupon_status'
      })
      this.couponCodeField.parent().append(this.couponStatus)
    }
    this.couponStatus.removeClass()
    this.sendRequest(successCallback, failureCallback)
    return this.couponApplied
  } else {
    return true
  }
}

CouponManager.prototype.removeCoupon = function (successCallback = null, failureCallback = null) {
  this.couponCode = $(this.appliedCouponCodeField).attr('data-code').trim()
  if (this.couponCode !== '') {
    if (this.couponStatus.length === 0) {
      this.couponStatus = $('<div/>', {
        id: 'coupon_status'
      })
      this.appliedCouponCodeField.parent().append(this.couponStatus)
    }
    this.couponStatus.removeClass()
    this.sendRemoveRequest(successCallback, failureCallback)
    return this.couponRemoved
  } else {
    return true
  }
}

CouponManager.prototype.sendRequest = function (successCallback = null, failureCallback = null) {
  return $.ajax({
    async: false,
    method: 'PATCH',
    url: Spree.routes.api_v2_storefront_cart_apply_coupon_code,
    dataType: 'json',
    headers: {
      'X-Spree-Order-Token': SpreeAPI.orderToken
    },
    data: {
      coupon_code: this.couponCode
    }
  }).done(function () {
    this.couponCodeField.val('')
    this.couponStatus.addClass('alert-success').html(Spree.translations.coupon_code_applied)
    this.couponApplied = true
    if (successCallback) successCallback()
  }.bind(this)).fail(function (xhr) {
    var handler = xhr.responseJSON
    this.couponCodeField.addClass('error')
    this.couponButton.addClass('error')
    this.couponStatus.addClass('alert-error').html(handler['error'])
    this.couponStatus.prepend(this.couponErrorIcon)
    if (failureCallback) failureCallback()
  }.bind(this))
}

CouponManager.prototype.sendRemoveRequest = function (successCallback = null, failureCallback = null) {
  return $.ajax({
    async: false,
    method: 'DELETE',
    url: Spree.routes.api_v2_storefront_cart_remove_coupon_code(this.couponCode),
    dataType: 'json',
    headers: {
      'X-Spree-Order-Token': SpreeAPI.orderToken
    }
  }).done(function () {
    this.appliedCouponCodeField.val('')
    this.couponStatus.addClass('alert-success').html(Spree.translations.coupon_code_removed)
    this.couponRemoved = true
    if (successCallback) successCallback()
  }.bind(this)).fail(function (xhr) {
    var handler = xhr.responseJSON
    this.appliedCouponCodeField.addClass('error')
    this.removeCouponButton.addClass('error')
    this.couponStatus.addClass('alert-error').html(handler['error'])
    this.couponStatus.prepend(this.couponErrorIcon)
    if (failureCallback) failureCallback()
  }.bind(this))
}

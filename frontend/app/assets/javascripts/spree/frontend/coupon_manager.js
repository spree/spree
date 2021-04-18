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
  var cc = this
  SpreeAPI.Storefront.applyCouponCode(
    this.couponCode,
    function(_response) {
      cc.couponCodeField.val('')
      cc.couponStatus.addClass('alert-success').html(Spree.translations.coupon_code_applied)
      cc.couponApplied = true
      if (successCallback) successCallback()
    },
    function(error) {
      cc.couponCodeField.val('')
      cc.couponCodeField.addClass('error')
      cc.couponButton.addClass('error')
      cc.couponStatus.addClass('alert-error').html(error)
      cc.couponStatus.prepend(cc.couponErrorIcon)
      if (failureCallback) failureCallback()
    }
  )
}

CouponManager.prototype.sendRemoveRequest = function (successCallback = null, failureCallback = null) {
  var cc = this
  SpreeAPI.Storefront.removeCouponCode(
    this.couponCode,
    function(_response) {
      cc.appliedCouponCodeField.val('')
      cc.couponStatus.addClass('alert-success').html(Spree.translations.coupon_code_removed)
      cc.couponRemoved = true
      if (successCallback) successCallback()
    },
    function(error) {
      cc.appliedCouponCodeField.addClass('error')
      cc.removeCouponButton.addClass('error')
      cc.couponStatus.addClass('alert-error').html(error)
      cc.couponStatus.prepend(cc.couponErrorIcon)
      if (failureCallback) failureCallback()
    }
  )
}

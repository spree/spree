function CouponManager(input) {
  this.input = input;
  this.couponCodeField = this.input.couponCodeField;
  this.couponApplied = false;
  this.couponStatus = this.input.couponStatus;
}

CouponManager.prototype.applyCoupon = function () {
  this.couponCode = $.trim($(this.couponCodeField).val());
  if (this.couponCode !== '') {
    if (this.couponStatus.length === 0) {
      this.couponStatus = $('<div/>', {
        id: 'coupon_status'
      });
      this.couponCodeField.parent().append(this.couponStatus);
    }
    this.createUrl();
    this.couponStatus.removeClass();
    this.sendRequest();
    return this.couponApplied;
  } else {
    return true;
  }
};

CouponManager.prototype.createUrl = function () {
  return this.url = Spree.url(Spree.routes.apply_coupon_code(Spree.current_order_id), {
    order_token: Spree.current_order_token,
    coupon_code: this.couponCode
  });
};

CouponManager.prototype.sendRequest = function () {
  return $.ajax({
    async: false,
    method: 'PUT',
    url: this.url
  }).done(function () {
    this.couponCodeField.val('');
    this.couponStatus.addClass('alert-success').html(Spree.translations.coupon_code_applied);
    this.couponApplied = true;
  }.bind(this)).fail(function (xhr) {
    var handler = JSON.parse(xhr.responseText);
    this.couponStatus.addClass('alert-error').html(handler['error']);
  }.bind(this));
};

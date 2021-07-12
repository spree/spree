/* eslint-disable no-undef */

document.addEventListener('DOMContentLoaded', function() {
  const applyCouponButton = document.querySelector('[data-hook=adjustments_new_coupon_code] #add_coupon_code')
  applyCouponButton.addEventListener('click', processCoupon)
})

const processCoupon = function() {
  const couponCode = document.querySelector('#coupon_code').value
  if (couponCode.length === 0) return

  addCoupon(couponCode)
}

/* eslint-disable no-undef */
/* eslint-disable no-unused-vars */
/* global order_number */

//
// BUILD URI
const ordersUri = (action) => `${Spree.routes.orders_api_v2}/${order_number}/${action}`

//
// ADVANCE ORDER
window.Spree.advanceOrder = function() {
  fetch(ordersUri('advance'), {
    method: 'PUT',
    headers: Spree.apiV2Authentication()
  })
    .then((response) => spreeHandleResponse(response)
      .then(window.location.reload()))
    .catch(err => console.log(err))
}

//
// ADD COUPON
const addCoupon = function(couponCode) {
  if (couponCode == null) return

  showProgressIndicator()
  const data = {
    coupon_code: couponCode
  }

  fetch(ordersUri('apply_coupon_code'), {
    method: 'PATCH',
    headers: Spree.apiV2Authentication(),
    body: JSON.stringify(data)
  })
    .then((response) => spreeHandleResponse(response)
      .then(window.location.reload()))
    .catch(err => console.log(err))
}

//
// DELETE COUPON
const deleteCoupon = function(couponCode) {
  showProgressIndicator()
  const data = {
    coupon_code: couponCode
  }

  fetch(ordersUri('remove_coupon_code'), {
    method: 'DELETE',
    headers: Spree.apiV2Authentication(),
    body: JSON.stringify(data)
  })
    .then((response) => spreeHandleResponse(response)
      .then(window.location.reload()))
    .catch(err => console.log(err))
}

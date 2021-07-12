/* eslint-disable no-undef */
/* eslint-disable no-unused-vars */
/* global order_number */

//
// BUILD URI
const orderUri = (action) => `${Spree.routes.orders_api_v2}/${order_number}/${action}`

//
// ADVANCE ORDER
window.Spree.advanceOrder = function() {
  fetch(orderUri('advance'), {
    method: 'PUT',
    headers: {
      Authorization: 'Bearer ' + OAUTH_TOKEN,
      'Content-Type': 'application/json'
    }
  })
    .then(response => {
      if (response.ok === true) {
        window.location.reload()
      } else {
        console.log(`Response: ${response}`)
      }
    })
    .catch(err => console.error(`Error: ${err}`))
}

//
// ADD LINE ITEM
const addLineItem = (variantId, quantity) => {
  if (variantId == null || quantity <= 0) return

  showProgressIndicator()
  const data = {
    variant_id: parseInt(variantId, 10),
    quantity: parseInt(quantity, 10)
  }

  fetch(orderUri('add_item'), {
    method: 'POST',
    headers: {
      Authorization: 'Bearer ' + OAUTH_TOKEN,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify(data)
  })
    .then(response => {
      hideProgressIndicator()
      if (response.ok === true) {
        window.Spree.advanceOrder()
      } else {
        flashAlertErrorResponse(response)
      }
    })
    .catch(err => console.error(`Error: ${err}`))
}

//
// ADJUST LINE ITEM QUANTITY
const adjustLineItemQuantity = function(lineItemId, quantity) {
  if (lineItemId == null) return
  if (quantity <= 0) {
    deleteLineItem(lineItemId)
    return
  }

  showProgressIndicator()
  const data = {
    line_item_id: parseInt(lineItemId, 10),
    quantity: parseInt(quantity, 10)
  }

  fetch(orderUri('set_quantity'), {
    method: 'PATCH',
    headers: {
      Authorization: 'Bearer ' + OAUTH_TOKEN,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify(data)
  })
    .then(response => {
      hideProgressIndicator()
      if (response.ok === true) {
        window.Spree.advanceOrder()
      } else {
        flashAlertErrorResponse(response)
      }
    })
    .catch(err => console.error(`Error: ${err}`))
}

//
// DELETE LINE ITEM
const deleteLineItem = function(lineItemId) {
  showProgressIndicator()
  const data = {
    line_item_id: parseInt(lineItemId, 10)
  }

  fetch(orderUri('remove_line_item'), {
    method: 'DELETE',
    headers: {
      Authorization: 'Bearer ' + OAUTH_TOKEN,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify(data)
  })
    .then(response => {
      hideProgressIndicator()
      if (response.ok === true) {
        window.Spree.advanceOrder()
      } else {
        console.log(`Response: ${response}`)
      }
    })
    .catch(err => console.error(`Error: ${err}`))
}

//
// ADD COUPON
const addCoupon = function(couponCode) {
  if (couponCode == null) return

  showProgressIndicator()
  const data = {
    coupon_code: couponCode
  }

  fetch(orderUri('apply_coupon_code'), {
    method: 'PATCH',
    headers: {
      Authorization: 'Bearer ' + OAUTH_TOKEN,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify(data)
  })
    .then(response => {
      hideProgressIndicator()
      if (response.ok === true) {
        window.location.reload()
      } else {
        flashAlertErrorResponse(response)
      }
    })
    .catch(err => {
      show_flash('error', 'There was a problem adding this coupon code.')
      console.error(`Error: ${err}`)
    })
}

//
// DELETE COUPON
const deleteCoupon = function(couponCode) {
  showProgressIndicator()
  const data = {
    coupon_code: couponCode
  }

  fetch(orderUri('remove_coupon_code'), {
    method: 'DELETE',
    headers: {
      Authorization: 'Bearer ' + OAUTH_TOKEN,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify(data)
  })
    .then(response => {
      hideProgressIndicator()
      if (response.ok === true) {
        window.Spree.advanceOrder()
      } else {
        console.log(`Response: ${response}`)
      }
    })
    .catch(err => console.error(`Error: ${err}`))
}

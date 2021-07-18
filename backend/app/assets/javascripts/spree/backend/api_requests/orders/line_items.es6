/* eslint-disable no-undef */
/* eslint-disable no-unused-vars */
/* global order_number */

//
// BUILD URI
const ordersLineItemsUri = (lineItemId = '') => `${Spree.routes.orders_api_v2}/${order_number}/line_items/${lineItemId}`

//
// POST -> Create Line Item
const addLineItem = (variantId, quantity) => {
  if (variantId == null || quantity <= 0) return

  showProgressIndicator()
  const data = {
    variant_id: parseInt(variantId, 10),
    quantity: parseInt(quantity, 10)
  }

  fetch(ordersLineItemsUri(), {
    method: 'POST',
    headers: {
      Authorization: 'Bearer ' + OAUTH_TOKEN,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify(data)
  })
    .then((response) => spreeHandleResponse(response).then(window.location.reload()))
    .catch(err => console.log(err))
}

//
// PUT -> Update Line Item Quantity
const adjustLineItemQuantity = function(lineItemId, quantity) {
  if (lineItemId == null) return

  if (quantity <= 0) {
    deleteLineItem(lineItemId)
    return
  }

  const formattedLineItemId = parseInt(lineItemId, 10)

  showProgressIndicator()
  const data = {
    quantity: parseInt(quantity, 10)
  }

  fetch(ordersLineItemsUri(formattedLineItemId), {
    method: 'PUT',
    headers: {
      Authorization: 'Bearer ' + OAUTH_TOKEN,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify(data)
  })
    .then((response) => spreeHandleResponse(response).then(window.location.reload()))
    .catch(err => console.log(err))
}

//
// DELETE -> Deletes Line Item
const deleteLineItem = function(lineItemId) {
  const formattedLineItemId = parseInt(lineItemId, 10)
  showProgressIndicator()

  fetch(ordersLineItemsUri(formattedLineItemId), {
    method: 'DELETE',
    headers: {
      Authorization: 'Bearer ' + OAUTH_TOKEN,
      'Content-Type': 'application/json'
    }
  })
    .then((response) => spreeHandleResponse(response).then(window.location.reload()))
    .catch(err => console.log(err))
}

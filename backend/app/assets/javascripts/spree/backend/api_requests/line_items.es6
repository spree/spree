/* eslint-disable no-undef */
/* eslint-disable no-unused-vars */
/* global order_number */

//
// BUILD URI
const ordersLineItemsUri = (lineItemId = '') => `${Spree.routes.line_items_api_v2}/${lineItemId}`

//
// CREATE LINE ITEM
const addLineItem = (variantId, quantity) => {
  if (variantId == null || quantity <= 0) return

  showProgressIndicator()
  const data = {
    order_id: order_number,
    variant_id: parseInt(variantId, 10),
    quantity: parseInt(quantity, 10)
  }

  fetch(ordersLineItemsUri(), {
    method: 'POST',
    headers: Spree.apiV2Authentication(),
    body: JSON.stringify(data)
  })
    .then((response) => spreeHandleResponse(response)
      .then((data) => {
        if (response.ok) {
          window.Spree.advanceOrder()
        } else {
          show_flash('info', data.error)
        }
      }))
    .catch(err => console.log(err))
}

//
// UPDATE LINE ITEM QTY
const adjustLineItemQuantity = function(lineItemId, quantity) {
  if (lineItemId == null) return

  if (quantity <= 0) {
    deleteLineItem(lineItemId)
    return
  }

  const formattedLineItemId = parseInt(lineItemId, 10)

  showProgressIndicator()
  const data = {
    order_id: order_number,
    quantity: parseInt(quantity, 10)
  }

  fetch(ordersLineItemsUri(formattedLineItemId), {
    method: 'PUT',
    headers: Spree.apiV2Authentication(),
    body: JSON.stringify(data)
  })
    .then((response) => spreeHandleResponse(response)
      .then((data) => {
        if (response.ok) {
          window.Spree.advanceOrder()
        } else {
          show_flash('info', data.error)
        }
      }))
    .catch(err => console.log(err))
}

//
// DELETE LINE ITEM
const deleteLineItem = function(lineItemId) {
  const formattedLineItemId = parseInt(lineItemId, 10)
  showProgressIndicator()
  const data = {
    order_id: order_number
  }

  fetch(ordersLineItemsUri(formattedLineItemId), {
    method: 'DELETE',
    headers: Spree.apiV2Authentication(),
    body: JSON.stringify(data)
  })
    .then((response) => spreeHandleResponse(response)
      .then((data) => {
        if (response.ok) {
          window.Spree.advanceOrder()
        } else {
          show_flash('info', data.error)
        }
      }))
    .catch(err => console.log(err))
}

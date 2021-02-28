//= require spree/api/main

SpreeAPI.Storefront.createCart = function (successCallback, failureCallback) {
  fetch(Spree.routes.api_v2_storefront_cart_create, {
    method: 'POST',
    headers: SpreeAPI.prepareHeaders()
  }).then(function (response) {
    switch (response.status) {
      case 422:
        response.json().then(function (json) { failureCallback(json.error) })
        break
      case 500:
        SpreeAPI.handle500error()
        break
      case 201:
        response.json().then(function (json) {
          SpreeAPI.orderToken = json.data.attributes.token
          successCallback()
        })
        break
    }
  })
}

SpreeAPI.Storefront.handleCartUpdate = function (response, successCallback, failureCallback) {
  switch (response.status) {
    case 422:
      response.json().then(function (json) { failureCallback(json.error) })
      break
    case 500:
      SpreeAPI.handle500error()
      break
    case 200:
      response.json().then(function (json) {
        successCallback(json.data)
      })
      break
  }
}

SpreeAPI.Storefront.addToCart = function (variantId, quantity, options, successCallback, failureCallback) {
  fetch(Spree.routes.api_v2_storefront_cart_add_item, {
    method: 'POST',
    headers: SpreeAPI.prepareHeaders({ 'X-Spree-Order-Token': SpreeAPI.orderToken }),
    body: JSON.stringify({
      variant_id: variantId,
      quantity: quantity,
      options: options
    })
  }).then(function (response) { SpreeAPI.Storefront.handleCartUpdate(response, successCallback, failureCallback) })
}

SpreeAPI.Storefront.removeLineItemFromCart = function (lineItemId, successCallback, failureCallback) {
  fetch(Spree.routes.api_v2_storefront_cart_remove_line_item(lineItemId), {
    method: 'DELETE',
    headers: SpreeAPI.prepareHeaders({ 'X-Spree-Order-Token': SpreeAPI.orderToken })
  }).then(function (response) { SpreeAPI.Storefront.handleCartUpdate(response, successCallback, failureCallback) })
}

SpreeAPI.Storefront.setLineItemQuantity = function (lineItemId, quantity, successCallback, failureCallback) {
  fetch(Spree.routes.api_v2_storefront_cart_set_quantity, {
    method: 'PATCH',
    headers: SpreeAPI.prepareHeaders({ 'X-Spree-Order-Token': SpreeAPI.orderToken }),
    body: JSON.stringify({
      line_item_id: lineItemId,
      quantity: quantity
    })
  }).then(function (response) { SpreeAPI.Storefront.handleCartUpdate(response, successCallback, failureCallback) })
}

SpreeAPI.Storefront.emptyCart = function (successCallback, failureCallback) {
  fetch(Spree.routes.api_v2_storefront_cart_empty, {
    method: 'PATCH',
    headers: SpreeAPI.prepareHeaders({ 'X-Spree-Order-Token': SpreeAPI.orderToken })
  }).then(function (response) { SpreeAPI.Storefront.handleCartUpdate(response, successCallback, failureCallback) })
}

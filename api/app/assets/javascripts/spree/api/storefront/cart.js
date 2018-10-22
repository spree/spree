//= require spree/api/main

SpreeAPI.Storefront.createCart = function (successCallback, failureCallback, setCookie) {
  // setting this cookie is essential for communication with Rails frontend
  var createCartUrl = Spree.routes.api_v2_storefront_cart_create
  if (setCookie) {
    createCartUrl += '?set_cookie=true'
  }

  fetch(createCartUrl, {
    method: 'POST',
    headers: SpreeAPI.prepareHeaders({})
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
          Spree.current_order_token = json.data.attributes.token // legacy - should be removed later
          SpreeAPI.orderToken = json.data.attributes.token
          successCallback()
        })
        break
    }
  })
}

SpreeAPI.Storefront.ensureCart = function (successCallback, failureCallback, setCookie) {
  if (SpreeAPI.orderToken) {
    successCallback()
  } else {
    SpreeAPI.Storefront.createCart(successCallback, failureCallback, setCookie)
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
  }).then(function (response) {
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
  })
}

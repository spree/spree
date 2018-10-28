//= require spree

var SpreeAPI = {
  oauthToken: null, // user Bearer token to authorize operations for the given user
  orderToken: null // order token to authorize operations on current order (cart)
}

SpreeAPI.Storefront = {}
SpreeAPI.Platform = {}

// API routes
Spree.routes.api_v2_storefront_cart_create = Spree.pathFor('api/v2/storefront/cart')
Spree.routes.api_v2_storefront_cart_add_item = Spree.pathFor('api/v2/storefront/cart/add_item')
Spree.routes.api_v2_storefront_cart_apply_coupon_code = Spree.pathFor('api/v2/storefront/cart/apply_coupon_code')

// helpers
SpreeAPI.handle500error = function () {
  alert('Internal Server Error')
}

SpreeAPI.prepareHeaders = function (headers) {
  if (typeof headers === 'undefined') {
    headers = {}
  }

  // if signed in we need to pass the Bearer authorization token
  // so backend will recognize that actions are authorized in scope of this user
  if (SpreeAPI.oauthToken) {
    headers['Authorization'] = 'Bearer ' + SpreeAPI.oauthToken
  }

  // default headers, required for POST/PATCH/DELETE requests
  headers['Accept'] = 'application/json'
  headers['Content-Type'] = 'application/json'
  return headers
}

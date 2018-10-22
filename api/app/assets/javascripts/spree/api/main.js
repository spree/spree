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

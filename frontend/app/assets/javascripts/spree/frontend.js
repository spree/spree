//= require jquery3
//= require jquery_ujs
//= require popper
//= require bootstrap
//= require jquery.payment
//= require cleave
//= require spree
//= require polyfill.min
//= require fetch.umd
//= require spree/api/main
//= require ./lazysizes.config
//= require lazysizes.min
//= require turbolinks
//= require spree/frontend/account
//= require spree/frontend/api_tokens
//= require spree/frontend/carousel-noconflict
//= require spree/frontend/cart
//= require spree/frontend/locale
//= require spree/frontend/currency
//= require spree/frontend/checkout
//= require spree/frontend/checkout/address
//= require spree/frontend/checkout/address_book
//= require spree/frontend/checkout/payment
//= require spree/frontend/checkout/shipment
//= require spree/frontend/views/spree/home/product_carousels
//= require spree/frontend/views/spree/layouts/spree_application
//= require spree/frontend/views/spree/product/related
//= require spree/frontend/views/spree/products/cart_form
//= require spree/frontend/views/spree/products/description
//= require spree/frontend/views/spree/products/index
//= require spree/frontend/views/spree/products/modal_carousel
//= require spree/frontend/views/spree/products/price_filters
//= require spree/frontend/views/spree/shared/carousel
//= require spree/frontend/views/spree/shared/carousel/single
//= require spree/frontend/views/spree/shared/carousel/swipes
//= require spree/frontend/views/spree/shared/carousel/thumbnails
//= require spree/frontend/views/spree/shared/delete_address_popup
//= require spree/frontend/views/spree/shared/mobile_navigation
//= require spree/frontend/views/spree/shared/nav_bar
//= require spree/frontend/views/spree/shared/product_added_modal
//= require spree/frontend/views/spree/shared/quantity_select
//= require spree/frontend/turbolinks_scroll_fix
//= require spree/frontend/main_nav_bar
//= require spree/frontend/login

Spree.routes.api_tokens = Spree.pathFor('api_tokens')
Spree.routes.ensure_cart = Spree.pathFor('ensure_cart')
Spree.routes.api_v2_storefront_cart_apply_coupon_code = Spree.localizedPathFor('api/v2/storefront/cart/apply_coupon_code')
Spree.routes.api_v2_storefront_cart_remove_coupon_code = function(couponCode) { return Spree.localizedPathFor('api/v2/storefront/cart/remove_coupon_code/' + couponCode) }
Spree.routes.product = function(id) { return Spree.localizedPathFor('products/' + id) }
Spree.routes.product_related = function(id) { return Spree.localizedPathFor('products/' + id + '/related') }
Spree.routes.product_carousel = function (taxonId) { return Spree.localizedPathFor('product_carousel/' + taxonId) }
Spree.routes.set_locale = function(locale) { return Spree.pathFor('locale/set?switch_to_locale=' + locale) }
Spree.routes.set_currency = function(currency) { return Spree.pathFor('currency/set?switch_to_currency=' + currency) }

Spree.showProgressBar = function () {
  if (!Turbolinks.supported) { return }
  Turbolinks.controller.adapter.progressBar.setValue(0)
  Turbolinks.controller.adapter.progressBar.show()
}

Spree.clearCache = function () {
  if (!Turbolinks.supported) { return }

  Turbolinks.clearCache()
}

Spree.setCurrency = function (currency) {
  Spree.clearCache()

  var params = (new URL(window.location)).searchParams
  if (currency === SPREE_DEFAULT_CURRENCY) {
    params.delete('currency')
  } else {
    params.set('currency', currency)
  }
  var queryString = params.toString()
  if (queryString !== '') { queryString = '?' + queryString }

  SPREE_CURRENCY = currency

  Turbolinks.visit(window.location.pathname + queryString, { action: 'replace' })
}

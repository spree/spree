//= require spree/api/storefront/cart
//= require spree/frontend/cart

Spree.ready(function($) {
  $('body').on('product_add_to_cart', function(event) {

    Spree.showProductAddedModal(event.product, event.variant)
  })
})

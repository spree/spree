Spree.updateCartIcon = function(cart) {
  var itemCount = cart.item_count
  var cartIconSelector = '.cart-icon'
  var cartCountSelector = '.cart-icon-count'
  var visibleCartCountClass = 'cart-icon--visible-count'
  var $cartIcon = $(cartIconSelector)

  $cartIcon
    .toggleClass(visibleCartCountClass, itemCount > 0)
    .find(cartCountSelector)
    .text(itemCount)
}

Spree.ready(function($) {
  $('body').on('product_add_to_cart', function(event) {
    Spree.updateCartIcon(event.cart)
  })
})

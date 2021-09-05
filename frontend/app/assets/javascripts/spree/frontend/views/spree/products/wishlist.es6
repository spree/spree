(function() {
  Spree.ready(function($) {
    $('#new_wished_product').on('submit', function() {
      const selectedVariantId = $('#add-to-cart-form input[name="variant_id"]').val()

      if (selectedVariantId != null) {
        $('#wished_product_variant_id').val(selectedVariantId)
      }
      const cartQuantity = $('#quantity').val()
      if (cartQuantity) {
        return $('#wished_product_quantity').val(cartQuantity)
      }
    })
    $('form#change_wishlist_accessibility').on('submit', function() {
      $.post($(this).prop('action'), $(this).serialize(), null, 'script')
      return false
    })
    return $('form#change_wishlist_accessibility input[type=radio]').on('click', function() {
      return $(this).parent().submit()
    })
  })
}).call(this)

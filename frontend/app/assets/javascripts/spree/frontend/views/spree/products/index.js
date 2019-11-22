Spree.ready(function($) {
  $('#sort-by-overlay-show-button').click(function() { $('#sort-by-overlay').show() })
  $('#sort-by-overlay-hide-button').click(function() { $('#sort-by-overlay').hide() })

  $('#filter-by-overlay-show-button').click(function() { $('#filter-by-overlay').show() })
  $('#filter-by-overlay-hide-button').click(function() { $('#filter-by-overlay').hide() })

  $('#no-product-available-close-button').click(function() { document.getElementById('no-product-available').classList.remove('shown') })
  $('#no-product-available-hide-button').click(function() { document.getElementById('no-product-available').classList.remove('shown') })
  $('#no-product-available-close-button').click(function() { document.getElementById('overlay').classList.remove('shown') })
  $('#no-product-available-hide-button').click(function() { document.getElementById('overlay').classList.remove('shown') })
})

Spree.ready(function($) {
  $('#sort-by-overlay-show-button').click(function() { $('#sort-by-overlay').show() })
  $('#sort-by-overlay-hide-button').click(function() { $('#sort-by-overlay').hide() })

  $('#filter-by-overlay-show-button').click(function() { $('#filter-by-overlay').show() })
  $('#filter-by-overlay-hide-button').click(function() { $('#filter-by-overlay').hide() })

  $('#no-product-available-close-button').click(function() { document.getElementById('no-product-available').classList.remove('shown') })
  $('#no-product-available-hide-button').click(function() { document.getElementById('no-product-available').classList.remove('shown') })
  $('#no-product-available-close-button').click(function() { document.getElementById('overlay').classList.remove('shown') })
  $('#no-product-available-hide-button').click(function() { document.getElementById('overlay').classList.remove('shown') })

  $('.plp-overlay-card-item').click(function() {
    $(this).toggleClass('plp-overlay-card-item--selected')
  })

  $('.color-select').click(function() {
    var borderElement = $(this).find('.color-select-border')
    var strokeValue = $(this).find('.color-select-border').attr('stroke')

    borderElement.attr('stroke', strokeValue === '#000000' ? '#e4e5e6' : '#000000')
  })
})

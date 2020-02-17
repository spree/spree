Spree.ready(function($) {
  $('#sort-by-overlay-show-button').click(function() { $('#sort-by-overlay').show() })
  $('#sort-by-overlay-hide-button').click(function() { $('#sort-by-overlay').hide() })

  $('#filter-by-overlay-show-button').click(function() { $('#filter-by-overlay').show() })
  $('#filter-by-overlay-hide-button').click(function() { $('#filter-by-overlay').hide() })

  function closeNoProductModal() {
    $('#no-product-available').removeClass('shown')
    $('#overlay').removeClass('shown')
  }

  $('#no-product-available-close-button').click(closeNoProductModal)
  $('#no-product-available-hide-button').click(closeNoProductModal)

  $('.plp-overlay-card-item').click(function() {
    $(this).toggleClass('plp-overlay-card-item--selected')
  })

  var allOptionsBorders = $('.color-select-border')
  var addToCartButton = document.getElementById('add-to-cart-button')

  function removeSelectedBorders() {
    allOptionsBorders.each(function() {
      $(this).removeClass('color-select-border--selected')
    })
  }

  $('.color-select').click(function() {
    var borderElement = $(this).find('.color-select-border')

    removeSelectedBorders()
    borderElement.addClass('color-select-border--selected')
  })

  if (allOptionsBorders !== undefined && addToCartButton !== null) {
    var colorsClassList = []

    allOptionsBorders.each(function(optionBorder) {
      colorsClassList.push(optionBorder.classList)
    })

    if (!colorsClassList.includes('color-select-border--selected')) {
      removeSelectedBorders()
      allOptionsBorders[0].classList.add('color-select-border--selected')
    }
  }

  $('.plp-overlay-ul-li').click(function() {
    $('.plp-overlay-ul-li--active').removeClass('plp-overlay-ul-li--active')
      .addClass('plp-overlay-ul-li')

    $(this).removeClass('plp-overlay-ul-li')
      .addClass('plp-overlay-ul-li--active')
  })
})

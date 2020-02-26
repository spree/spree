Spree.ready(function($) {
  $('#sort-by-overlay-show-button').click(function() {
    $('#sort-by-overlay').show();
  });
  $('#sort-by-overlay-hide-button').click(function() {
    $('#sort-by-overlay').hide();
  });

  $('#filter-by-overlay-show-button').click(function() {
    $('#filter-by-overlay').show();
  });
  $('#filter-by-overlay-hide-button').click(function() {
    $('#filter-by-overlay').hide();
  });

  function closeNoProductModal() {
    $('#no-product-available').removeClass('shown');
    $('#overlay').removeClass('shown');
  }

  $('#no-product-available-close-button').click(closeNoProductModal);
  $('#no-product-available-hide-button').click(closeNoProductModal);

  $('.plp-overlay-card-item').click(function() {
    $(this).toggleClass('plp-overlay-card-item--selected');
  });

  $('#filters-accordion .color-select, #plp-filters-accordion .color-select').click(function() {
    $(this).find('.plp-overlay-color-item').toggleClass('color-select-border--selected')
  });

  $('.plp-overlay-ul-li').click(function() {
    $('.plp-overlay-ul-li--active')
      .removeClass('plp-overlay-ul-li--active')
      .addClass('plp-overlay-ul-li');

    $(this)
      .removeClass('plp-overlay-ul-li')
      .addClass('plp-overlay-ul-li--active');
  });
});

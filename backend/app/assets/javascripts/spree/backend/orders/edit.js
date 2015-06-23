$(document).ready(function () {
  'use strict';

  $('[data-hook="add_product_name"]').find('.variant_autocomplete').variantAutocomplete();

  $('.js-toggle-extra-line-item-info').click(function(){
    var item_id = $(this).data('id');
    $('.js-extra-line-item-info[data-id=' + item_id + ']').toggle();
  });
});

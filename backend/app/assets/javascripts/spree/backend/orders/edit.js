$(document).ready(function () {
  'use strict';

  $('[data-hook="add_product_name"]').find('.variant_autocomplete').variantAutocomplete();

  // Will refresh the states (based on the country) when you open the
  // shipment address modal
  $('.js-shipment-address-modal').click(function(){
    var dataTarget = $(this).data('target');
    var $parent = $(dataTarget);
    requestStates($parent);
  });
});

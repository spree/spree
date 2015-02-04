$(document).ready(function () {
  'use strict';

  $('[data-hook="add_product_name"]').find('.variant_autocomplete').variantAutocomplete();

  // Will refresh the states (based on the country) when you open the
  // shipment address form
  $(".js-new-shipment-address").click(function(){
    var data_target = $(this).data("target");
    var $parent = $(data_target);
    requestStates($parent);
  });
});

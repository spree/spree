$(document).ready(function () {
  'use strict';

  $('[data-hook="add_product_name"]').find('.variant_autocomplete').variantAutocomplete();

  $(".js-change-shipment-address").click(function(){
    var data_target = $(this).data("target");
    var $parent = $(data_target);
    requestStates($parent);
  });
});

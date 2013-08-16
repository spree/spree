$(document).ready(function () {
  'use strict';

  $('#add_line_item_to_order').on('click', function () {
    if ($('#add_variant_id').val() === '') {
      return false;
    }

    var update_target = '#' + $(this).attr('data-update');
    $.post(this.href, {
        'line_item[variant_id]': $('#add_variant_id').val(),
        'line_item[quantity]': $('#add_quantity').val()
      },

      function (data) {
        $(update_target).html(data);
      });
    return false;
  });

  $('[data-hook="add_product_name"]').find('.variant_autocomplete').variantAutocomplete();
});
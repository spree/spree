/* global variantLineItemTemplate, order_number */
// This file contains the code for interacting with line items in the manual cart
$(document).ready(function () {
  'use strict'

  // handle variant selection, show stock level.
  $('#add_line_item_variant_id').change(function () {
    var variantId = parseInt($(this).val())

    var variant = _.find(window.variants, function (variant) {
      return parseInt(variant.id) === variantId
    })

    $('#stock_details').html(variantLineItemTemplate({ variant: variant.attributes }))
    $('#stock_details').show()
    $('button.add_variant').click(addVariant)
  })
})



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

function addVariant () {
  $('#stock_details').hide()
  var variantId = $('select.variant_autocomplete').val()
  var quantity = $('input#variant_quantity').val()

  adjustLineItems(order_number, variantId, quantity)
  return 1
}

var adjustLineItems = function(order_number, variant_id, quantity) {
  var url = Spree.routes.orders_api + '/' + order_number + '/line_items'
  $.ajax({
    type: 'POST',
    url: Spree.url(url),
    data: {
      line_item: {
        variant_id: variant_id,
        quantity: quantity
      },
      token: Spree.api_key
    }
  }).done(function () {
    window.Spree.advanceOrder()
  }).fail(function (msg) {
    if (typeof msg.responseJSON.message !== 'undefined') {
      alert(msg.responseJSON.message)
    } else {
      alert(msg.responseJSON.exception)
    }
  })
}

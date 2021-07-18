/* eslint-disable no-undef */
/* global variantLineItemTemplate */

document.addEventListener('DOMContentLoaded', function() {
  // Search variants to add to order line items.
  $('[data-hook="add_product_name"]').find('.variant_autocomplete').variantAutocomplete()

  // Handle variant selection, show stock level.
  $('#add_line_item_variant_id').change(function () {
    var variantId = $(this).val()

    var variant = _.find(window.variants, function (variant) {
      return variant.id === variantId
    })
    $('#stock_details').html(variantLineItemTemplate({ variant: variant.attributes }))
    $('#stock_details').show()
    $('button.add_variant').click(addVariant)
  })

  // handle edit click
  $('a.edit-line-item').click(toggleLineItemEdit)

  // handle cancel click
  $('a.cancel-line-item').click(toggleLineItemEdit)

  // handle save click
  $('a.save-line-item').click(function () {
    var save = $(this)
    var lineItemId = save.data('line-item-id')
    var quantity = parseInt(save.parents('tr').find('input.line_item_quantity').val())
    adjustLineItemQuantity(lineItemId, quantity)
  })

  // handle delete click
  $('a.delete-line-item').click(function () {
    if (confirm(Spree.translations.are_you_sure_delete)) {
      var del = $(this)
      var lineItemId = del.data('line-item-id')
      deleteLineItem(lineItemId)
    }
  })
})

// Add line Item to order
function addVariant () {
  var variantId = $('select.variant_autocomplete').val()
  var quantity = $('input#variant_quantity').val()

  addLineItem(variantId, quantity)
}

function toggleLineItemEdit () {
  var link = $(this)
  var parent = link.parent()
  var tr = link.parents('tr')
  parent.find('a.edit-line-item').toggle()
  parent.find('a.cancel-line-item').toggle()
  parent.find('a.save-line-item').toggle()
  parent.find('a.delete-line-item').toggle()
  tr.find('td.line-item-qty-show').toggle()
  tr.find('td.line-item-qty-edit').toggle()
}

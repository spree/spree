/* global toggleItemEdit, order_number */
$(function () {
  // handle edit click
  $('a.edit-line-item').click(toggleLineItemEdit)
  // handle cancel click
  $('a.cancel-line-item').click(toggleLineItemEdit)
  // handle save click
  $('a.save-line-item').click(function () {
    var save = $(this)
    var lineItemId = save.data('line-item-id')
    var quantity = parseInt(save.parents('tr').find('input.line_item_quantity').val())
    toggleItemEdit()
    adjustLineItem(lineItemId, quantity)
  })
  // handle delete click
  $('a.delete-line-item').click(function () {
    if (confirm(Spree.translations.are_you_sure_delete)) {
      var del = $(this)
      var lineItemId = del.data('line-item-id')
      toggleItemEdit()
      deleteLineItem(lineItemId)
    }
  })
})

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

function lineItemURL (lineItemId) {
  // eslint-disable-next-line camelcase
  return Spree.routes.orders_api + '/' + order_number + '/line_items/' + lineItemId + '.json'
}

function adjustLineItem (lineItemId, quantity) {
  $.ajax({
    type: 'PUT',
    url: Spree.url(lineItemURL(lineItemId)),
    data: {
      line_item: {
        quantity: quantity
      },
      token: Spree.api_key
    }
  }).done(function () {
    window.Spree.advanceOrder()
  })
}

function deleteLineItem (lineItemId) {
  $.ajax({
    type: 'DELETE',
    url: Spree.url(lineItemURL(lineItemId)),
    headers: {
      'X-Spree-Token': Spree.api_key
    }
  }).done(function () {
    $('#line-item-' + lineItemId).remove()
    if ($('.line-items tr.line-item').length === 0) {
      $('.line-items').remove()
    }
    window.Spree.advanceOrder()
  })
}

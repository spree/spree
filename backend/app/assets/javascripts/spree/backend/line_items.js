$(function () {
  //handle edit click
  $('a.edit-line-item').click(toggleLineItemEdit);
  //handle cancel click
  $('a.cancel-line-item').click(toggleLineItemEdit);
  //handle save click
  $('a.save-line-item').click(function () {
    var save = $(this);
    var line_item_id = save.data('line-item-id');
    var quantity = parseInt(save.parents('tr').find('input.line_item_quantity').val());
    toggleItemEdit();
    adjustLineItem(line_item_id, quantity);
  });
  // handle delete click
  $('a.delete-line-item').click(function () {
    if (confirm(Spree.translations.are_you_sure_delete)) {
      var del = $(this);
      var line_item_id = del.data('line-item-id');
      toggleItemEdit();
      deleteLineItem(line_item_id);
    }
  });
});

function toggleLineItemEdit() {
  var link = $(this);
  var parent = link.parent();
  var tr = link.parents('tr');
  parent.find('a.edit-line-item').toggle();
  parent.find('a.cancel-line-item').toggle();
  parent.find('a.save-line-item').toggle();
  parent.find('a.delete-line-item').toggle();
  tr.find('td.line-item-qty-show').toggle();
  tr.find('td.line-item-qty-edit').toggle();
}

function lineItemURL(line_item_id) {
  return Spree.routes.orders_api + '/' + order_number + '/line_items/' + line_item_id + '.json';
}

function adjustLineItem(line_item_id, quantity) {
  $.ajax({
    type: 'PUT',
    url: Spree.url(lineItemURL(line_item_id)),
    data: {
      line_item: {
        quantity: quantity
      },
      token: Spree.api_key
    }
  }).done(function () {
    window.Spree.advanceOrder();
  });
}

function deleteLineItem(line_item_id) {
  $.ajax({
    type: 'DELETE',
    url: Spree.url(lineItemURL(line_item_id)),
    headers: {
      'X-Spree-Token': Spree.api_key
    }
  }).done(function () {
    $('#line-item-' + line_item_id).remove();
    if ($('.line-items tr.line-item').length === 0) {
      $('.line-items').remove();
    }
    window.Spree.advanceOrder();
  });
}

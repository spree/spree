/* global order_number */

window.Spree.advanceOrder = function() {
  fetch(`${Spree.routes.orders_api_v2}/${order_number}/advance`, {
    method: 'PUT',
    headers: {
      Authorization: 'Bearer ' + OAUTH_TOKEN,
      'Content-Type': 'application/json'
    }
  })
    .then(response => {
      if (response.ok === true) {
        window.location.reload()
      } else {
        console.log(`Response: ${response}`)
      }
    })
    .catch(err => {
      console.error(`Error: ${err}`);
    })
}

// eslint-disable-next-line no-unused-vars
function addVariant () {
  $('#stock_details').hide()
  const variantId = $('select.variant_autocomplete').val()
  const quantity = $('input#variant_quantity').val()

  adjustLineItems(order_number, variantId, quantity)
  return 1
}

function adjustLineItems(orderNumber, variantId, quantity) {
  const url = `${Spree.routes.orders_api}/${orderNumber}/line_items`;

  $.ajax({
    type: 'POST',
    url: Spree.url(url),
    data: {
      line_item: {
        variant_id: variantId,
        quantity: quantity
      },
      token: Spree.api_key
    }
  }).done(function() {
    window.Spree.advanceOrder();
  }).fail(function(msg) {
    if (typeof msg.responseJSON.message !== 'undefined') {
      alert(msg.responseJSON.message);
    } else {
      alert(msg.responseJSON.exception);
    }
  })
}

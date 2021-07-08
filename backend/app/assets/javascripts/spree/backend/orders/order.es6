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
      window.location.reload()
      if (response.ok !== true) {
        console.log(response)
      }
    })
    .catch(err => {
      console.error(err);
    })
}

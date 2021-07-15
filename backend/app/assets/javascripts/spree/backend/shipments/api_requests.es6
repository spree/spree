/* eslint-disable no-unused-vars */

//
// BUILD URI
const shipmentUri = (shipmentNumber, action) => `${Spree.routes.shipments_api_v2}/${shipmentNumber}/${action}`

//
// SHIP
const shipShipment = function(shipmentNumber) {
  showProgressIndicator()

  fetch(shipmentUri(shipmentNumber, 'ship'), {
    method: 'PUT',
    headers: {
      Authorization: 'Bearer ' + OAUTH_TOKEN,
      'Content-Type': 'application/json'
    }
  })
    .then(response => {
      hideProgressIndicator()
      if (response.ok === true) {
        window.location.reload()
      } else {
        console.log(response)
      }
    })
    .catch(err => console.error(err))
}

//
// REMOVE
const removeShipment = function(shipmentNumber, variantId) {
  showProgressIndicator()

  const data = {
    variant_id: parseInt(variantId, 10)
  }

  fetch(shipmentUri(shipmentNumber, 'remove'), {
    method: 'PUT',
    headers: {
      Authorization: 'Bearer ' + OAUTH_TOKEN,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify(data)
  })
    .then(response => {
      hideProgressIndicator()
      if (response.ok === true) {
        window.location.reload()
      } else {
        console.log(`Response: ${response}`)
      }
    })
    .catch(err => console.error(`Error: ${err}`))
}

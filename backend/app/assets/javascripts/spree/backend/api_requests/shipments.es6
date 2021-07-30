/* eslint-disable no-undef */
/* eslint-disable no-unused-vars */

//
// BUILD URI
const shipmentUri = (shipmentNumber, action = '') => `${Spree.routes.shipments_api_v2}/${shipmentNumber}/${action}`

//
// MARK AS SHIPPED
const shipShipment = function(shipmentNumber) {
  showProgressIndicator()

  fetch(shipmentUri(shipmentNumber, 'ship'), {
    method: 'PUT',
    headers: Spree.apiV2Authentication()
  })
    .then((response) => spreeHandleFetchRequestResponse(response, true)
      .then((data) => {
        if (response.ok) {
          window.location.reload()
        } else {
          spreeHandleFetchRequestError(data)
        }
      }))
    .catch(err => console.log(err))
}

//
// ADD VARIANT TO SHIPMENT
const addVariantToShipment = function(shipmentNumber, variantId, quantity = null) {
  showProgressIndicator()

  const data = {
    quantity: quantity,
    variant_id: parseInt(variantId, 10)
  }

  fetch(shipmentUri(shipmentNumber, 'add'), {
    method: 'PUT',
    headers: Spree.apiV2Authentication(),
    body: JSON.stringify(data)
  })
    .then((response) => spreeHandleFetchRequestResponse(response, true)
      .then((data) => {
        if (response.ok) {
          window.location.reload()
        } else {
          spreeHandleFetchRequestError(data)
        }
      }))
    .catch(err => console.log(err))
}

//
// REMOVE VARIANT FROM SHIPMENT
const removeVariantFromShipment = function(shipmentNumber, variantId, quantity = null) {
  showProgressIndicator()

  let data = {}

  if (quantity == null) {
    data = {
      variant_id: parseInt(variantId, 10)
    }
  } else {
    data = {
      quantity: quantity,
      variant_id: parseInt(variantId, 10)
    }
  }

  fetch(shipmentUri(shipmentNumber, 'remove'), {
    method: 'PUT',
    headers: Spree.apiV2Authentication(),
    body: JSON.stringify(data)
  })
    .then((response) => spreeHandleFetchRequestResponse(response, true)
      .then((data) => {
        if (response.ok) {
          window.location.reload()
        } else {
          spreeHandleFetchRequestError(data)
        }
      }))
    .catch(err => console.log(err))
}

//
// START SHIPMENT SPLIT
const startItemSplit = function(clickedLink, variantId, succeed) {
  showProgressIndicator()

  fetch(`${Spree.routes.variants_api_v2}/${variantId}/?include=stock_items,stock_locations`, {
    headers: Spree.apiV2Authentication()
  })
    .then((response) => spreeHandleFetchRequestResponse(response)
      .then((data) => {
        if (response.ok) {
          succeed(data, clickedLink)
        } else {
          spreeHandleFetchRequestError(data)
        }
      }))
    .catch(err => console.log(err))
}

//
// CREATE NEW SHIPMENT
const createShipment = function(data) {
  showProgressIndicator()

  fetch(Spree.routes.shipments_api_v2, {
    method: 'POST',
    headers: Spree.apiV2Authentication(),
    body: JSON.stringify(data)
  })
    .then((response) => spreeHandleFetchRequestResponse(response, true)
      .then((data) => {
        if (response.ok) {
          window.location.reload()
        } else {
          spreeHandleFetchRequestError(data)
        }
      }))
    .catch(err => console.log(err))
}

//
// UPDATE EXISTING SHIPMENT
const updateShipment = function(shipmentNumber, data) {
  showProgressIndicator()

  fetch(shipmentUri(shipmentNumber), {
    method: 'PUT',
    headers: Spree.apiV2Authentication(),
    body: JSON.stringify(data)
  })
    .then((response) => spreeHandleFetchRequestResponse(response, true)
      .then((data) => {
        if (response.ok) {
          window.location.reload()
        } else {
          spreeHandleFetchRequestError(data)
        }
      }))
    .catch(err => console.log(err))
}

//
// TRANSFER STOCK
const transferShipment = function(data, path) {
  showProgressIndicator()

  fetch(Spree.routes.shipments_api_v2 + path, {
    method: 'POST',
    headers: Spree.apiV2Authentication(),
    body: JSON.stringify(data)
  })
    .then((response) => spreeHandleFetchRequestResponse(response, true)
      .then((data) => {
        if (response.ok) {
          window.location.reload()
        } else {
          spreeHandleFetchRequestError(data)
        }
      }))
    .catch(err => console.log(err))
}

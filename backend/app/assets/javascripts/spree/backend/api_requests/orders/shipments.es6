/* eslint-disable no-undef */
/* eslint-disable no-unused-vars */

//
// BUILD URI
const shipmentUri = (shipmentNumber, action = '') => `${Spree.routes.shipments_api_v2}/${shipmentNumber}/${action}`

//
// SHIP
const shipShipment = function(shipmentNumber) {
  showProgressIndicator()

  fetch(shipmentUri(shipmentNumber, 'ship'), {
    method: 'PUT',
    headers: Spree.apiV2Authentication()
  })
    .then((response) => spreeHandleResponse(response).then(window.location.reload()))
    .catch(err => console.log(err))
}

//
// ADD
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
    .then((response) => spreeHandleResponse(response).then(window.location.reload()))
    .catch(err => console.log(err))
}

//
// REMOVE
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
  }).then((response) => spreeHandleResponse(response).then(window.location.reload()))
    .catch(err => console.log(err))
}

//
// START SHIPMENT SPLIT
const startItemSplit = function(clickedLink, variantId, succeed) {
  showProgressIndicator()

  fetch(`${Spree.routes.products_api_v2}?include=default_variant%2Cvariants&filter[variants_id_eq]=${variantId}`, {
    headers: Spree.apiV2Authentication()
  })
    .then((response) => spreeHandleResponse(response))
    .then((data) => succeed(data, clickedLink))
    .catch(err => console.log(err))
}

//
// CREATE
const createShipment = function(data) {
  showProgressIndicator()

  fetch(Spree.routes.shipments_api_v2, {
    method: 'POST',
    headers: Spree.apiV2Authentication(),
    body: JSON.stringify(data)
  })
    .then((response) => spreeHandleResponse(response).then(window.location.reload()))
    .catch(err => console.log(err))
}

//
// UPDATE
const updateShipment = function(shipmentNumber, data) {
  showProgressIndicator()

  fetch(shipmentUri(shipmentNumber), {
    method: 'PUT',
    headers: Spree.apiV2Authentication(),
    body: JSON.stringify(data)
  })
    .then((response) => spreeHandleResponse(response).then(window.location.reload()))
    .catch(err => console.log(err))
}

//
// TRANSFER
const transferShipment = function(data, path) {
  showProgressIndicator()

  fetch(Spree.routes.shipments_api_v2 + path, {
    method: 'POST',
    headers: Spree.apiV2Authentication(),
    body: JSON.stringify(data)
  })
    .then((response) => spreeHandleResponse(response).then(window.location.reload()))
    .catch(err => console.log(err))
}

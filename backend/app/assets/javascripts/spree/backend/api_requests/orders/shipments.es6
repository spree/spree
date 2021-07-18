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
    headers: { Authorization: 'Bearer ' + OAUTH_TOKEN, 'Content-Type': 'application/json' }
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
    headers: { Authorization: 'Bearer ' + OAUTH_TOKEN, 'Content-Type': 'application/json' },
    body: JSON.stringify(data)
  })
    .then((response) => spreeHandleResponse(response).then(window.location.reload()))
    .catch(err => console.log(err))
}

//
// REMOVE
const removeVariantFromShipment = function(shipmentNumber, variantId, quantity = null) {
  showProgressIndicator()

  const data = {
    quantity: quantity,
    variant_id: parseInt(variantId, 10)
  }

  fetch(shipmentUri(shipmentNumber, 'remove'), {
    method: 'PUT',
    headers: { Authorization: 'Bearer ' + OAUTH_TOKEN, 'Content-Type': 'application/json' },
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
// UPDATE
const updateShipment = function(shipmentNumber, data) {
  showProgressIndicator()

  fetch(shipmentUri(shipmentNumber), {
    method: 'PUT',
    headers: { Authorization: 'Bearer ' + OAUTH_TOKEN, 'Content-Type': 'application/json' },
    body: JSON.stringify(data)
  })
    .then((response) => spreeHandleResponse(response).then(window.location.reload()))
    .catch(err => console.log(err))
}

//
//
//
// TODO ###########################################
//

function addVariantFromStockLocation(event) {
  console.log('addVariantFromStockLocation')

  event.preventDefault()

  $('#stock_details').hide()

  var variantId = $('select.variant_autocomplete').val()
  var stockLocationId = $(this).data('stock-location-id')
  var quantity = $("input.quantity[data-stock-location-id='" + stockLocationId + "']").val()

  var shipment = _.find(shipments, function (shipment) {
    return shipment.stock_location_id === stockLocationId && (shipment.state === 'ready' || shipment.state === 'pending')
  })

  if (shipment === undefined) {
    $.ajax({
      type: 'POST',
      // eslint-disable-next-line camelcase
      url: Spree.url(Spree.routes.shipments_api + '?shipment[order_id]=' + order_number),
      data: {
        variant_id: variantId,
        quantity: quantity,
        stock_location_id: stockLocationId,
        token: Spree.api_key
      }
    }).done(function (msg) {
      window.location.reload()
    }).fail(function (msg) {
      alert(msg.responseJSON.message || msg.responseJSON.exception)
    })
  } else {
    // add to existing shipment
    adjustShipmentItems(shipment.number, variantId, quantity)
  }
  return 1
}

function completeItemSplit(event) {
  console.log('completeItemSplit')

  event.preventDefault()

  if ($('#item_stock_location').val() === '') {
    alert('Please select the split destination.')
    return false
  }

  var link = $(this)
  var stockItemRow = link.closest('tr')
  var variantId = stockItemRow.data('variant-id')
  var quantity = stockItemRow.find('#item_quantity').val()

  var stockLocationId = stockItemRow.find('#item_stock_location').val()
  var originalShipmentNumber = link.closest('tbody').data('shipment-number')

  var selectedShipment = stockItemRow.find('#item_stock_location option:selected')
  var targetShipmentNumber = selectedShipment.data('shipment-number')
  var newShipment = selectedShipment.data('new-shipment')

  // eslint-disable-next-line eqeqeq
  if (stockLocationId != 'new_shipment') {
    var path, additionalData
    if (newShipment !== undefined) {
      // transfer to a new location data
      path = '/transfer_to_location'
      additionalData = { stock_location_id: stockLocationId }
    } else {
      // transfer to an existing shipment data
      path = '/transfer_to_shipment'
      additionalData = { target_shipment_number: targetShipmentNumber }
    }

    var data = {
      original_shipment_number: originalShipmentNumber,
      variant_id: variantId,
      quantity: quantity,
      token: Spree.api_key
    }

    $.ajax({
      type: 'POST',
      async: false,
      url: Spree.url(Spree.routes.shipments_api + path),
      data: $.extend(data, additionalData)
    }).fail(function (msg) {
      alert(msg.responseJSON.message || msg.responseJSON.exception)
    }).done(function (msg) {
      window.location.reload()
    })
  }
}

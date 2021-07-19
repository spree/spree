/* eslint-disable no-unused-vars */
/* eslint-disable no-undef */

const handleShipButtonClick = function() {
  const shipButtons = document.querySelectorAll('[data-hook=admin_shipment_form] a.ship')
  if (shipButtons == null) return

  shipButtons.forEach(function(el) {
    el.addEventListener('click', function(event) {
      event.preventDefault()

      const shipmentNumber = this.dataset.shipmentNumber
      shipShipment(shipmentNumber)
    })
  })
}

const handleDeleteLineItemFromShipmentClick = function() {
  const deleteLineItemButtons = document.querySelectorAll('a.delete-item')
  if (deleteLineItemButtons == null) return

  deleteLineItemButtons.forEach(function(el) {
    el.addEventListener('click', function(event) {
      event.preventDefault()

      const shipmentNumber = this.dataset.shipmentNumber
      const variantId = this.dataset.variantId

      removeVariantFromShipment(shipmentNumber, variantId)
    })
  })
}

const handleSaveChangeToLineItemClick = function() {
  const saveButtons = document.querySelectorAll('a.save-item')
  if (saveButtons == null) return

  saveButtons.forEach(function(el) {
    el.addEventListener('click', function(event) {
      event.preventDefault()

      const parentTableRow = this.closest('tr')
      const inputValue = parentTableRow.querySelector('input.line_item_quantity').value

      const shipmentNumber = this.dataset.shipmentNumber
      const variantId = parseInt(this.dataset.variantId, 10)
      const quantity = parseInt(inputValue, 10)

      adjustShipmentItems(shipmentNumber, variantId, quantity)
    })
  })
}

const handleShippingMethodSaveClick = function() {
  const shippingMethodSaveButtons = document.querySelectorAll('[data-hook=admin_shipment_form] a.save-method')

  shippingMethodSaveButtons.forEach(function(el) {
    el.addEventListener('click', function(event) {
      event.preventDefault()

      const shipmentNumber = this.dataset.shipmentNumber
      const selectedShippingRateContainer = this.closest('tbody')
      const selectedShippingRateId = selectedShippingRateContainer.querySelector("select#selected_shipping_rate_id[data-shipment-number='" + shipmentNumber + "']").value

      const data = {
        shipment: {
          selected_shipping_rate_id: selectedShippingRateId
        }
      }

      updateShipment(shipmentNumber, data)
    })
  })
}

const handleTrackingNumberSaveClick = function() {
  const trackingSaveButtons = document.querySelectorAll('[data-hook=admin_shipment_form] a.save-tracking')
  trackingSaveButtons.forEach(function(el) {
    el.addEventListener('click', function(event) {
      event.preventDefault()

      const shipmentNumber = el.dataset.shipmentNumber
      const tracking = el.closest('tbody').querySelector('input#tracking').value

      const data = {
        shipment: {
          tracking: tracking
        }
      }

      updateShipment(shipmentNumber, data)
    })
  })
}

// Initiate click handeler functions listed above
document.addEventListener('DOMContentLoaded', function() {
  handleShipButtonClick()
  handleDeleteLineItemFromShipmentClick()
  handleSaveChangeToLineItemClick()
  handleShippingMethodSaveClick()
  handleTrackingNumberSaveClick()
})

const adjustShipmentItems = function(shipmentNumber, variantId, quantity) {
  const shipment = _.findWhere(shipments, { number: shipmentNumber + '' })
  const inventoryUnits = _.where(shipment.inventory_units, { variant_id: variantId })
  const previousQuantity = inventoryUnits.reduce(function (accumulator, currentUnit, _index, _array) {
    return accumulator + currentUnit.quantity
  }, 0)

  let newQuantity = 0

  if (previousQuantity < quantity) {
    newQuantity = (quantity - previousQuantity)
    if (newQuantity === 0) return

    addVariantToShipment(shipmentNumber, variantId, newQuantity)
  } else if (previousQuantity > quantity) {
    newQuantity = (previousQuantity - quantity)
    if (newQuantity === 0) return

    removeVariantFromShipment(shipmentNumber, variantId, newQuantity)
  }
}

const createTrackingValueContent = function(data) {
  const selectedShippingMethod = data.shipping_methods.filter(function (method) {
    return method.id === data.selected_shipping_rate.shipping_method_id
  })[0]

  if (selectedShippingMethod && selectedShippingMethod.tracking_url) {
    const shipmentTrackingUrl = selectedShippingMethod.tracking_url.replace(/:tracking/, data.tracking)
    return '<a target="_blank" href="' + shipmentTrackingUrl + '">' + data.tracking + '<a>'
  }
  return data.tracking
}

const addVariantFromStockLocation = function(event) {
  event.preventDefault()
  const variantId = document.querySelector('select.variant_autocomplete').value
  const stockLocationId = this.dataset.stockLocationId
  const quantity = document.querySelector("input.quantity[data-stock-location-id='" + stockLocationId + "']").value

  const shipment = _.find(shipments, function (shipment) {
    return shipment.stock_location_id === parseInt(stockLocationId, 10) && (shipment.state === 'ready' || shipment.state === 'pending')
  })

  if (shipment === undefined) {
    // Create A New Shipment
    const data = {
      order_id: order_number,
      variant_id: parseInt(variantId, 10),
      quantity: parseInt(quantity, 10),
      stock_location_id: parseInt(stockLocationId, 10)
    }
    createShipment(data)
  } else {
    // add to existing shipment
    adjustShipmentItems(shipment.number, variantId, quantity)
  }
}

const completeItemSplit = function(event) {
  event.preventDefault()

  // TODO: REMOVE JQUERY
  // TODO: Translate flash message
  if (document.querySelector('#item_stock_location').value === '') {
    show_flash('info', 'Please select the split destination.')
    return false
  }

  const link = $(this)
  const stockItemRow = link.closest('tr')
  const variantId = stockItemRow.data('variant-id')
  const quantity = stockItemRow.find('#item_quantity').val()

  const stockLocationId = stockItemRow.find('#item_stock_location').val()
  const originalShipmentNumber = link.closest('tbody').data('shipment-number')

  const selectedShipment = stockItemRow.find('#item_stock_location option:selected')
  const targetShipmentNumber = selectedShipment.data('shipment-number')
  const newShipment = selectedShipment.data('new-shipment')

  // eslint-disable-next-line eqeqeq
  if (stockLocationId != 'new_shipment') {
    let path, additionalData
    if (newShipment !== undefined) {
      // transfer to a new location data
      path = '/transfer_to_location'
      additionalData = { stock_location_id: stockLocationId }
    } else {
      // transfer to an existing shipment data
      path = '/transfer_to_shipment'
      additionalData = { target_shipment_number: targetShipmentNumber }
    }

    const data = {
      original_shipment_number: originalShipmentNumber,
      variant_id: variantId,
      quantity: quantity
    }

    const combinedData = Object.assign({}, data, additionalData)
    transferShipment(combinedData, path)
  }
}

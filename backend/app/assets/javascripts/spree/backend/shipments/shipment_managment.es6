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
      const variantId = parseInt(this.dataset.variantId)
      const quantity = parseInt(inputValue)

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

// Initiate click handelers above
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

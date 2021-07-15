/* eslint-disable no-undef */

document.addEventListener('DOMContentLoaded', function() {
  const handleShipClick = function() {
    const shipButton = document.querySelector('[data-hook=admin_shipment_form] a.ship')
    if (shipButton == null) return

    shipButton.addEventListener('click', function() {
      const shipmentNumber = this.dataset.shipmentNumber
      shipShipment(shipmentNumber)
    })
  }

  handleShipClick()
})

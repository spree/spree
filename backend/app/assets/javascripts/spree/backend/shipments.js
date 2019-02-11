/* global shipments, variantStockTemplate, order_number */
// Shipments AJAX API
$(document).ready(function () {
  'use strict'

  // handle variant selection, show stock level.
  $('#add_variant_id').change(function () {
    var variantId = parseInt($(this).val())

    var variant = _.find(window.variants, function (variant) {
      return variant.id === variantId
    })

    $('#stock_details').html(variantStockTemplate({ variant: variant }))
    $('#stock_details').show()

    $('button.add_variant').click(addVariantFromStockLocation)
  })

  // handle edit click
  $('a.edit-item').click(toggleItemEdit)

  // handle cancel click
  $('a.cancel-item').click(toggleItemEdit)

  // handle split click
  $('a.split-item').click(startItemSplit)

  // handle save click
  $('a.save-item').click(function () {
    var save = $(this)
    var shipmentNumber = save.data('shipment-number')
    var variantId = save.data('variant-id')

    var quantity = parseInt(save.parents('tr').find('input.line_item_quantity').val())

    toggleItemEdit()
    adjustShipmentItems(shipmentNumber, variantId, quantity)
    return false
  })

  // handle delete click
  $('a.delete-item').click(function (event) {
    if (confirm(Spree.translations.are_you_sure_delete)) {
      var del = $(this)
      var shipmentNumber = del.data('shipment-number')
      var variantId = del.data('variant-id')
      // eslint-disable-next-line
      var shipment = _.findWhere(shipments, { number: shipmentNumber + '' })
      var url = Spree.routes.shipments_api + '/' + shipmentNumber + '/remove'

      toggleItemEdit()

      $.ajax({
        type: 'PUT',
        url: Spree.url(url),
        data: {
          variant_id: variantId,
          token: Spree.api_key
        }
      }).done(function (msg) {
        window.location.reload()
      }).fail(function (msg) {
        alert(msg.responseJSON.message || msg.responseJSON.exception)
      })
    }
    return false
  })

  // handle ship click
  $('[data-hook=admin_shipment_form] a.ship').on('click', function () {
    var link = $(this)
    var shipmentNumber = link.data('shipment-number')
    var url = Spree.url(Spree.routes.shipments_api + '/' + shipmentNumber + '/ship.json')
    $.ajax({
      type: 'PUT',
      url: url,
      data: {
        token: Spree.api_key
      }
    }).done(function () {
      window.location.reload()
    }).fail(function (msg) {
      alert(msg.responseJSON.message || msg.responseJSON.exception)
    })
  })

  // handle shipping method edit click
  $('a.edit-method').click(toggleMethodEdit)
  $('a.cancel-method').click(toggleMethodEdit)

  // handle shipping method save
  $('[data-hook=admin_shipment_form] a.save-method').on('click', function (event) {
    event.preventDefault()

    var link = $(this)
    var shipmentNumber = link.data('shipment-number')
    var selectedShippingRateId = link.parents('tbody').find("select#selected_shipping_rate_id[data-shipment-number='" + shipmentNumber + "']").val()
    var unlock = link.parents('tbody').find("input[name='open_adjustment'][data-shipment-number='" + shipmentNumber + "']:checked").val()
    var url = Spree.url(Spree.routes.shipments_api + '/' + shipmentNumber + '.json')

    $.ajax({
      type: 'PUT',
      url: url,
      data: {
        shipment: {
          selected_shipping_rate_id: selectedShippingRateId,
          unlock: unlock
        },
        token: Spree.api_key
      }
    }).done(function () {
      window.location.reload()
    }).fail(function (msg) {
      alert(msg.responseJSON.message || msg.responseJSON.exception)
    })
  })

  function toggleTrackingEdit(event) {
    event.preventDefault()

    var link = $(this)
    link.parents('tbody').find('tr.edit-tracking').toggle()
    link.parents('tbody').find('tr.show-tracking').toggle()
  }

  // handle tracking edit click
  $('a.edit-tracking').click(toggleTrackingEdit)
  $('a.cancel-tracking').click(toggleTrackingEdit)

  function createTrackingValueContent(data) {
    var selectedShippingMethod = data.shipping_methods.filter(function (method) {
      return method.id === data.selected_shipping_rate.shipping_method_id
    })[0]

    if (selectedShippingMethod && selectedShippingMethod.tracking_url) {
      var shipmentTrackingUrl = selectedShippingMethod.tracking_url.replace(/:tracking/, data.tracking)
      return '<a target="_blank" href="' + shipmentTrackingUrl + '">' + data.tracking + '<a>'
    }

    return data.tracking
  }

  // handle tracking save
  $('[data-hook=admin_shipment_form] a.save-tracking').on('click', function (event) {
    event.preventDefault()

    var link = $(this)
    var shipmentNumber = link.data('shipment-number')
    var tracking = link.parents('tbody').find('input#tracking').val()
    var url = Spree.url(Spree.routes.shipments_api + '/' + shipmentNumber + '.json')

    $.ajax({
      type: 'PUT',
      url: url,
      data: {
        shipment: {
          tracking: tracking
        },
        token: Spree.api_key
      }
    }).done(function (data) {
      link.parents('tbody').find('tr.edit-tracking').toggle()

      var show = link.parents('tbody').find('tr.show-tracking')
      show.toggle()

      if (data.tracking) {
        show.find('.tracking-value').html($('<strong>').html(Spree.translations.tracking + ': ')).append(createTrackingValueContent(data))
      } else {
        show.find('.tracking-value').html(Spree.translations.no_tracking_present)
      }
    })
  })
})

function adjustShipmentItems(shipmentNumber, variantId, quantity) {
  var shipment = _.findWhere(shipments, { number: shipmentNumber + '' })
  var inventoryUnits = _.where(shipment.inventory_units, { variant_id: variantId })
  var url = Spree.routes.shipments_api + '/' + shipmentNumber
  var previousQuantity = inventoryUnits.reduce(function (accumulator, currentUnit, _index, _array) {
    return accumulator + currentUnit.quantity
  }, 0)
  var newQuantity = 0

  if (previousQuantity < quantity) {
    url += '/add'
    newQuantity = (quantity - previousQuantity)
  } else if (previousQuantity > quantity) {
    url += '/remove'
    newQuantity = (previousQuantity - quantity)
  }
  url += '.json'

  if (newQuantity !== 0) {
    $.ajax({
      type: 'PUT',
      url: Spree.url(url),
      data: {
        variant_id: variantId,
        quantity: newQuantity,
        token: Spree.api_key
      }
    }).done(function (msg) {
      window.location.reload()
    }).fail(function (msg) {
      alert(msg.responseJSON.message || msg.responseJSON.exception)
    })
  }
}

function toggleMethodEdit() {
  var link = $(this)
  link.parents('tbody').find('tr.edit-method').toggle()
  link.parents('tbody').find('tr.show-method').toggle()

  return false
}

function toggleItemEdit() {
  var link = $(this)
  var linkParent = link.parent()
  linkParent.find('a.edit-item').toggle()
  linkParent.find('a.cancel-item').toggle()
  linkParent.find('a.split-item').toggle()
  linkParent.find('a.save-item').toggle()
  linkParent.find('a.delete-item').toggle()
  link.parents('tr').find('td.item-qty-show').toggle()
  link.parents('tr').find('td.item-qty-edit').toggle()

  return false
}

function startItemSplit(event) {
  event.preventDefault()
  $('.cancel-split').each(function () {
    $(this).click()
  })
  var link = $(this)
  link.parent().find('a.edit-item').toggle()
  link.parent().find('a.split-item').toggle()
  link.parent().find('a.delete-item').toggle()
  var variantId = link.data('variant-id')

  var variant = {}
  $.ajax({
    type: 'GET',
    async: false,
    url: Spree.url(Spree.routes.variants_api),
    data: {
      q: {
        'id_eq': variantId
      },
      token: Spree.api_key
    }
  }).done(function (data) {
    variant = data['variants'][0]
  }).fail(function (msg) {
    alert(msg.responseJSON.message || msg.responseJSON.exception)
  })

  var maxQuantity = link.closest('tr').data('item-quantity')
  var splitItemTemplate = Handlebars.compile($('#variant_split_template').text())
  link.closest('tr').after(splitItemTemplate({ variant: variant, shipments: shipments, max_quantity: maxQuantity }))
  $('a.cancel-split').click(cancelItemSplit)
  $('a.save-split').click(completeItemSplit)

  $('#item_stock_location').select2({ width: 'resolve', placeholder: Spree.translations.item_stock_placeholder })
}

function completeItemSplit(event) {
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

  var selectedShipment = stockItemRow.find($('#item_stock_location').select2('data').element)
  var targetShipmentNumber = selectedShipment.data('shipment-number')
  var newShipment = selectedShipment.data('new-shipment')
  // eslint-disable-next-line eqeqeq
  if (stockLocationId != 'new_shipment') {
    if (newShipment !== undefined) {
      // TRANSFER TO A NEW LOCATION
      $.ajax({
        type: 'POST',
        async: false,
        url: Spree.url(Spree.routes.shipments_api + '/transfer_to_location'),
        data: {
          original_shipment_number: originalShipmentNumber,
          variant_id: variantId,
          quantity: quantity,
          stock_location_id: stockLocationId,
          token: Spree.api_key
        }
      }).fail(function (msg) {
        alert(msg.responseJSON.message || msg.responseJSON.exception)
      }).done(function (msg) {
        window.location.reload()
      })
    } else {
      // TRANSFER TO AN EXISTING SHIPMENT
      $.ajax({
        type: 'POST',
        async: false,
        url: Spree.url(Spree.routes.shipments_api + '/transfer_to_shipment'),
        data: {
          original_shipment_number: originalShipmentNumber,
          target_shipment_number: targetShipmentNumber,
          variant_id: variantId,
          quantity: quantity,
          token: Spree.api_key
        }
      }).fail(function (msg) {
        alert(msg.responseJSON.message || msg.responseJSON.exception)
      }).done(function (msg) {
        window.location.reload()
      })
    }
  }
}

function cancelItemSplit(event) {
  event.preventDefault()
  var link = $(this)
  var prevRow = link.closest('tr').prev()
  link.closest('tr').remove()
  prevRow.find('a.edit-item').toggle()
  prevRow.find('a.split-item').toggle()
  prevRow.find('a.delete-item').toggle()
}

function addVariantFromStockLocation(event) {
  event.preventDefault()

  $('#stock_details').hide()

  var variantId = $('input.variant_autocomplete').val()
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

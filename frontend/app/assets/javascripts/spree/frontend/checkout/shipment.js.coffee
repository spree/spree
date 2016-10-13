class @ShippingTotalManager
  REGEX_FOR_REMOVING_SPECIAL_CHARS = /[^0-9\.]+/g

  constructor: (@input) ->
    @shippingMethods = @input.shippingMethods
    @shipmentTotal = @input.shipmentTotal
    @orderTotal = @input.orderTotal

  calculateShipmentTotal: ->
    @sum = 0
    $.each ($(@shippingMethods).filter(':checked')), (idx, shippingMethod) =>
      @sum += @parseCurrencyToFloat($(shippingMethod).data('cost'))

    @readjustSummarySection(
      @parseCurrencyToFloat(@orderTotal.html()),
      @sum,
      @parseCurrencyToFloat(@shipmentTotal.html())
    )

  parseCurrencyToFloat: (input) ->
    parseFloat(input.replace(REGEX_FOR_REMOVING_SPECIAL_CHARS, ""))

  readjustSummarySection: (orderTotal, newShipmentTotal, oldShipmentTotal) ->
    newOrderTotal = orderTotal + (newShipmentTotal - oldShipmentTotal)
    @shipmentTotal.html(@shipmentTotal.data('currency') + newShipmentTotal.toFixed(2))
    @orderTotal.html(@orderTotal.data('currency') + newOrderTotal.toFixed(2))

  bindEvent: ->
    @shippingMethods.change =>
      @calculateShipmentTotal()

Spree.ready ($) ->
  input =
    orderTotal: $('#summary-order-total')
    shipmentTotal: $("[data-hook='shipping-total']")
    shippingMethods: $("input[data-behavior='shipping-method-selector']")

  new ShippingTotalManager(input).bindEvent()

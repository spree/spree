class @ShippingTotalManager
  constructor: (@input) ->
    @shippingMethods = @input.shippingMethods
    @shipmentTotal = @input.shipmentTotal
    @orderTotal = @input.orderTotal
    @formatOptions = {
      symbol : @shipmentTotal.data('currency'),
      decimal : @shipmentTotal.attr('decimal-mark'),
      thousand: @shipmentTotal.attr('thousands-separator'),
      precision : 2 }

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
    accounting.unformat(input, @formatOptions.decimal)

  readjustSummarySection: (orderTotal, newShipmentTotal, oldShipmentTotal) ->
    newOrderTotal = orderTotal + (newShipmentTotal - oldShipmentTotal)
    @shipmentTotal.html(accounting.formatMoney(newShipmentTotal, @formatOptions))
    @orderTotal.html(accounting.formatMoney(newOrderTotal, @formatOptions))

  bindEvent: ->
    @shippingMethods.change =>
      @calculateShipmentTotal()

Spree.ready ($) ->
  input =
    orderTotal: $('#summary-order-total')
    shipmentTotal: $("[data-hook='shipping-total']")
    shippingMethods: $("input[data-behavior='shipping-method-selector']")

  new ShippingTotalManager(input).bindEvent()

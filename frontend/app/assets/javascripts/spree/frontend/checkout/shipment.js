/* global accounting */
function ShippingTotalManager (input1) {
  this.input = input1
  this.shippingMethods = this.input.shippingMethods
  this.shipmentTotal = this.input.shipmentTotal
  this.orderTotal = this.input.orderTotal
  this.formatOptions = {
    symbol: this.shipmentTotal.data('currency'),
    decimal: this.shipmentTotal.attr('decimal-mark'),
    thousand: this.shipmentTotal.attr('thousands-separator'),
    precision: 2
  }
}

ShippingTotalManager.prototype.calculateShipmentTotal = function () {
  var checked = $(this.shippingMethods).filter(':checked')
  this.sum = 0
  $.each(checked, function (idx, shippingMethod) {
    this.sum += this.parseCurrencyToFloat($(shippingMethod).data('cost'))
  }.bind(this))
  return this.readjustSummarySection(this.parseCurrencyToFloat(this.orderTotal.html()), this.sum, this.parseCurrencyToFloat(this.shipmentTotal.html()))
}

ShippingTotalManager.prototype.parseCurrencyToFloat = function (input) {
  return accounting.unformat(input, this.formatOptions.decimal)
}

ShippingTotalManager.prototype.readjustSummarySection = function (orderTotal, newShipmentTotal, oldShipmentTotal) {
  var newOrderTotal = orderTotal + (newShipmentTotal - oldShipmentTotal)
  this.shipmentTotal.html(accounting.formatMoney(newShipmentTotal, this.formatOptions))
  return this.orderTotal.html(accounting.formatMoney(newOrderTotal, this.formatOptions))
}

ShippingTotalManager.prototype.bindEvent = function () {
  this.shippingMethods.change(function () {
    return this.calculateShipmentTotal()
  }.bind(this))
}

Spree.ready(function ($) {
  var input = {
    orderTotal: $('#summary-order-total'),
    shipmentTotal: $('[data-hook="shipping-total"]'),
    shippingMethods: $('input[data-behavior="shipping-method-selector"]')
  }
  return new ShippingTotalManager(input).bindEvent()
})

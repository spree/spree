//= require jquery.payment
//= require_self
//= require spree/frontend/checkout/address
//= require spree/frontend/checkout/payment

Spree.disableSaveOnClick = ->
  ($ 'form.edit_order').submit ->
    ($ this).find(':submit, :image').attr('disabled', true).removeClass('primary').addClass 'disabled'

Spree.ready ($) ->
  Spree.Checkout = {}

//= require jquery.payment
//= require_self
//= require spree/frontend/checkout/address
//= require spree/frontend/checkout/payment

Spree.disableSaveOnClick = ->
  ($ 'form.edit_order').submit ->
    disableSave(this)

Spree.disableUserInputOnClick = ->
  ($ 'form.edit_order').submit ->
    disableSave(this)
    $('.modal-background').css('display','block')
    $('.modal-foreground').css('display','block')

disableSave = (selector)->
  ($ selector).find(':submit, :image').attr('disabled', true).removeClass('primary').addClass 'disabled'
Spree.ready ($) ->
  Spree.Checkout = {}

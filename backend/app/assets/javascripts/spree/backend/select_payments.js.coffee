$ ->
  if $('.new_payment').is('*')
    $('.payment-method-settings fieldset').addClass('hidden').first().removeClass('hidden')
    $('input[name="payment[payment_method_id]"]').click ()->
      $('.payment-method-settings fieldset').addClass('hidden')
      id = $(this).parents('div.radio').data('id')
      $("fieldset[data-id='#{id}']").removeClass('hidden')

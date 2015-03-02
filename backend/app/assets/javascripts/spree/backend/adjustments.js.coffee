$(@).ready( ->
  $('[data-hook=adjustments_new_coupon_code] #add_coupon_code').click ->
    return if $("#coupon_code").val().length == 0
    $.ajax
      type: 'PUT'
      url: Spree.url(Spree.routes.apply_coupon_code(order_number))
      data:
        coupon_code: $("#coupon_code").val()
        token: Spree.api_key
      success: ->
        window.location.reload();
      error: (msg) ->
        if msg.responseJSON["error"]
          show_flash 'error', msg.responseJSON["error"]
        else
          show_flash 'error', "There was a problem adding this coupon code."
)

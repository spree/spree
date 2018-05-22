Spree.disableSaveOnClick = ->
  ($ 'form.edit_order').on('submit', (e) ->
    if (($ this).data('submitted') == true)
      # Previously submitted, don't submit again
      e.preventDefault()
    else
      # Mark it so that the next submit gets ignored
      ($ this).data('submitted', true)
      ($ this).find(':submit, :image').removeClass('primary').addClass 'disabled'
  )

Spree.enableSave = ->
  ($ 'form.edit_order').data('submitted', false).find(':submit, :image').attr('disabled', false).addClass('primary').removeClass 'disabled'

Spree.ready ($) ->

  $('.delete-coupon-button').click (event) ->
    coupon_code = $(this).attr('value')
    url = Spree.url(Spree.routes.remove_coupon_code(Spree.current_order_id), {
      order_token: Spree.current_order_token,
      coupon_code: coupon_code
    })

    $.ajax
      async: false
      method: 'PUT'
      url: url
      success: =>
        location.reload()
      error: =>
        alert Spree.translations.coupon_code_removal_error


  Spree.Checkout = {}

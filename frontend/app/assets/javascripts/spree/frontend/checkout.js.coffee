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
  Spree.Checkout = {}

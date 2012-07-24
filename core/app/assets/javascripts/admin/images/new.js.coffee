($ '#cancel_link').click (event) ->
  event.preventDefault()
  ($ '#new_image_link').show()
  ($ '#images').html('')

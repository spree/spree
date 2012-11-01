($ '#cancel_link').click (event) ->
  event.preventDefault()

  ($ '.no-objects-found').show()

  ($ '#new_image_link').show()
  ($ '#images').html('')

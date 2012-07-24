$ ->
  ($ '#new_image_link').click (event) ->
    event.preventDefault()
    ($ this).hide()
    $.ajax
      type: 'GET'
      url: @href
      data: (
        authenticity_token: AUTH_TOKEN
      )
      success: (r) ->
        ($ '#images').html r

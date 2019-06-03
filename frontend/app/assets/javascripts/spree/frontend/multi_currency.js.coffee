$ ->
  $('#currency').on 'change', ->
    $.ajax(
      type: 'POST'
      url: $(this).data('href')
      data:
        currency: $(this).val()
    ).done ->
      window.location.reload()

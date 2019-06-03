Spree.ready(function () {
  return $('#currency').on('change', function() {
    return $.ajax({
      type: 'POST',
      url: $(this).data('href'),
      data: {
        currency: $(this).val()
      }
    }).done(function() {
      return window.location.reload()
    })
  })
})

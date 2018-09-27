Spree.disableSaveOnClick = function () {
  $('form.edit_order').on('submit', function (event) {
    if ($(this).data('submitted') === true) {
      event.preventDefault()
    } else {
      $(this).data('submitted', true)
      $(this).find(':submit, :image').removeClass('primary').addClass('disabled')
    }
  })
}

Spree.enableSave = function () {
  $('form.edit_order').data('submitted', false).find(':submit, :image').attr('disabled', false).addClass('primary').removeClass('disabled')
}

Spree.ready(function () {
  Spree.Checkout = {}
  return Spree.Checkout
})

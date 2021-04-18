//= require spree/frontend/coupon_manager

Spree.disableSaveOnClick = function () {
  console.warn('DEPRECATION: Spree.disableSaveOnClick() will be removed in Spree 5.0')
  $('form.edit_order').on('submit', function (event) {
    if ($(this).data('submitted') === true) {
      event.preventDefault()
    } else {
      $(this).data('submitted', true)
      $(this).find(':submit, :image').removeClass('primary').addClass('disabled')
    }
  })
}

Spree.enableSave = () => {
  const submitButton = document.getElementById('checkout-submit')
  if (submitButton) submitButton.disabled = false
}

Spree.ready(() => {
  Spree.Checkout = {}
})

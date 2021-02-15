Spree.ready(function ($) {
  var currencySelect = $('#currency-select select')

  if (currencySelect.length) {
    currencySelect.on('change', function () {
      currencySelect.attr('disabled')
      Spree.showProgressBar()
      window.location = Spree.routes.set_currency(this.value)
    })
  }
})

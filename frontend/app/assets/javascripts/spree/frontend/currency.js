Spree.ready(function ($) {
  var currencySelect = $('#currency-select select')

  if (currencySelect.length) {
    currencySelect.on('change', function () {
      currencySelect.attr('disabled')
      var selectedCurrency = currencySelect.val()

      window.location = Spree.routes.set_currency(selectedCurrency)
    })
  }
})

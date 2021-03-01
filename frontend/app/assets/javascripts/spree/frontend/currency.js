Spree.ready(function ($) {
  var currencySelectForm = $('#currency-select')
  var currencySelectDropdown = currencySelectForm.find('select#switch_to_currency')

  if (currencySelectForm.length && currencySelectDropdown.length) {
    currencySelectDropdown.on('change', function () {
      Spree.clearCache()
      currencySelectDropdown.attr('disabled')
      Spree.showProgressBar()
      currencySelectForm.submit()
    })
  }
})

Spree.ready(function ($) {
  var localeSelectForm = $('#locale-select')
  var localeSelectDropdown = localeSelectForm.find('select#switch_to_locale')

  if (localeSelectForm.length && localeSelectDropdown.length) {
    localeSelectDropdown.on('change', function () {
      localeSelectDropdown.attr('disabled')
      Spree.showProgressBar()
      localeSelectForm.submit()
    })
  }
})

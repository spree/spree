Spree.ready(function ($) {
  var localeSelect = $('#locale-select select')

  if (localeSelect.length) {
    localeSelect.on('change', function () {
      localeSelect.attr('disabled')
      var selectedLocale = localeSelect.val()

      window.location = Spree.routes.set_locale(selectedLocale)
    })
  }
})

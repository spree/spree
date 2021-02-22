Spree.ready(function ($) {
  var localeSelect = $('#locale-select select')

  if (localeSelect.length) {
    localeSelect.on('change', function () {
      localeSelect.attr('disabled')
      Spree.showProgressBar()
      window.location = Spree.routes.set_locale(this.value)
    })
  }
})

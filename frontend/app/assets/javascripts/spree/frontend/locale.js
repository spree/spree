document.addEventListener('turbolinks:load', function () {
  var localeSelect = document.querySelectorAll('select[name=switch_to_locale]')

  if (localeSelect.length) {
    localeSelect.forEach(function (element) {
      element.addEventListener('change', function () {
        Spree.clearCache()
        Spree.showProgressBar()
        this.form.submit()
      })
    })
  }
})

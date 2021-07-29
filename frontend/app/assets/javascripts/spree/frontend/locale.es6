document.addEventListener('turbolinks:load', () => {
  const localeSelect = document.querySelectorAll('select[name=switch_to_locale]')

  if (localeSelect.length) {
    localeSelect.forEach((element) => {
      element.addEventListener('change', () => {
        Spree.clearCache()
        Spree.showProgressBar()
        element.form.submit()
      })
    })
  }
})

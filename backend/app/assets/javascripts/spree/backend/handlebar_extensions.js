Handlebars.registerHelper('t', function (key) {
  if (Spree.translations[key]) {
    return Spree.translations[key]
  } else {
    console.error('No translation found for ' + key + '. Does it exist within spree/admin/shared/_translations.html.erb?')
  }
})
Handlebars.registerHelper('edit_product_url', function (productId) {
  return Spree.routes.edit_product(productId)
})
Handlebars.registerHelper('name_or_presentation', function (optionValue) {
  if (optionValue.option_type_name === 'color') {
    return optionValue.name
  } else {
    return optionValue.presentation
  }
})

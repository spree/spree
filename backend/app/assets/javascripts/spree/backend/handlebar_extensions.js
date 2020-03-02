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
Handlebars.registerHelper('name_or_presentation', function (option_type_presentation, option_value) {
  if(option_type_presentation == 'Color') {
    return option_value.name.toUpperCase()
  } else {
    return option_value.presentation
  }
})

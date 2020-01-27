Spree.fetchRelatedProductcs = function (slug) {
  return $.ajax({
    url: Spree.routes.product_related(slug)
  }).done(function (data) {
    return $('#related-products').html(data)
  })
}

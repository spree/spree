Spree.fetchRelatedProductcs = function (slug, id) {
  return $.ajax({
    url: Spree.routes.product_related(slug),
    data: { id: id }
  }).done(function (data) {
    return $('#related-products').html(data)
  })
}

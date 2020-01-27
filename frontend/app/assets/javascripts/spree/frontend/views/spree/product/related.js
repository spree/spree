Spree.fetchRelatedProductcs = function (slug, id) {
  return $.ajax({
    url: Spree.routes.product_related(slug),
    data: { id: id }
  }).done(function (data) {
    $('#related-products').html(data);
    $('.carousel').carouselBootstrap4()
  })
}

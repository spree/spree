Spree.fetchRelatedProductcs = function (id) {
  return $.ajax({
    url: Spree.routes.product_related(id)
  }).done(function (data) {
    $('#related-products').html(data);
    $('.carousel').carouselBootstrap4()
  })
}

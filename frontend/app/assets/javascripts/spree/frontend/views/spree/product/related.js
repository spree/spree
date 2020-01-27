Spree.fetchRelatedProductcs = function (id) {
  return $.ajax({
    url: Spree.routes.product_related(id)
  }).done(function (data) {
    $('#related-products').html(data);
    $('.carousel').carouselBootstrap4()
  })
}

document.addEventListener('turbolinks:load', function () {
  var productId = $('div[data-related-products]').attr('data-related-products-id')
  var relatedProductsEnabled = $('div[data-related-products]').attr('data-related-products-enabled')

  if (relatedProductsEnabled && relatedProductsEnabled === 'true' && productId !== '') {
    Spree.fetchRelatedProductcs(productId)
  }
})

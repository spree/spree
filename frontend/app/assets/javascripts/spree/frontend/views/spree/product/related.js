//= require spree/frontend/viewport

Spree.fetchRelatedProductcs = function (id) {
  return $.ajax({
    url: Spree.routes.product_related(id)
  }).done(function (data) {
    $('#related-products').html(data)
    $('.carousel').carouselBootstrap4()
  })
}

document.addEventListener('turbolinks:load', function () {
  var productDetailsPage = $('body#product-details')

  if (productDetailsPage.length) {
    var productId = $('div[data-related-products]').attr('data-related-products-id')
    var relatedProductsEnabled = $('div[data-related-products]').attr('data-related-products-enabled')
    var relatedProductsFetched = false

    if (relatedProductsEnabled && relatedProductsEnabled === 'true' && productId !== '') {
      $(window).on('resize scroll', function () {
        if ($('#related-products').isInViewport() && !relatedProductsFetched) {
          Spree.fetchRelatedProductcs(productId)
          relatedProductsFetched = true
        }
      })
    }
  }
})

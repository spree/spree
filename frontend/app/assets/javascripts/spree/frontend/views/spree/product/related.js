//= require spree/frontend/viewport

Spree.fetchRelatedProducts = function (id, htmlContainer) {
  return $.ajax({
    url: Spree.routes.product_related(id)
  }).done(function (data) {
    htmlContainer.html(data)
    htmlContainer.find('.carousel').carouselBootstrap4()
  })
}

document.addEventListener('turbolinks:load', function () {
  var productDetailsPage = $('body#product-details')

  if (productDetailsPage.length) {
    var productId = $('div[data-related-products]').attr('data-related-products-id')
    var relatedProductsEnabled = $('div[data-related-products]').attr('data-related-products-enabled')
    var relatedProductsFetched = false
    var relatedProductsContainer = $('#related-products')

    if (!relatedProductsFetched && relatedProductsContainer.length && relatedProductsEnabled && relatedProductsEnabled === 'true' && productId !== '') {
      $(window).on('resize scroll', function () {
        if (!relatedProductsFetched && relatedProductsContainer.isInViewport()) {
          Spree.fetchRelatedProducts(productId, relatedProductsContainer)
          relatedProductsFetched = true
        }
      })
    }
  }
})

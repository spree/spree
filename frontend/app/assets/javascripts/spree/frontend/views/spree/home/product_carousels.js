Spree.fetchProductCarousel = function (taxonId, htmlContainer) {
  return $.ajax({
    url: Spree.routes.product_carousel(taxonId)
  }).done(function (data) {
    htmlContainer.html(data);
    htmlContainer.find('.carousel').carouselBootstrap4()
  })
}

document.addEventListener('turbolinks:load', function () {
  var homePage = $('body#home')

  if (homePage.length) {
    $('div[data-product-carousel').each(function (_index, element) {
      var productCarousel = $(this)
      var taxonId = productCarousel.attr('data-product-carousel-taxon-id')

      Spree.fetchProductCarousel(taxonId, $(element))
    })
  }
})

//= require spree/frontend/viewport

Spree.fetchProductCarousel = function (taxonId, htmlContainer) {
  return $.ajax({
    url: Spree.routes.product_carousel(taxonId)
  }).done(function (data) {
    htmlContainer.html(data);
    htmlContainer.find('.carousel').carouselBootstrap4()
  })
}

Spree.loadCarousel = function (element, div) {
  var container = $(element)
  var productCarousel = $(div)
  var carouselLoaded = productCarousel.attr('data-product-carousel-loaded')

  if (container.length && !carouselLoaded && container.isInViewport()) {
    var taxonId = productCarousel.attr('data-product-carousel-taxon-id')
    productCarousel.attr('data-product-carousel-loaded', 'true')

    Spree.fetchProductCarousel(taxonId, container)
  }
}

document.addEventListener('turbolinks:load', function () {
  var homePage = $('body#home')

  if (homePage.length) {
    var carousels = $('div[data-product-carousel')
    // load Carousels straight away if they are in the viewport
    carousels.each(function (_index, element) { Spree.loadCarousel(element, this) })

    // load additional Carousels when scrolling down
    $(window).on('resize scroll', function () {
      carousels.each(function (_index, element) { Spree.loadCarousel(element, this) })
    })
  }
})

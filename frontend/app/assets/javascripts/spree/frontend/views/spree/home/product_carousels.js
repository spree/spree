Spree.fetchProductCarousel = function (taxonId, htmlContainer) {
  return $.ajax({
    url: Spree.routes.product_carousel(taxonId)
  }).done(function (data) {
    htmlContainer.html(data);
    htmlContainer.find('.carousel').carouselBootstrap4()
  })
}

$.fn.isInViewport = function () {
  var elementTop = $(this).offset().top;
  var elementBottom = elementTop + $(this).outerHeight();
  var viewportTop = $(window).scrollTop();
  var viewportBottom = viewportTop + $(window).height();
  return elementBottom > viewportTop && elementTop < viewportBottom;
};

document.addEventListener('turbolinks:load', function () {
  var homePage = $('body#home')

  if (homePage.length) {
    $(window).on('resize scroll', function () {
      $('div[data-product-carousel').each(function (_index, element) {
        var container = $(element)
        var productCarousel = $(this)
        var carouselLoaded = productCarousel.attr('data-product-carousel-loaded')

        if (container.isInViewport() && !carouselLoaded) {
          var taxonId = productCarousel.attr('data-product-carousel-taxon-id')
          productCarousel.attr('data-product-carousel-loaded', 'true')

          Spree.fetchProductCarousel(taxonId, container)
        }
      })
    })
  }
})

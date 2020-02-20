Spree.ready(function($) {
  // Synchronize carousels.

  var carouselGroupIdentifierAttributeName =
    'data-product-carousel-group-identifier'
  var carouselPerPageAttributeName = 'data-product-carousel-per-page'
  var carouselIsSlaveAttributeName = 'data-product-carousel-is-slave'
  var carouselToSlideAttributeName = 'data-product-carousel-to-slide'
  var groupedCarousels = []
  Spree.goToCarouselSlide = function(
    $invokedCarousel,
    slideIndex,
    slideIndexLocalToSlide,
    respectIsSlave
  ) {
    var elementGroupIdentifier = $invokedCarousel.attr(
      carouselGroupIdentifierAttributeName
    )

    var carouselGroupDescription = groupedCarousels.find(function(
      candidateCarouselGroupDescription
    ) {
      return (
        candidateCarouselGroupDescription.identifier === elementGroupIdentifier
      )
    })

    carouselGroupDescription.elements.forEach(function(element) {
      var $candidateCarousel = element.$carousel
      if (
        (!respectIsSlave || element.isSlave) &&
        !$candidateCarousel.is($invokedCarousel)
      ) {
        setTimeout(function() {
          // setTimeout is required due to "Returns to the caller before the target item has been shown" issue.
          // Details: https://getbootstrap.com/docs/4.0/components/carousel/#carouselnumber
          if (slideIndexLocalToSlide) {
            var invokedPerPage = carouselGroupDescription.elements.find(
              function(element) {
                var $candidateCarousel = element.$carousel
                return $candidateCarousel.is($invokedCarousel)
              }
            ).perPage

            $candidateCarousel.carouselBootstrap4(
              Math.floor((slideIndex * invokedPerPage) / element.perPage)
            )
          } else {
            $candidateCarousel.carouselBootstrap4(
              Math.floor(slideIndex / element.perPage)
            )
          }
        })
      }
    })
  }

  $('[' + carouselGroupIdentifierAttributeName + ']').each(function(
    _carouselIndex,
    carouselElement
  ) {
    var $carousel = $(carouselElement)

    $carousel.carouselBootstrap4()

    var elementGroupIdentifier = $carousel.attr(
      carouselGroupIdentifierAttributeName
    )
    var perPage = parseInt($carousel.attr(carouselPerPageAttributeName)) || 1
    var isSlave = !!$carousel.attr(carouselIsSlaveAttributeName)

    var carouselGroupDescription = groupedCarousels.find(function(
      candidateCarouselGroupDescription
    ) {
      return (
        candidateCarouselGroupDescription.identifier === elementGroupIdentifier
      )
    })
    if (carouselGroupDescription) {
      carouselGroupDescription.elements.push({
        $carousel: $carousel,
        perPage: perPage,
        isSlave: isSlave
      })
    } else {
      groupedCarousels.push({
        identifier: elementGroupIdentifier,
        elements: [
          {
            $carousel: $carousel,
            perPage: perPage,
            isSlave: isSlave
          }
        ]
      })
    }
  })

  $('body').on('click', '[' + carouselToSlideAttributeName + ']', function(
    event
  ) {
    var $invokedCarousel = $(
      event.currentTarget.closest(
        '[' + carouselGroupIdentifierAttributeName + ']'
      )
    )

    var toSlideOnPageIndex = parseInt(
      $(event.currentTarget).attr(carouselToSlideAttributeName)
    )

    Spree.goToCarouselSlide($invokedCarousel, toSlideOnPageIndex, false, false)
  })

  $('body').on(
    'slide.bs.carousel',
    '[' + carouselGroupIdentifierAttributeName + ']',
    function(event) {
      var invokedCarouselElement = event.relatedTarget.closest(
        '[' + carouselGroupIdentifierAttributeName + ']'
      )
      var $invokedCarousel = $(invokedCarouselElement)
      var toSlideIndex = event.to
      Spree.goToCarouselSlide($invokedCarousel, toSlideIndex, true, true)
    }
  )

  $('.carousel').carouselBootstrap4()
})

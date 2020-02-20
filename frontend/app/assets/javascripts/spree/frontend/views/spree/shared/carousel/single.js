Spree.ready(function($) {
  // Adjust single carousel based on picked variant.

  var productDetailsPage = $('#product-details')

  if (productDetailsPage.length) {
    var variantIdAttributeName = 'data-variant-id'
    var carouselItemsContainerSelector = '.carousel-inner'
    var carouselItemSelector = '[data-variant-id]'
    var isMasterVariantAttributeName = 'data-variant-is-master'
    var enabledCarouselItemClass = 'carousel-item'
    var activeCarouselItemClass = 'active'
    var getCarouselsWithVariantChangeTriggerSelector = function(triggerId) {
      return (
        '.product-carousel[data-variant-change-trigger-identifier=' +
        triggerId +
        ']'
      )
    }
    var carouselEmptyClass = 'product-carousel--empty'
    var carouselIndicatorsContainerSelector = '.product-carousel-indicators'
    var carouselIndicatorSelector = '.product-carousel-indicators-indicator'
    var enabledCarouselIndicatorClass =
      'product-carousel-indicators-indicator--visible'
    var activeCarouselIndicatorClass = 'active'
    var carouselIndicatorSlidetoAttributeName = 'data-slide-to'

    Spree.showSingleCarouselVariantImages = function($carousel, variantId) {
      $carousel.carouselBootstrap4('dispose')
      var oldActiveQualifiedIndex = null
      var $firstQualifyingSlide = null
      var qualifiedSlides = 0
      var $carouselIndicatorsContainer = $carousel.find(
        carouselIndicatorsContainerSelector
      )
      var $carouselItemsContainer = $carousel.find(carouselItemsContainerSelector)
      var $carouselIndicators = $carousel.find(carouselIndicatorSelector)
      $carousel
        .find(carouselItemSelector)
        .each(function(itemIndex, slideElement) {
          var $slide = $(slideElement)
          var qualifies =
            $slide.attr(variantIdAttributeName) === variantId ||
            $slide.attr(isMasterVariantAttributeName) === 'true'
          var $slideIndicator = $carouselIndicators.eq(itemIndex)

          if (qualifies) {
            qualifiedSlides += 1
            // Switch indicator slide to index based on picked variant.
            $slideIndicator.attr(
              carouselIndicatorSlidetoAttributeName,
              qualifiedSlides - 1
            )
          } else {
            $slideIndicator.detach()
            $carouselIndicatorsContainer.append($slideIndicator)

            $slide.detach()
            $carouselItemsContainer.append($slide)
          }

          // Switch item visibility in the carousel based on picked variant.
          $slide.toggleClass(enabledCarouselItemClass, qualifies)
          // Switch indicator visibility in the carousel based on picked variant.
          $slideIndicator.toggleClass(enabledCarouselIndicatorClass, qualifies)

          // Safari doesn't correctly calculate width of $slideIndicator after page loading.
          // w-100 class makes Safari work as expected. For visible images we don't need this class anymore.
          $slideIndicator.find('img').toggleClass('w-100', !qualifies)

          $slideIndicator.removeClass(activeCarouselIndicatorClass)

          // Select an active image included in the new list of images for selected variant.
          if (qualifies) {
            if ($slide.hasClass(activeCarouselItemClass)) {
              // Use the current active slide if it's still active after changing the variant.
              oldActiveQualifiedIndex = qualifiedSlides - 1
            }

            if ($firstQualifyingSlide === null) {
              $firstQualifyingSlide = $slide
            }
          } else {
            $slide.removeClass(activeCarouselItemClass)
          }
        })

      if (qualifiedSlides === 0) {
        // There are no images to show after picking a variant. Disable the carousel.
        $carousel.addClass(carouselEmptyClass)
      } else {
        $carousel.removeClass(carouselEmptyClass)

        if (oldActiveQualifiedIndex === null) {
          // Pick the first qualifying slide if the old active slide does not qualify.
          $firstQualifyingSlide.addClass(activeCarouselItemClass)
          // Activate first indicator.
          $carouselIndicators
            .filter('.' + enabledCarouselIndicatorClass)
            .eq(0)
            .addClass(activeCarouselIndicatorClass)
        } else {
          // Activate proper indicator based on active slide.
          $carouselIndicators
            .filter('.' + enabledCarouselIndicatorClass)
            .eq(oldActiveQualifiedIndex)
            .addClass(activeCarouselIndicatorClass)
        }

        $carousel.carouselBootstrap4()

        setTimeout(function() {
          // Add delay to allow other carousels to adjust their slides after a variant is picked before syncing slides.
          var enabledSlides = $carousel.find('.' + enabledCarouselItemClass)
          var toSlideIndex = enabledSlides.index(
            enabledSlides.find('.' + activeCarouselItemClass)
          )
          Spree.goToCarouselSlide($carousel, toSlideIndex, true, true)
          Spree.addSwipeEventListeners($carousel)

          $carousel.on('slide.bs.carousel', function(event) {
            $carousel.trigger('single_carousel:slide', event.to)
          })
        })
      }
    }

    productDetailsPage.on('variant_id_change', function (options) {
      var triggerId = options.triggerId
      var variantId = options.variantId
      $(getCarouselsWithVariantChangeTriggerSelector(triggerId)).each(function (
        _carouselElementIndex,
        carouselElement
      ) {
        Spree.showSingleCarouselVariantImages($(carouselElement), variantId)
      })
    })
  }
})

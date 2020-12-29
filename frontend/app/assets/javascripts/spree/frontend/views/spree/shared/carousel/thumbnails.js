function ThumbnailsCarousel($, carousel) {
  var VISIBLE_IMAGE_SELECTOR = '.product-thumbnails-carousel-item-single--visible img'
  var SELECTED_IMAGE_CLASS = 'selected'
  var self = this
  var modalCarouselId = 'productModalThumbnailsCarousel'
  var modalCarousel = $('#' + modalCarouselId)
  var zoomClickObject = $('.product-carousel-overlay-modal-opener')

  this.constructor = function() {
    this.bindEventHandlers()
  }

  this.bindEventHandlers = function() {
    zoomClickObject.on('click', this.handleZoomClick)
    carousel.on('click', 'img', this.handleImageClick)
    carousel.on('thumbnails:ready', this.handleThumbnailsReady)

    $('body').on('single_carousel:slide', this.handleSingleCarouselSlide)
  }

  this.handleImageClick = function(event) {
    self.selectImage(event, $(event.target))
  }

  this.handleThumbnailsReady = function(event) {
    var image = carousel.find(VISIBLE_IMAGE_SELECTOR).eq(0)

    self.selectImage(event, image)
  }

  this.handleSingleCarouselSlide = function(event, imageIndex) {
    var image;
    if (event.target.id === 'productModalCarousel') {
      image = modalCarousel.find('[data-product-carousel-to-slide=' + imageIndex + '] img')
      self.unselectModalImages()
    } else {
      image = carousel.find('[data-product-carousel-to-slide=' + imageIndex + '] img')
      self.unselectThumbanilsImages()
    }

    image.addClass(SELECTED_IMAGE_CLASS)
  }

  this.selectImage = function(event, image) {
    var clickedElement = event.target
    var productModalThumbnailClicked = $(clickedElement).closest('.product-thumbnails-carousel').is('#' + modalCarouselId)

    if (clickedElement.id === modalCarouselId || productModalThumbnailClicked) {
      this.unselectModalImages()
    } else {
      this.unselectThumbanilsImages()
    }

    image.addClass(SELECTED_IMAGE_CLASS)
  }

  this.unselectThumbanilsImages = function() {
    carousel.find('img').removeClass(SELECTED_IMAGE_CLASS)
  }

  this.unselectModalImages = function() {
    modalCarousel.find('img').removeClass(SELECTED_IMAGE_CLASS)
  }

  this.handleZoomClick = function(event) {
    var selectedImageId = self.getSelectedImageId()
    var image = modalCarousel.find(VISIBLE_IMAGE_SELECTOR).eq(selectedImageId)
    self.unselectModalImages()

    image.addClass(SELECTED_IMAGE_CLASS)
  }

  this.getSelectedImageId = function() {
    var selectedImages = $('#productThumbnailsCarousel').find('img.d-block.w-100.lazyloaded.selected')

    if (selectedImages.length > 1) {
      return $(selectedImages[1]).parent()[0].dataset.productCarouselToSlide
    } else {
      return '0'
    }
  }

  this.constructor()
}

Spree.ready(function($) {
  // Adjust thumbnails carousel based on picked variant.

  if ($('#product-details').length) {

    var variantIdAttributeName = 'data-variant-id'
    var carouselItemSelector = '[data-variant-id]'
    var isMasterVariantAttributeName = 'data-variant-is-master'
    var enabledCarouselItemClass = 'carousel-item'
    var activeCarouselItemClass = 'active'
    var getCarouselsWithVariantChangeTriggerSelector = function(triggerId) {
      return (
        '.product-thumbnails-carousel[data-variant-change-trigger-identifier="' +
        triggerId +
        '"]'
      )
    }

    Spree.showThumbnailsCarouselVariantImages = function(carousel, variantId) {
      var carouselSlideSelector = '.product-thumbnails-carousel-item'
      var carouselSlideContainerSelector =
        '.product-thumbnails-carousel-item-content'
      var enabledCarouselSingleClass =
        'product-thumbnails-carousel-item-single--visible'
      var carouselToSlideAttributeName = 'data-product-carousel-to-slide'
      var carouselPerPageAttributeName = 'data-product-carousel-per-page'
      var carouselEmptyClass = 'product-thumbnails-carousel--empty'

      carousel.carouselBootstrap4('dispose')
      var qualifiedSlides = 0
      var perPage = parseInt(carousel.attr(carouselPerPageAttributeName)) || 1
      var slides = carousel.find(carouselSlideSelector)

      carousel
        .find(carouselItemSelector)
        .each(function(_itemIndex, slideElement) {
          // Switch item visibility in the carousel based on picked variant.

          var targetSlideIndex
          var slide = $(slideElement)
          var qualifies =
            slide.attr(variantIdAttributeName) === variantId ||
            slide.attr(isMasterVariantAttributeName) === 'true'

          if (qualifies) {
            qualifiedSlides += 1
            slide.attr(carouselToSlideAttributeName, qualifiedSlides - 1)
          }

          targetSlideIndex = Math.max(0, Math.ceil(qualifiedSlides / perPage) - 1)
          slide.detach()
          slides
            .eq(targetSlideIndex)
            .find(carouselSlideContainerSelector)
            .append(slide)
          slide.toggleClass(enabledCarouselSingleClass, qualifies)
        })
      var enabledSlidesCount = Math.ceil(qualifiedSlides / perPage)
      carousel
        .find(carouselSlideSelector)
        .each(function(slideIndex, slideElement) {
          var slide = $(slideElement)
          slide.toggleClass(
            enabledCarouselItemClass,
            slideIndex < enabledSlidesCount
          )
          slide.toggleClass(activeCarouselItemClass, slideIndex === 0)
        })

      // If there are no images to show after picking a variant, disable the carousel.
      carousel.toggleClass(carouselEmptyClass, enabledSlidesCount === 0)

      carousel.carouselBootstrap4()
      carousel.trigger('thumbnails:ready')
    }

    $('#product-details').on('variant_id_change', function(options) {
      var triggerId = options.triggerId
      var variantId = options.variantId
      $(getCarouselsWithVariantChangeTriggerSelector(triggerId)).each(function(
        _carouselElementIndex,
        carouselElement
      ) {
        Spree.showThumbnailsCarouselVariantImages($(carouselElement), variantId)
      })
    })

    var carousel = $('#productThumbnailsCarousel')

    ThumbnailsCarousel($, carousel)
  }
})

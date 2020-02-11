Spree.ready(function($) {
  var $modalCarousel = $('#productModalThumbnailsCarousel')
  if ($modalCarousel.length) {
    ThumbnailsCarousel($, $modalCarousel)
  }

  var activeSingleImageIndex = function(sourceWrappingClass) {
    var $activeSingleImage = $('.' + sourceWrappingClass + ' .product-details-single [data-variant-id].active')
    return $activeSingleImage.index()
  }

  var selectModalThumbnail = function(imgIndex) {
    var carouselPerPage = $('#productModalThumbnailsCarousel').data('product-carousel-per-page')
    var carouselItems = $('#productModalThumbnailsCarousel > div > div.carousel-item.product-thumbnails-carousel-item')
    var carouselItem = carouselItems[Math.floor(imgIndex / carouselPerPage)]

    carouselItems.removeClass('active')
    $(carouselItems).find('img').removeClass('selected')
    $(carouselItem).addClass('active')

    var $modalThumbnailsChildren = $(carouselItem).find('> div > div').children('[data-variant-id]')
    if ($modalThumbnailsChildren.length > 0) {
      $($modalThumbnailsChildren.get(imgIndex % carouselPerPage).getElementsByTagName('img')[0]).addClass('selected')
    }
  }

  var activateModalSingleImg = function(imgIndex, targetWrappingClass) {
    $('.' + targetWrappingClass + ' .product-details-single [data-variant-id].active').removeClass('active')
    var $modalActiveSingleImage = $($('.' + targetWrappingClass + ' .product-details-single [data-variant-id]').parent().children().get(imgIndex))
    $modalActiveSingleImage.addClass('active')
  }

  $('#picturesModal').on('show.bs.modal', function() {
    var rowActiveSingleImageIndex = activeSingleImageIndex('row')
    selectModalThumbnail(rowActiveSingleImageIndex - 1)
    activateModalSingleImg(rowActiveSingleImageIndex, 'modal')
  })

  $('#picturesModal').on('hide.bs.modal', function() {
    activateModalSingleImg(activeSingleImageIndex('modal'), 'row')
  })
})

Spree.ready(function($) {
  var $modalCarousel = $('#productModalThumbnailsCarousel')
  var modalThumbnails = new ThumbnailsCarousel($, $modalCarousel)

  var selectedThumbnailVariantId =  function() {
    var $selectedThumbnail = $('.row .product-thumbnails-carousel-item-single.product-thumbnails-carousel-item-single--visible .selected')
    return $selectedThumbnail[0].parentNode.getAttribute('data-variant-id')
  }

  var activeSingleImageIndex = function(sourceWrappingClass) {
    var $activeSingleImage = $('.' + sourceWrappingClass + ' .product-details-single [data-variant-id="' + selectedThumbnailVariantId() + '"].active')
    return $activeSingleImage.index()
  }

  var selectModalThumbnail = function(variantId, imgIndex) {
    var modalThumbnails = $('#productModalThumbnailsCarousel > div > div.carousel-item.product-thumbnails-carousel-item.active > div > div')
    $(modalThumbnails.children('[data-variant-id="' + variantId + '"]').get(imgIndex).getElementsByTagName('img')[0]).addClass('selected')
  }

  var activateModalSingleImg = function(variantId, imgIndex, targetWrappingClass) {
    $('.' + targetWrappingClass + ' .product-details-single [data-variant-id="' + variantId + '"].active').removeClass('active')
    var $modalActiveSingleImage = $($('.' + targetWrappingClass + ' .product-details-single [data-variant-id="' + variantId + '"]').parent().children().get(imgIndex))
    $modalActiveSingleImage.addClass('active')
  }

  $('#picturesModal').on('show.bs.modal', function() {
    var variantId = selectedThumbnailVariantId()
    var rowActiveSingleImageIndex = activeSingleImageIndex('row')
    selectModalThumbnail(variantId, rowActiveSingleImageIndex - 1)
    activateModalSingleImg(variantId, rowActiveSingleImageIndex, 'modal')
  })

  $('#picturesModal').on('hide.bs.modal', function() {
    activateModalSingleImg(selectedThumbnailVariantId(), activeSingleImageIndex('modal'), 'row')
  })
})

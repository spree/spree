Spree.ready(function($) {
  Spree.addSwipeEventListeners = function($carousel) {
    var touchStartX = 0
    var touchStartY = 0
    var touchCurrentX = 0
    var touchCurrentY = 0

    var SWIPE_THRESHOLD = 40

    $carousel.on('touchstart.bs.carousel', function(event) {
      touchStartX = event.touches[0].clientX
      touchStartY = event.touches[0].clientY
    })

    $carousel.on('touchmove.bs.carousel', function(event) {
      touchCurrentX = event.touches[0].clientX
      touchCurrentY = event.touches[0].clientY
    })

    $carousel.on('touchend.bs.carousel', function(_event) {
      var carouselInstance = $carousel.data('bs.carousel')

      var touchDeltaX = touchCurrentX - touchStartX
      var touchDeltaY = touchCurrentY - touchStartY

      var absDeltaX = Math.abs(touchDeltaX)
      var absDeltaY = Math.abs(touchDeltaY)

      if (touchCurrentX > 0 && absDeltaX > SWIPE_THRESHOLD && absDeltaX > absDeltaY) {
        var direction = absDeltaX / touchDeltaX

        if (direction > 0) {
          carouselInstance.prev()
        }

        if (direction < 0) {
          carouselInstance.next()
        }
      }

      touchCurrentX = 0
      touchStartX = 0
      touchCurrentY = 0
      touchStartY = 0

      carouselInstance.touchDeltaX = 0
    })
  }

  $('.carousel').each(function(_index, carousel) {
    Spree.addSwipeEventListeners($(carousel))
  })
})

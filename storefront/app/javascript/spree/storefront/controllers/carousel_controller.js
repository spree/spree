import Carousel from '@stimulus-components/carousel'

export default class extends Carousel {
  static targets = ['pagination']

  get defaultOptions() {
    const setStyle = (el, display) => {
      if (Array.isArray(el)) {
        el.forEach((cEl) => (cEl.style.display = display))
      } else {
        el.style.display = display
      }
    }

    return Object.assign(super.defaultOptions, {
      pagination: {
        el: this.hasPaginationTarget ? this.paginationTarget : undefined
      },
      on: {
        // Hide the arrow buttons if there are not needed
        init: function () {
          if (this.navigation.prevEl && this.navigation.nextEl) {
            if (!this.allowSlidePrev && !this.allowSlideNext) {
              setStyle(this.navigation.prevEl, 'none')
              setStyle(this.navigation.nextEl, 'none')
            }
          }
        },
        resize: function () {
          if (this.navigation.prevEl && this.navigation.nextEl) {
            if (!this.allowSlidePrev && !this.allowSlideNext) {
              setStyle(this.navigation.prevEl, 'none')
              setStyle(this.navigation.nextEl, 'none')
            } else {
              // Let class hide/show the arrows
              setStyle(this.navigation.prevEl, null)
              setStyle(this.navigation.nextEl, null)
            }
          }
        }
      }
    })
  }
}

import { Controller } from '@hotwired/stimulus'
import Swiper from 'swiper/bundle'

export default class extends Controller {
  static targets = ['imagesSlider', 'imagesSliderPagination', 'imagesThumbsSlider', 'prevArrow', 'nextArrow']
  connect() {
    const thumbsSwiper = new Swiper(this.imagesThumbsSliderTarget, {
      spaceBetween: 4,
      direction: 'vertical',
      slidesPerView: 'auto',
      freeMode: { enabled: true, sticky: true },
      watchSlidesProgress: true,
      watchOverflow: true
    })
    new Swiper(this.imagesSliderTarget, {
      slidesPerView: 1,
      pagination: {
        el: this.hasImagesSliderPaginationTarget ? this.imagesSliderPaginationTarget : undefined
      },
      thumbs: { swiper: thumbsSwiper, autoScrollOffset: 2 },
      watchOverflow: true,
      navigation: {
        prevEl: this.prevArrowTarget,
        nextEl: this.nextArrowTarget
      }
    })
  }
}

import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = [
    'container',
    'content',
    'wrapper',
    'line_items',
    'coupon_area'
  ]

  onCouponResize() {
    this.line_itemsTarget.style.maxHeight = `${window.innerHeight - this.coupon_areaTarget.offsetHeight - 20}px`
  }

  connect() {
    var wrapper = this.wrapperTarget
    var summary = this.containerTarget
    var content = this.contentTarget
    var couponArea = this.coupon_areaTarget

    summary.style.height = content.offsetHeight + 'px'
    wrapper.classList.toggle('summary-folded', true)

    this.observer = new ResizeObserver(function () {
      summary.style.height = content.offsetHeight + 'px'
    })

    this.couponObserver = new ResizeObserver(this.onCouponResize.bind(this))

    window.addEventListener('resize', this.onCouponResize.bind(this))

    this.observer.observe(content)
    this.couponObserver.observe(couponArea)
  }

  disconnect() {
    if (this.observer) {
      this.observer.disconnect()
    }
    if (this.couponObserver) {
      this.couponObserver.disconnect()
    }
    window.removeEventListener('resize', this.onCouponResize.bind(this))
  }
}

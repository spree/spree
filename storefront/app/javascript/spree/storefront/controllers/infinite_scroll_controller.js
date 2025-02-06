import { Controller } from '@hotwired/stimulus'
import { get } from '@rails/request.js'

export default class extends Controller {
  static values = { offset: String }
  initialize() {
    this.intersectionObserver = new IntersectionObserver(this.checkIntersection, { rootMargin: this.offsetValue })
  }

  connect() {
    this.intersectionObserver.observe(this.element)
  }

  disconnect() {
    this.intersectionObserver.unobserve(this.element)
  }

  checkIntersection = async (entries) => {
    for (const entry of entries) {
      if (entry.isIntersecting) {
        await this.loadMore()
        break
      }
    }
  }

  async loadMore() {
    this.element.disabled = true
    await get(this.element.src, { responseKind: 'turbo-stream' })
  }
}

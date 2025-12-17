import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static values = {
    threshold: { type: Number, default: 60 }
  }

  connect() {
    this.handleScroll = this.handleScroll.bind(this)
    window.addEventListener('scroll', this.handleScroll)
  }

  disconnect() {
    window.removeEventListener('scroll', this.handleScroll)
  }

  handleScroll() {
    if (window.scrollY > this.thresholdValue) {
      this.element.classList.add('sticky')
      this.element.classList.add('top-0')
      this.element.classList.add('z-[1020]')
    } else {
      this.element.classList.remove('sticky')
      this.element.classList.remove('top-0')
      this.element.classList.remove('z-[1020]')
    }
  }
}
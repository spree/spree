import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  // we need to preserve the width of the button so it won't change after we replace the text with the spinner
  connect() {
    // Handle hidden elements or dynamically added elements by checking if dimensions are available
    if (this.element.offsetWidth > 0 && this.element.offsetHeight > 0) {
      this.originalWidth = this.element.offsetWidth
      this.originalHeight = this.element.offsetHeight
    } else {
      // For hidden elements, get computed style dimensions or use a reasonable default
      const computedStyle = window.getComputedStyle(this.element)
      this.originalWidth = parseInt(computedStyle.width) || this.element.scrollWidth || 100
      this.originalHeight = parseInt(computedStyle.height) || this.element.scrollHeight || 36
    }
    this.element.style.width = `${this.originalWidth}px`
    this.element.style.height = `${this.originalHeight}px`
  }
}
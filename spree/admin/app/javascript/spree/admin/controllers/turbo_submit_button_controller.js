import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  // we need to preserve the width of the button so it won't change after we replace the text with the spinner
  connect() {
    // Handle hidden elements or dynamically added elements by checking if dimensions are available
    if (this.element.offsetWidth > 0 && this.element.offsetHeight > 0) {
      this.originalWidth = this.element.offsetWidth
      this.originalHeight = this.element.offsetHeight
    }
    this.element.style.width = `${this.originalWidth+10}px`
    this.element.style.height = `${this.originalHeight}px`
  }
}
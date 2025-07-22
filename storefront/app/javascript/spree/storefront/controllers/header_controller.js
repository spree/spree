import { Controller } from '@hotwired/stimulus'
import Headroom from 'headroom.js'

export default class extends Controller {
  static targets = ['header']

  connect() {
    this.headroom = new Headroom(this.element, {
      offset: 200,
      onNotTop: () => {
        if (this.element.classList.contains('header-logo-centered'))
          this.element
            .querySelector('body:not(.inside-page-builder) .header-nav-container #header-logo')
            ?.classList?.add('lg:sr-only')
      },
      onTop: () => {
        if (this.element.classList.contains('header-logo-centered'))
          this.element
            .querySelector('body:not(.inside-page-builder) .header-nav-container #header-logo')
            ?.classList?.remove('lg:sr-only')
      }
    })
    this.headroom.init()
  }

  freeze() {
    this.headroom.freeze()
  }

  unfreeze() {
    this.headroom.unfreeze()
  }
}

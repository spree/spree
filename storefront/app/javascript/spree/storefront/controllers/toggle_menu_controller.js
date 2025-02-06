import { Toggle } from 'tailwindcss-stimulus-components'
import { lockScroll, unlockScroll } from 'spree/core/helpers/scroll_lock'

export default class ToggleMenu extends Toggle {
  static targets = ['toggleable', 'content', 'button']
  static values = ['open']

  connect() {
    super.connect()
  }

  hide(e) {
    if (this.openValue) {
      super.hide(e)
      this.buttonTarget.classList.remove('menu-open')
    }
  }

  toggle(e) {
    this.contentTarget.style.paddingBottom = `${this.contentTarget.offsetTop}px`
    super.toggle(e)
    if (this.openValue) {
      this.buttonTarget.classList.add('menu-open')
      setTimeout(() => {
        lockScroll()
      }, 0)
    } else {
      this.buttonTarget.classList.remove('menu-open')
      unlockScroll()
    }
  }
}

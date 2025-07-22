import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['stickyButton', 'fixedButton']

  connect() {
    if (!this.hasFixedButtonTarget) return

    this.handleScroll()

    const header = document.querySelector('header.sticky')

    this.navHeight = header ? header.offsetHeight : 0
    window.addEventListener('scroll', this.handleScroll, true)
  }

  disconnect() {
    window.removeEventListener('scroll', this.handleScroll)
  }

  handleScroll = () => {
    const button = this.stickyButtonTarget
    const top = button.getBoundingClientRect().top
    const fixedButton = this.fixedButtonTarget

    if (top < this.navHeight || top > window.innerHeight) {
      fixedButton.classList.remove('hidden')
    } else {
      fixedButton.classList.add('hidden')
    }
  }
}

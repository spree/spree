import { Controller } from 'stimulus'
import { useHover } from 'stimulus-use'

export default class extends Controller {
  static targets = [ 'menu' ]

  get menu() {
    return this.menuTarget
  }

  connect() {
    useHover(this, { element: this.element })
  }

  mouseEnter() {
    this.menu.classList.add('show')
  }

  mouseLeave() {
    this.menu.classList.remove('show')
  }
}

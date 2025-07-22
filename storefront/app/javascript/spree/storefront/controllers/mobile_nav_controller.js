import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['submenuContainer']

  openSubmenu(e) {
    const template = e.target.querySelector('template')
    if (template) {
      this.submenuContainerTarget.innerHTML = template.innerHTML
      this.element.style.setProperty('--tw-translate-x', '-100vw')
    }
  }

  closeSubmenu() {
    this.element.style.setProperty('--tw-translate-x', null)
  }
}

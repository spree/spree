import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['close', 'save']

  close() {
    if (this.hasCloseTarget) {
      window.Turbo.visit(this.closeTarget.href)
    }
  }

  save(event) {
    if (this.hasSaveTarget) {
      event.preventDefault()
      this.saveTarget.click()
    }
  }
}
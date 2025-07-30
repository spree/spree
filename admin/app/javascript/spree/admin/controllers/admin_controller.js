import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['close', 'save']

  close(event) {
    // https://github.com/hotwired/stimulus/issues/743
    if (event.type == "keydown" && !(event instanceof KeyboardEvent)) return

    if (this.hasCloseTarget) {
      window.Turbo.visit(this.closeTarget.href)
    }
  }

  save(event) {
    // https://github.com/hotwired/stimulus/issues/743
    if (event.type == "keydown" && !(event instanceof KeyboardEvent)) return

    if (this.hasSaveTarget) {
      event.preventDefault()
      this.saveTarget.click()
    }
  }
}
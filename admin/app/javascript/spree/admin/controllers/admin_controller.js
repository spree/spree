import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['close', 'save']

  handle(event) {
    if (!this.isValidEvent(event)) return

    const action = event.params?.action
    if (action === 'close') this.visitTarget(this.closeTarget)
    else if (action === 'save') this.clickTarget(this.saveTarget, event)
  }

  // --- helpers ---

  isValidEvent(event) {
    // Fix for Stimulus bug: ignore synthetic keydown events
    return !(event.type === 'keydown' && !(event instanceof KeyboardEvent))
  }

  visitTarget(target) {
    if (target) window.Turbo.visit(target.href)
  }

  clickTarget(target, event) {
    if (target) {
      event.preventDefault()
      target.click()
    }
  }
}

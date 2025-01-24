import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['eventsCheckboxesContainer', 'subscribeToAll']

  hideCheckboxes() {
    this.eventsCheckboxesContainerTarget.classList.add('d-none')
  }

  showCheckboxes() {
    this.eventsCheckboxesContainerTarget.classList.remove('d-none')
  }

  initialize() {
    if (this.subscribeToAllTarget.checked) {
      this.hideCheckboxes()
    }
  }
}

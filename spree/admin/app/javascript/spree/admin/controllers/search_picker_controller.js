import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['checkbox', 'submit', 'search', 'results']

  toggle(event) {
    if (event.target.type == 'checkbox' || event.target.type == 'radio') {
      this.refresh()
    } else {
      const input =
        event.target.querySelector('input[type="checkbox"]') || event.target.querySelector('input[type="radio"]')
      if (input?.disabled) return

      switch (input?.type) {
        case 'checkbox':
          input.toggleAttribute('checked')
        case 'radio':
          if (input.disabled) break
          input.checked = true
      }
      this.refresh()
    }
  }

  refresh() {
    let checked = this.checkboxTargets.filter((checkbox) => checkbox.checked)
    if (checked.length > 0) {
      this.submitTarget.disabled = false
    } else {
      this.submitTarget.disabled = true
    }
  }

  closeAndClear() {
    this.searchTarget.value = ''
    this.resultsTarget.innerHTML = ''
  }
}

import { Controller } from '@hotwired/stimulus'

// Progressive disclosure for the API key form: scopes apply only to secret
// keys, channel binding only to publishable keys. Hidden sections get their
// inputs disabled so the irrelevant params are never submitted.
export default class extends Controller {
  static targets = ['typeSelect', 'section']

  connect() {
    this.toggle()
  }

  toggle() {
    const type = this.typeSelectTarget.value

    this.sectionTargets.forEach((section) => {
      const match = section.dataset.showWhenKeyType === type
      section.hidden = !match
      section.querySelectorAll('select, input').forEach((input) => {
        input.disabled = !match
      })
    })
  }
}

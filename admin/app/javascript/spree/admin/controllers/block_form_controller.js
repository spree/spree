import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['form', 'type']

  addBlock(event) {
    event.preventDefault()
    this.typeTarget.value = event.params.type
    this.formTarget.requestSubmit()
  }
}

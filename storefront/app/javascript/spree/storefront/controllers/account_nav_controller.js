import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  connect() {
    this.element.querySelector('[data-active=true]').scrollIntoView({
      block: 'nearest',
      inline: 'center'
    })
  }
}

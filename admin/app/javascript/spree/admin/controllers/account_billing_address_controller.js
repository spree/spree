import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = [
    'country',
    'state',
    'stateSelectContainer'
  ]

  connect() {
    super.connect()
    this.changeCountry()
  }

  changeCountry(_) {
    const countryIso = this.countryTarget.value

    if (countryIso == 'US') {
      this.stateSelectContainerTarget.classList.remove('hidden')
    } else {
      this.stateSelectContainerTarget.classList.add('hidden')
      this.stateTarget.value = ''
    }
  }
}

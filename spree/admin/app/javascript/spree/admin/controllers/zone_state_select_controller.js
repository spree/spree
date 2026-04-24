import { Controller } from "@hotwired/stimulus"
import { get } from '@rails/request.js'

export default class extends Controller {
  static values = {
    url: String
  }

  static targets = ["statesSelect"]

  async countryChanged(event) {
    const countryId = event.target.value
    const statesInput = this.statesSelectTarget.querySelector('select')
    if (!statesInput || !statesInput.tomselect) return

    const tomSelect = statesInput.tomselect
    tomSelect.clear()
    tomSelect.clearOptions()

    if (!countryId) return

    const url = this.urlValue.replace(':country_id', countryId)
    const response = await get(url, { contentType: 'application/json' })

    if (response.ok) {
      const states = await response.json
      states.forEach(state => tomSelect.addOption(state))
      tomSelect.refreshOptions(false)
    }
  }
}

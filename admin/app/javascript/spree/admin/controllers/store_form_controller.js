import { Controller } from '@hotwired/stimulus'
import countryCurrency from '../../helpers/country_currency'
export default class extends Controller {
  static targets = ['currency']

  updateCurrency(e) {
    const selectController = this.application.getControllerForElementAndIdentifier(
      this.currencyTarget,
      'autocomplete-select'
    )

    if (selectController?.select && countryCurrency[e.target.value]) {
      selectController.select.setValue(countryCurrency[e.target.value])
    }
  }
}

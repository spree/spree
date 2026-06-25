import { Controller } from '@hotwired/stimulus'
import { adminUiLocale, formatCodeName, intlDisplayName } from 'spree/admin/helpers/display_names'

// Upgrades a server-rendered label to Intl.DisplayNames in the admin UI language.
export default class extends Controller {
  static values = {
    type: String,
    code: String
  }

  connect() {
    const name = intlDisplayName(this.typeValue, this.codeValue, adminUiLocale())
    if (name) this.element.textContent = formatCodeName(this.codeValue, name)
  }
}

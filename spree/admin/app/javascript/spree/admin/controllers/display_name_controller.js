import { Controller } from '@hotwired/stimulus'
import { adminUiLocale, formatCodeName, intlDisplayName } from 'spree/admin/helpers/display_names'

/**
 * Upgrades a server-rendered code/name label to its `Intl.DisplayNames`
 * equivalent in the admin UI language once JS is available.
 */
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

import { Controller } from '@hotwired/stimulus'

/**
 * MoneyFieldController
 *
 * A Stimulus controller for locale-aware money/price input fields.
 * Handles formatting values for display in the user's locale format.
 *
 * Features:
 * - Displays amounts in the user's locale format (e.g., "1.234,56" for German, "1,234.56" for English)
 * - Supports optional currency symbol display
 *
 * Usage:
 *   <input type="text"
 *          data-controller="money-field"
 *          data-money-field-locale-value="de"
 *          data-money-field-decimal-separator-value=","
 *          data-money-field-thousands-separator-value="."
 *          inputmode="decimal">
 *
 * Values:
 *   - locale: The locale to use for formatting (e.g., "en", "de", "pl")
 *   - decimalSeparator: The decimal separator for the locale (e.g., "." for en, "," for de/pl)
 *   - thousandsSeparator: The thousands separator for the locale (e.g., "," for en, "." for de/pl)
 */
export default class extends Controller {
  static values = {
    locale: { type: String, default: 'en' },
    decimalSeparator: { type: String, default: '.' },
    thousandsSeparator: { type: String, default: ',' }
  }

  connect() {
    // Format the initial value for display
    this.formatForDisplay()
  }

  /**
   * Called on blur to format the value for display
   */
  format() {
    this.formatForDisplay()
  }

  /**
   * Formats the current value for display in the user's locale format
   */
  formatForDisplay() {
    const normalizedValue = this.normalizeValue(this.element.value)
    if (normalizedValue === '' || normalizedValue === null) {
      return
    }

    const number = parseFloat(normalizedValue)
    if (!Number.isFinite(number)) {
      return
    }

    this.element.value = this.formatNumber(number)
  }

  /**
   * Formats a number for display using the configured locale
   * @param {number} number - The number to format
   * @returns {string} The formatted number string
   */
  formatNumber(number) {
    return number.toLocaleString(this.localeValue, {
      minimumFractionDigits: 2,
      maximumFractionDigits: 2,
      useGrouping: false // Disable thousands separator for cleaner input
    })
  }

  /**
   * Normalizes the input value to standard decimal format (with "." as decimal separator)
   * Automatically detects the format based on the input pattern.
   * @param {string} value - The value to normalize
   * @returns {string} The normalized value
   */
  normalizeValue(value) {
    if (value === null || value === undefined) {
      return ''
    }

    let stringValue = String(value).trim()
    if (stringValue === '') {
      return ''
    }

    // Detect the decimal separator by finding the last separator character
    // This handles both "1,234.56" (en) and "1.234,56" (de/pl) formats
    const lastComma = stringValue.lastIndexOf(',')
    const lastDot = stringValue.lastIndexOf('.')

    let decimalSeparator = '.'
    let thousandsSeparator = ','

    // If comma comes after dot, comma is the decimal separator (European format)
    // Also treat comma as decimal if there's no dot and comma has 1-2 digits after it
    if (lastComma > lastDot) {
      decimalSeparator = ','
      thousandsSeparator = '.'
    } else if (lastDot === -1 && lastComma !== -1) {
      // No dot present, check if comma looks like a decimal separator
      // (has 1-3 digits after it, typical for currency)
      const afterComma = stringValue.substring(lastComma + 1)
      if (/^\d{1,3}$/.test(afterComma)) {
        decimalSeparator = ','
        thousandsSeparator = '.'
      }
    }

    // Remove thousands separators
    stringValue = stringValue.split(thousandsSeparator).join('')

    // Replace decimal separator with standard "."
    if (decimalSeparator !== '.') {
      stringValue = stringValue.replace(decimalSeparator, '.')
    }

    // Remove any non-numeric characters except "." and "-"
    stringValue = stringValue.replace(/[^0-9.\-]/g, '')

    return stringValue
  }

}

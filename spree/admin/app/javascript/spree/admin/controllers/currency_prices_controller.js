import { Controller } from '@hotwired/stimulus'

/**
 * Suggests prices in other store currencies using reference FX rates (ECB via Frankfurter).
 * Filled values remain editable. Only runs when data-currency-prices-url-value is set.
 */
export default class extends Controller {
  static values = {
    url: String,
    locale: { type: String, default: 'en' }
  }

  connect() {
    this._debounce = null
  }

  scheduleConvert(event) {
    if (!this.hasUrlValue || !this.urlValue) return

    clearTimeout(this._debounce)
    this._debounce = setTimeout(() => this.convertFrom(event.target), 400)
  }

  async convertFrom(sourceInput) {
    if (!(sourceInput instanceof HTMLInputElement) || sourceInput.disabled || sourceInput.readOnly) return
    if (!sourceInput.name?.includes('prices_attributes')) return

    const isAmount = sourceInput.name.includes('[amount]') && !sourceInput.name.includes('compare_at')
    const isCompare = sourceInput.name.includes('compare_at_amount')
    if (!isAmount && !isCompare) return

    const row = sourceInput.closest('tr')
    if (!row) return

    const fromCurrency = this.currencyFromRow(row)
    if (!fromCurrency) return

    const amount = this.parseNumber(sourceInput.value)
    if (!Number.isFinite(amount) || amount <= 0) return

    const targets = this.otherCurrenciesInTable(row, fromCurrency)
    if (targets.length === 0) return

    const url = `${this.urlValue}?${new URLSearchParams({
      amount: String(amount),
      from: fromCurrency,
      to: targets.join(',')
    })}`

    const token = document.querySelector('meta[name="csrf-token"]')?.getAttribute('content')
    const headers = { Accept: 'application/json', 'X-Requested-With': 'XMLHttpRequest' }
    if (token) headers['X-CSRF-Token'] = token

    let data
    try {
      const res = await fetch(url, { headers, credentials: 'same-origin' })
      if (!res.ok) return
      data = await res.json()
    } catch (_e) {
      return
    }

    const conversions = data.conversions || {}
    for (const [code, value] of Object.entries(conversions)) {
      const targetInput = this.findPriceInputInTable(sourceInput, row, code, isCompare)
      if (!targetInput || targetInput === sourceInput) continue
      targetInput.value = this.formatNumber(Number(value))
      targetInput.dispatchEvent(new Event('input', { bubbles: true }))
    }
  }

  currencyFromRow(row) {
    const cell = row.querySelector('td')
    return cell?.textContent?.trim() || null
  }

  otherCurrenciesInTable(sourceRow, fromCurrency) {
    const table = sourceRow.closest('table')
    if (!table) return []

    const codes = []
    table.querySelectorAll('tbody tr').forEach((tr) => {
      const c = this.currencyFromRow(tr)
      if (c && c !== fromCurrency) codes.push(c)
    })
    return [...new Set(codes)]
  }

  findPriceInputInTable(sourceInput, sourceRow, currencyCode, isCompare) {
    const table = sourceRow.closest('table')
    if (!table) return null

    for (const tr of table.querySelectorAll('tbody tr')) {
      if (this.currencyFromRow(tr) !== currencyCode) continue
      const cells = tr.querySelectorAll('td')
      const colIndex = isCompare ? 2 : 1
      const cell = cells[colIndex]
      return cell?.querySelector('input[type="text"], input:not([type])') || null
    }
    return null
  }

  parseNumber(value) {
    if (value === null || value === undefined) return NaN
    let str = String(value).trim()
    if (str === '') return NaN

    const lastComma = str.lastIndexOf(',')
    const lastDot = str.lastIndexOf('.')
    if (lastComma > lastDot) {
      str = str.replace(/\./g, '').replace(',', '.')
    } else if (lastDot === -1 && lastComma !== -1 && /^\d{1,3}$/.test(str.substring(lastComma + 1))) {
      str = str.replace(',', '.')
    }
    return parseFloat(str)
  }

  formatNumber(number) {
    if (!Number.isFinite(number)) return ''
    return number.toLocaleString(this.localeValue, {
      minimumFractionDigits: 2,
      maximumFractionDigits: 2,
      useGrouping: false
    })
  }
}

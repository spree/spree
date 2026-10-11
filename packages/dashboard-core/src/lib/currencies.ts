import type { CurrencyCode } from '@spree/admin-sdk'
import { isCurrencyCode } from './iso-codes'

/**
 * Every ISO 4217 currency code the runtime knows about — the active-currency
 * counterpart to the Rails admin's `Money::Currency.table` list. Used for
 * contexts where the merchant can pick *any* currency (a market's currency)
 * rather than one the store already supports. Degrades to an empty list on
 * runtimes without `Intl.supportedValuesOf`, so callers fall back to
 * `supported_currencies`.
 */
export const ALL_CURRENCY_CODES: CurrencyCode[] = (() => {
  try {
    return Intl.supportedValuesOf('currency').filter(isCurrencyCode)
  } catch {
    return []
  }
})()

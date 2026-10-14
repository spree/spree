import { CurrencyCode } from '@spree/admin-sdk'

/**
 * Every currency still in circulation that Spree accepts. Used for contexts
 * where the merchant can pick *any* currency (a market's currency) rather than
 * one the store already supports. Spree's list keeps retired currencies (EEK,
 * BYR) so old orders stay valid; the runtime's own list drops them, so a
 * merchant is not offered one for new pricing. Runtimes without
 * `Intl.supportedValuesOf` get Spree's full list.
 */
export const ALL_CURRENCY_CODES: readonly CurrencyCode[] = (() => {
  const all = Object.values(CurrencyCode)
  try {
    const current = new Set(Intl.supportedValuesOf('currency'))
    return all.filter((code) => current.has(code))
  } catch {
    return all
  }
})()

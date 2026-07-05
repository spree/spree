import { useAllMarkets } from './use-markets'

/**
 * Resolves a currency code to the locale used to display and normalize amounts
 * entered in it. Money forms format the field in this locale (so a EUR amount
 * shows/accepts `1.234,56`) and normalize the merchant's input to canonical
 * `"1234.56"` under the same locale before sending — the API only ever receives
 * canonical decimal strings (client-side normalization; the server does not
 * parse locale formats). See docs/plans/5.5-client-side-money-normalization.md.
 *
 * The mapping is the store's markets: each market pairs a `currency` with a
 * `default_locale`. Returns `undefined` when no market matches (callers fall
 * back to the UI language / `en`).
 *
 * @returns a `localeForCurrency(currency)` resolver
 */
export function useCurrencyLocale(): (currency: string | undefined) => string | undefined {
  const { markets } = useAllMarkets()

  return (currency) => {
    if (!currency) return undefined
    const market = markets.find((m) => m.currency === currency)
    return market?.default_locale ?? undefined
  }
}

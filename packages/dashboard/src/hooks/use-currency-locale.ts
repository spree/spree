import { useAllMarkets } from './use-markets'

/**
 * Resolves a currency code to the locale that should parse amounts entered in
 * it. Monetary amounts are parsed server-side by `LocalizedNumber.parse` under
 * the request locale, so an amount typed in a comma-decimal currency (e.g. EUR
 * → `de`/`fr`) must travel with that market's locale or `1.234,56` is mangled.
 *
 * The mapping is the store's markets: each market pairs a `currency` with a
 * `default_locale`. Returns `undefined` when no market matches (the caller then
 * omits the override and the server falls back to its default locale).
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

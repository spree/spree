import { CountryCode, CurrencyCode, LocaleCode } from './iso-codes.generated'

export { CountryCode, CurrencyCode, LocaleCode }

// Built on first use, so a bundle that never checks a code can drop the lists.
const lookups = new Map<object, ReadonlySet<unknown>>()

function listed(list: Record<string, string>, value: unknown): boolean {
  let codes = lookups.get(list)
  if (!codes) {
    codes = new Set(Object.values(list))
    lookups.set(list, codes)
  }
  return codes.has(value)
}

/** Whether a value is a country code Spree accepts (`'US'`, `'DE'`). */
export function isCountryCode(value: unknown): value is CountryCode {
  return listed(CountryCode, value)
}

/** Whether a value is a currency code Spree accepts (`'USD'`, `'EUR'`). */
export function isCurrencyCode(value: unknown): value is CurrencyCode {
  return listed(CurrencyCode, value)
}

/** Whether a value is a locale code Spree accepts (`'en'`, `'pt-BR'`). */
export function isLocaleCode(value: unknown): value is LocaleCode {
  return listed(LocaleCode, value)
}

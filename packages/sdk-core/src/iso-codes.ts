import { CountryCode, CurrencyCode, LocaleCode } from './iso-codes.generated'

export { CountryCode, CurrencyCode, LocaleCode }

const COUNTRY_CODES: ReadonlySet<unknown> = new Set(Object.values(CountryCode))
const CURRENCY_CODES: ReadonlySet<unknown> = new Set(Object.values(CurrencyCode))
const LOCALE_CODES: ReadonlySet<unknown> = new Set(Object.values(LocaleCode))

/** Whether a value is a country code Spree accepts (`'US'`, `'DE'`). */
export function isCountryCode(value: unknown): value is CountryCode {
  return COUNTRY_CODES.has(value)
}

/** Whether a value is a currency code Spree accepts (`'USD'`, `'EUR'`). */
export function isCurrencyCode(value: unknown): value is CurrencyCode {
  return CURRENCY_CODES.has(value)
}

/** Whether a value is a locale code Spree accepts (`'en'`, `'pt-BR'`). */
export function isLocaleCode(value: unknown): value is LocaleCode {
  return LOCALE_CODES.has(value)
}

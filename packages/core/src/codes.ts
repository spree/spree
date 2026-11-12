import { type CountryCode, CurrencyCode, type LocaleCode } from './code-lists.generated'

/**
 * Whether a value has the shape of an ISO 3166-1 alpha-2 country code.
 *
 * Shape only: the connected server holds the authoritative list and rejects a
 * code it does not know, while `CountryCode` is fixed when this package is
 * built. Checking against that copy would hide or reject a code an older or
 * newer server accepts.
 */
export function isCountryCode(value: unknown): value is CountryCode {
  return typeof value === 'string' && /^[A-Z]{2}$/.test(value)
}

/** Whether a value has the shape of an ISO 4217 currency code. See `isCountryCode`. */
export function isCurrencyCode(value: unknown): value is CurrencyCode {
  return typeof value === 'string' && /^[A-Z]{3}$/.test(value)
}

/**
 * Whether a value has the shape of a locale code: an ISO 639-1 language,
 * optionally with a region (`en`, `pt-BR`, `es-419`). See `isCountryCode`.
 */
export function isLocaleCode(value: unknown): value is LocaleCode {
  return typeof value === 'string' && /^[a-z]{2,3}(-[A-Z0-9]{2,3})?$/.test(value)
}

/**
 * Replaced currencies Spree still accepts, so amounts recorded in them stay
 * valid, but which nobody should pick for new prices.
 */
export const RETIRED_CURRENCY_CODES: ReadonlySet<CurrencyCode> = new Set<CurrencyCode>([
  'BYR',
  'CUC',
  'EEK',
  'HRK',
  'LTL',
  'LVL',
  'MRO',
  'MTL',
  'SKK',
  'SLL',
  'STD',
  'TMM',
  'VEF',
  'ZMK',
  'ZWD',
  'ZWL',
  'ZWN',
  'ZWR',
])

/** Every currency Spree accepts that is still in use, for a picker offering any currency. */
export const ACTIVE_CURRENCY_CODES: readonly CurrencyCode[] = Object.values(CurrencyCode).filter(
  (code) => !RETIRED_CURRENCY_CODES.has(code),
)

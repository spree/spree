import type { CountryCode, CurrencyCode, LocaleCode } from '@spree/admin-sdk'
import i18n from 'i18next'
import { z } from 'zod/v4'

/**
 * Whether a value has the shape of an ISO 3166-1 alpha-2 country code.
 *
 * Shape only: the server holds the authoritative list and rejects a code it
 * does not know, so the dashboard does not ship a second copy of it. This is
 * the one place a plain string becomes a `CountryCode`.
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
 * A required country field. A form that allows leaving it blank widens it
 * with `.or(z.literal(''))` and sends `value || null` (or `|| undefined`).
 */
export const countryCodeSchema = z.custom<CountryCode>(isCountryCode, {
  error: () => i18n.t('admin.validation.country_required'),
})

/** A required currency field. See `countryCodeSchema`. */
export const currencyCodeSchema = z.custom<CurrencyCode>(isCurrencyCode, {
  error: () => i18n.t('admin.validation.currency_required'),
})

/** A required locale field. See `countryCodeSchema`. */
export const localeCodeSchema = z.custom<LocaleCode>(isLocaleCode, {
  error: () => i18n.t('admin.validation.locale_required'),
})

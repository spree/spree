import {
  type CountryCode,
  type CurrencyCode,
  isCountryCode,
  isCurrencyCode,
  isLocaleCode,
  type LocaleCode,
} from '@spree/core'
import i18n from 'i18next'
import { z } from 'zod/v4'

export { isCountryCode, isCurrencyCode, isLocaleCode }

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

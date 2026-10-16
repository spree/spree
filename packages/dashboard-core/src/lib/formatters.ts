import { formatMoney, type Price } from '@spree/admin-sdk'
import { parseISO } from 'date-fns'
import { formatInTimeZone } from 'date-fns-tz'
import i18n from 'i18next'

export { formatMoney }

/**
 * A price's amount in its currency, in the admin's own number format. A unit
 * price keeps a fraction of a cent. `display_amount` is accepted and ignored
 * so callers built against the old shape keep compiling.
 */
export function formatPrice(
  price: (Pick<Price, 'amount' | 'currency'> & { display_amount?: string | null }) | null,
  locale: string = i18n.language || 'en',
) {
  if (!price?.amount || !price.currency) return '—'
  return formatMoney(price.amount, price.currency, locale, { unitPrice: true })
}

/**
 * Formats an API amount (a decimal string) in its currency, falling back to
 * the bare number for a currency `Intl` does not know, and to `fallback` when
 * either is missing.
 */
export function formatAmount(
  amount: string | null | undefined,
  currency: string | null | undefined,
  locale?: string,
  fallback = '—',
): string {
  if (amount === null || amount === undefined || amount === '' || !currency) return fallback
  try {
    return formatMoney(amount, currency, locale) || fallback
  } catch {
    return `${amount} ${currency}`
  }
}

export function formatStoreDateTime(iso: string, timezone: string) {
  return formatInTimeZone(parseISO(iso), timezone, 'PPP p')
}

export function formatStoreDate(iso: string, timezone: string) {
  return formatInTimeZone(parseISO(iso), timezone, 'PP')
}

export function getInitials(fullName: string | null | undefined, fallback: string): string {
  const parts = (fullName ?? '').trim().split(/\s+/).filter(Boolean)
  if (parts.length === 0) return fallback.charAt(0)
  if (parts.length === 1) return parts[0].charAt(0)
  return parts[0].charAt(0) + parts[parts.length - 1].charAt(0)
}

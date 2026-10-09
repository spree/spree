import type { Price } from '@spree/admin-sdk'
import { parseISO } from 'date-fns'
import { formatInTimeZone } from 'date-fns-tz'

export function formatPrice(price: Pick<Price, 'amount' | 'currency' | 'display_amount'> | null) {
  if (!price) return '—'
  return price.display_amount ?? `${price.currency} ${price.amount}`
}

/**
 * Formats a decimal-string amount ("1234.50") in a currency and locale. The
 * string goes to `Intl` as it is — `Intl` reads numeric strings exactly — so
 * the amount never passes through a JavaScript number.
 */
export function formatMoney(amount: string, currency: string, locale?: string): string {
  // ES2023's Intl typings accept a numeric string; this package targets ES2022.
  return new Intl.NumberFormat(locale, { style: 'currency', currency }).format(
    amount as unknown as number,
  )
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

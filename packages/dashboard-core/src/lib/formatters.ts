import type { Price } from '@spree/admin-sdk'
import { parseISO } from 'date-fns'
import { formatInTimeZone } from 'date-fns-tz'

export function formatPrice(price: Pick<Price, 'amount' | 'currency' | 'display_amount'> | null) {
  if (!price) return '—'
  return price.display_amount ?? `${price.currency} ${price.amount}`
}

export function formatStoreDateTime(iso: string, timezone: string) {
  return formatInTimeZone(parseISO(iso), timezone, 'PPP p')
}

export function getInitials(fullName: string | null | undefined, fallback: string): string {
  const parts = (fullName ?? '').trim().split(/\s+/).filter(Boolean)
  if (parts.length === 0) return fallback.charAt(0)
  if (parts.length === 1) return parts[0].charAt(0)
  return parts[0].charAt(0) + parts[parts.length - 1].charAt(0)
}

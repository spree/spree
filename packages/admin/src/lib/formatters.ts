import type { Price } from '@spree/admin-sdk'

export function formatPrice(price: Pick<Price, 'amount' | 'currency' | 'display_amount'> | null) {
  if (!price) return '—'
  return price.display_amount ?? `${price.currency} ${price.amount}`
}

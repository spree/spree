/**
 * How an erased customer reads on screen.
 *
 * Erasure replaces the name with a placeholder and the address with a random
 * one at an unroutable domain, because the row has to stay valid and unique
 * while carrying nothing about the person. Those values are for the database,
 * not for anyone reading a page: shown as-is they say "Redacted Redacted" and
 * a meaningless address, which reads as corrupted data rather than as a
 * request somebody made and the shop honoured.
 *
 * The record itself stays reachable — orders, totals and the erasure date are
 * exactly what someone comes to this page to confirm.
 */

/** A field that erasure overwrote, shown as absent rather than as its placeholder. */
export function erasedFieldValue(
  value: string | null | undefined,
  anonymized: boolean | null | undefined,
  placeholder = '—',
): string {
  if (anonymized) return placeholder
  return value?.trim() || placeholder
}

/**
 * What to call an erased customer. Their own name is gone, so the page is
 * titled by what happened to them instead of by a placeholder.
 */
export function customerDisplayName(
  customer: {
    full_name?: string | null
    first_name?: string | null
    last_name?: string | null
    email?: string | null
    anonymized?: boolean | null
  },
  erasedLabel: string,
): string {
  if (customer.anonymized) return erasedLabel

  const name =
    customer.full_name?.trim() ||
    [customer.first_name, customer.last_name].filter(Boolean).join(' ').trim()

  return name || customer.email?.trim() || '—'
}

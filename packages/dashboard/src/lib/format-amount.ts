import { formatMoney } from '@spree/dashboard-core'

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

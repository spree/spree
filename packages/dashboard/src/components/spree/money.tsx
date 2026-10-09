import { useMoneyLocale, useStore } from '@spree/dashboard-core'
import { formatAmount } from '../../lib/format-amount'

/**
 * An API amount shown in the admin's own number format. Without a currency it
 * is shown in the store's default currency, for figures the API states in it
 * (a customer's total spent).
 */
export function Money({
  amount,
  currency,
  fallback,
}: {
  amount: string | null | undefined
  currency?: string | null
  fallback?: string
}) {
  const locale = useMoneyLocale()
  const { defaultCurrency } = useStore()
  return <>{formatAmount(amount, currency ?? defaultCurrency, locale, fallback)}</>
}

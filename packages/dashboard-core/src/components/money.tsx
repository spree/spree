import { formatAmount } from '../lib/formatters'
import { useMoneyLocale } from '../products/use-money-locale'
import { useOptionalStore } from '../providers/store-provider'

/**
 * An API amount shown in the admin's own number format. Without a currency it
 * is shown in the store's default currency, for figures the API states in it
 * (a customer's total spent); the seller panel, which mounts no store, always
 * passes one.
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
  const store = useOptionalStore()
  return <>{formatAmount(amount, currency ?? store?.defaultCurrency, locale, fallback)}</>
}

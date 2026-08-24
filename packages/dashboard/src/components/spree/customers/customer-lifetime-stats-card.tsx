import type { Customer } from '@spree/admin-sdk'
import { useStore } from '@spree/dashboard-core'
import { Card, CardContent, RelativeTime } from '@spree/dashboard-ui'
import type { ReactNode } from 'react'
import { useTranslation } from 'react-i18next'
import { useCurrencyLocale } from '../../../hooks/use-currency-locale'
import { formatAmount } from '../../../lib/delivery-method-summary'

export function CustomerLifetimeStatsCard({ customer }: { customer: Customer }) {
  const { t, i18n } = useTranslation()
  const { defaultCurrency } = useStore()
  const localeForCurrency = useCurrencyLocale()
  const orders = customer.orders_count ?? 0
  const totalSpent = Number(customer.total_spent ?? '0')
  // Format the average from the number rather than rewriting the digits inside
  // `display_total_spent`: that string is already localized, so substituting a
  // period-decimal figure into it mixes separators (`1.234,56 €` → `1234.57 €`).
  const aovDisplay =
    orders > 0 && totalSpent > 0
      ? formatAmount(
          totalSpent / orders,
          defaultCurrency,
          localeForCurrency(defaultCurrency) || i18n.language,
        )
      : '—'

  return (
    <Card>
      <CardContent className="grid grid-cols-2 lg:grid-cols-5 gap-6 py-6">
        <Stat
          label={t('admin.pages.customers.detail.stat_total_spent')}
          value={customer.display_total_spent ?? '—'}
        />
        <Stat label={t('admin.pages.customers.detail.stat_orders')} value={String(orders)} />
        <Stat label={t('admin.pages.customers.detail.stat_avg_order_value')} value={aovDisplay} />
        <Stat
          label={t('admin.pages.customers.detail.section_store_credit')}
          value={customer.display_available_store_credit_total ?? '—'}
        />
        <Stat
          label={t('admin.customers.detail.customer_since')}
          value={<RelativeTime iso={customer.created_at} />}
        />
      </CardContent>
    </Card>
  )
}

function Stat({ label, value }: { label: string; value: ReactNode }) {
  return (
    <div className="flex flex-col gap-1">
      <span className="text-sm text-muted-foreground">{label}</span>
      <span className="text-lg font-semibold">{value}</span>
    </div>
  )
}

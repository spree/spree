import type { Customer } from '@spree/admin-sdk'
import { prorateMoney } from '@spree/core'
import { formatAmount, isPositiveMoney, useMoneyLocale, useStore } from '@spree/dashboard-core'
import { RelativeTime, StatItem } from '@spree/dashboard-ui'
import { useTranslation } from 'react-i18next'

export function CustomerLifetimeStatsCard({ customer }: { customer: Customer }) {
  const { t } = useTranslation()
  const moneyLocale = useMoneyLocale()
  const { defaultCurrency } = useStore()
  const orders = customer.orders_count ?? 0
  const totalSpent = customer.total_spent
  const aovDisplay =
    orders > 0 && isPositiveMoney(totalSpent)
      ? formatAmount(
          prorateMoney(totalSpent, 1, orders, defaultCurrency),
          defaultCurrency,
          moneyLocale,
        )
      : '—'

  return (
    <div className="grid grid-cols-2 gap-3 lg:grid-cols-5">
      <StatItem
        label={t('admin.pages.customers.detail.stat_total_spent')}
        value={formatAmount(totalSpent, defaultCurrency, moneyLocale)}
      />
      <StatItem label={t('admin.pages.customers.detail.stat_orders')} value={String(orders)} />
      <StatItem label={t('admin.pages.customers.detail.stat_avg_order_value')} value={aovDisplay} />
      <StatItem
        label={t('admin.pages.customers.detail.section_store_credit')}
        value={formatAmount(customer.available_store_credit_total, defaultCurrency, moneyLocale)}
      />
      <StatItem
        label={t('admin.customers.detail.customer_since')}
        value={<RelativeTime iso={customer.created_at} />}
      />
    </div>
  )
}

import { type Customer, decimalPlaces } from '@spree/admin-sdk'
import { formatAmount, isPositiveMoney, useMoneyLocale, useStore } from '@spree/dashboard-core'
import { Item, ItemContent, ItemDescription, ItemTitle, RelativeTime } from '@spree/dashboard-ui'
import type { ReactNode } from 'react'
import { useTranslation } from 'react-i18next'

export function CustomerLifetimeStatsCard({ customer }: { customer: Customer }) {
  const { t } = useTranslation()
  const moneyLocale = useMoneyLocale()
  const { defaultCurrency } = useStore()
  const orders = customer.orders_count ?? 0
  const totalSpent = customer.total_spent
  // Dividing needs a number; the average is only displayed, never sent or compared.
  const averageForDisplay =
    orders > 0 && isPositiveMoney(totalSpent)
      ? (Number(totalSpent) / orders).toFixed(decimalPlaces(defaultCurrency))
      : null
  const aovDisplay =
    averageForDisplay === null ? '—' : formatAmount(averageForDisplay, defaultCurrency, moneyLocale)

  return (
    <div className="grid grid-cols-2 gap-3 lg:grid-cols-5">
      <Stat
        label={t('admin.pages.customers.detail.stat_total_spent')}
        value={formatAmount(totalSpent, defaultCurrency, moneyLocale)}
      />
      <Stat label={t('admin.pages.customers.detail.stat_orders')} value={String(orders)} />
      <Stat label={t('admin.pages.customers.detail.stat_avg_order_value')} value={aovDisplay} />
      <Stat
        label={t('admin.pages.customers.detail.section_store_credit')}
        value={formatAmount(customer.available_store_credit_total, defaultCurrency, moneyLocale)}
      />
      <Stat
        label={t('admin.customers.detail.customer_since')}
        value={<RelativeTime iso={customer.created_at} />}
      />
    </div>
  )
}

function Stat({ label, value }: { label: string; value: ReactNode }) {
  return (
    <Item variant="outline" className="rounded-xl border-border-card bg-card px-4 py-3 shadow-xs">
      <ItemContent>
        <ItemDescription>{label}</ItemDescription>
        <ItemTitle className="text-lg font-semibold">{value}</ItemTitle>
      </ItemContent>
    </Item>
  )
}

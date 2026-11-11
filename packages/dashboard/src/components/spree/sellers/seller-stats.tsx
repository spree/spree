import type { Seller } from '@spree/admin-sdk'
import { Subject, usePermissions, useStore } from '@spree/dashboard-core'
import { StatItem } from '@spree/dashboard-ui'
import { Link } from '@tanstack/react-router'
import type { ReactNode } from 'react'
import { useTranslation } from 'react-i18next'
import { useReportingQuery } from '../../../hooks/use-reporting'
import { useSellerOrdersCount } from '../../../hooks/use-sellers'
import { GrowthBadge } from '../reporting/growth-badge'
import { sellerOrdersSearch } from './seller-orders-section'
import { sellerProductsSearch } from './seller-products-section'

/**
 * How the seller is doing and what waits on the operator. Sales are the last
 * 30 days against the 30 before; the counts are as of now and open the list
 * behind them.
 */
export function SellerStats({ seller }: { seller: Seller }) {
  const { t } = useTranslation()
  const { storeId } = useStore()
  const { permissions } = usePermissions()
  const canReadOrders = permissions.can('read', Subject.Order)
  const orders = useSellerOrdersCount(seller.id, false, canReadOrders)
  const toFulfill = useSellerOrdersCount(seller.id, true, canReadOrders)
  const inReview = seller.products_count_by_status.proposed

  return (
    <div className="grid grid-cols-2 gap-3 lg:grid-cols-5">
      <SalesStat
        sellerId={seller.id}
        metric="net_sales"
        label={t('admin.sellers.stats.net_sales')}
        enabled={canReadOrders}
      />
      <SalesStat
        sellerId={seller.id}
        metric="commission"
        label={t('admin.sellers.stats.commission')}
        enabled={permissions.can('read', Subject.CommissionLine)}
      />
      {canReadOrders && (
        <>
          <StatItem label={t('admin.nav.orders')} value={orders.data ?? '—'} />
          <StatItem
            label={t('admin.sellers.orders.to_fulfill')}
            value={
              <StatLink
                to="/$storeId/orders"
                params={{ storeId }}
                search={sellerOrdersSearch(seller.id, true)}
              >
                {toFulfill.data ?? '—'}
              </StatLink>
            }
          />
        </>
      )}
      <StatItem
        label={t('admin.pages.products.status_options.proposed')}
        value={
          <StatLink
            to="/$storeId/products"
            params={{ storeId }}
            search={sellerProductsSearch(seller.id, 'proposed')}
          >
            {inReview}
          </StatLink>
        }
      />
    </div>
  )
}

function SalesStat({
  sellerId,
  metric,
  label,
  enabled,
}: {
  sellerId: string
  metric: string
  label: string
  enabled: boolean
}) {
  const { data, error } = useReportingQuery(
    {
      metrics: [metric],
      compare: 'previous_period',
      time_range: { preset: 'last_30_days' },
      filters: [{ dimension: 'seller', op: 'eq', value: sellerId }],
    },
    { enabled },
  )

  // A role that cannot read the figure is not shown a dash for it.
  if (!enabled || error) return null

  const total = data?.totals[metric]

  return (
    <StatItem
      label={label}
      value={
        <span className="flex items-baseline gap-2">
          {total?.display ?? '—'}
          <GrowthBadge growth={total?.growth} />
        </span>
      }
    />
  )
}

function StatLink({
  children,
  to,
  params,
  search,
}: {
  children: ReactNode
  to: string
  params: { storeId: string }
  search: unknown
}) {
  return (
    <Link
      to={to as never}
      params={params as never}
      search={search as never}
      className="text-foreground no-underline hover:underline"
    >
      {children}
    </Link>
  )
}

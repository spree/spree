import { ExportButton, type ResourceSearch, ResourceTable } from '@spree/dashboard-core'
import { useRowClickBridge } from '@spree/dashboard-ui'
import type { Order } from '@spree/seller-sdk'
import { useNavigate, useParams } from '@tanstack/react-router'
import { useTranslation } from 'react-i18next'
import { sellerClient } from '../api-client'
import '../tables/orders'

/** What this seller has sold, newest first. */
export function OrdersPage({ search }: { search: ResourceSearch }) {
  const { t } = useTranslation()
  const { sellerId } = useParams({ from: '/_authenticated/$sellerId' })
  const navigate = useNavigate()

  useRowClickBridge('data-order-id', (orderId: string) =>
    navigate({ to: '/$sellerId/orders/$orderId', params: { sellerId, orderId } }),
  )

  return (
    <div className="flex flex-col gap-4">
      <h1 className="font-medium text-2xl">{t('orders.title')}</h1>

      <ResourceTable<Order>
        tableKey="seller-orders"
        queryKey="seller-orders"
        queryFn={(params) => sellerClient().orders.list(params)}
        searchParams={search}
        actions={(ctx) => <ExportButton type="orders" {...ctx} />}
      />
    </div>
  )
}

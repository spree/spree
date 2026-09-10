import { StatusBadge } from '@spree/dashboard-ui'
import { useTranslation } from 'react-i18next'

/**
 * A stock transfer's or purchase order's status.
 *
 * `received` gets an explicit success tone: the shared tone map reads that code
 * as a return awaiting a refund, which is amber, and a finished transfer is
 * not amber. `over_received` is finished too, but with more on the shelf than
 * was asked for — worth a look, so it stays amber.
 */
export function InventoryStatusBadge({
  status,
  resource,
}: {
  status: string
  resource: 'stock_transfers' | 'purchase_orders'
}) {
  const { t } = useTranslation()
  const tone =
    status === 'received' ? 'success' : status === 'over_received' ? 'warning' : undefined
  return (
    <StatusBadge status={status} label={t(`admin.${resource}.statuses.${status}`)} tone={tone} />
  )
}

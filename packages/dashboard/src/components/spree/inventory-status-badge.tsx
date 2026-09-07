import { StatusBadge } from '@spree/dashboard-ui'
import { useTranslation } from 'react-i18next'

/**
 * A stock transfer's or purchase order's status.
 *
 * `received` gets an explicit success tone: the shared tone map reads that code
 * as a return awaiting a refund, which is amber, and a finished transfer is
 * not amber.
 */
export function InventoryStatusBadge({
  status,
  resource,
}: {
  status: string
  resource: 'stock_transfers' | 'purchase_orders'
}) {
  const { t } = useTranslation()

  return (
    <StatusBadge
      status={status}
      label={t(`admin.${resource}.statuses.${status}`)}
      tone={status === 'received' ? 'success' : undefined}
    />
  )
}

import { adminClient, ResourceTable, resourceSearchSchema } from '@spree/dashboard-core'
import { createFileRoute } from '@tanstack/react-router'
import { useTranslation } from 'react-i18next'
import '../../../../tables/seller-ledger'

export const Route = createFileRoute('/_authenticated/$storeId/sellers/transfers')({
  validateSearch: resourceSearchSchema,
  component: SellerTransfersPage,
})

/**
 * What the marketplace's sellers have earned, order by order.
 *
 * Read-only, like the returns and exchanges lists: an earning is written when
 * an order is fulfilled and corrected by a reversal when it is refunded, so
 * there is nothing here to act on — what an operator acts on is the payout.
 */
function SellerTransfersPage() {
  const { t } = useTranslation()
  const searchParams = Route.useSearch()

  return (
    <ResourceTable
      tableKey="seller-transfers"
      queryKey="seller-transfers"
      queryFn={(params) => adminClient.sellerTransfers.list(params)}
      searchParams={searchParams}
      title={t('admin.nav.seller_transfers')}
    />
  )
}

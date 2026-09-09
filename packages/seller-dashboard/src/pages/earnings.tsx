import { PageHeader, type ResourceSearch, ResourceTable } from '@spree/dashboard-core'
import { Skeleton } from '@spree/dashboard-ui'
import type { Transfer } from '@spree/seller-sdk'
import { useTranslation } from 'react-i18next'
import { sellerClient } from '../api-client'
import { BalanceSummary } from '../components/finance/balance-summary'
import { useBalances } from '../hooks/use-ledger'
import '../tables/transfers'

/**
 * What this seller has earned: where they stand overall, then the sale-by-sale
 * rows behind it.
 *
 * Read-only. An earning is written when an order is fulfilled and corrected by
 * a reversal when it is refunded, so there is nothing here to edit.
 */
export function EarningsPage({ search }: { search: ResourceSearch }) {
  const { t } = useTranslation()
  const { data, isLoading } = useBalances()

  return (
    <div className="flex flex-col gap-4">
      <PageHeader title={t('earnings.title')} subtitle={t('earnings.subtitle')} />

      {isLoading ? (
        <Skeleton className="h-36 w-full" />
      ) : (
        <BalanceSummary balances={data?.data ?? []} />
      )}

      <ResourceTable<Transfer>
        tableKey="seller-transfers"
        queryKey="seller-transfers-list"
        queryFn={(params) => sellerClient().transfers.list(params)}
        searchParams={search}
      />
    </div>
  )
}

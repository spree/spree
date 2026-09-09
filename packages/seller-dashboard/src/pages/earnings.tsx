import { PageHeader, type ResourceSearch, ResourceTable } from '@spree/dashboard-core'
import { ErrorState, Skeleton } from '@spree/dashboard-ui'
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
  const { data, isLoading, isError, refetch } = useBalances()

  return (
    <div className="flex flex-col gap-4">
      <PageHeader title={t('earnings.title')} subtitle={t('earnings.subtitle')} />

      {/* A failed balance request must not fall through to the empty state:
          "you have earned nothing yet" is the opposite of "we could not ask". */}
      {isLoading ? (
        <Skeleton className="h-36 w-full" />
      ) : isError ? (
        <ErrorState title={t('earnings.balance.load_error')} onRetry={() => void refetch()} />
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

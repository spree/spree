import { PageHeader, type ResourceSearch, ResourceTable } from '@spree/dashboard-core'
import { useRowClickBridge } from '@spree/dashboard-ui'
import type { Payout } from '@spree/seller-sdk'
import { useNavigate, useParams } from '@tanstack/react-router'
import { useTranslation } from 'react-i18next'
import { sellerClient } from '../api-client'
import '../tables/payouts'

/** What the marketplace has sent this seller, and what is on its way. */
export function PayoutsPage({ search }: { search: ResourceSearch }) {
  const { t } = useTranslation()
  const { sellerId } = useParams({ from: '/_authenticated/$sellerId' })
  const navigate = useNavigate()

  useRowClickBridge('data-payout-id', (payoutId: string) =>
    navigate({ to: '/$sellerId/payouts/$payoutId', params: { sellerId, payoutId } }),
  )

  return (
    <div className="flex flex-col gap-4">
      <PageHeader title={t('payouts.title')} subtitle={t('payouts.subtitle')} />

      <ResourceTable<Payout>
        tableKey="seller-payouts"
        queryKey="seller-payouts-list"
        queryFn={(params) => sellerClient().payouts.list(params)}
        searchParams={search}
      />
    </div>
  )
}

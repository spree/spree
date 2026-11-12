import {
  formatAmount,
  PageHeader,
  type ResourceSearch,
  ResourceTable,
  useMoneyLocale,
} from '@spree/dashboard-core'
import { useRowClickBridge } from '@spree/dashboard-ui'
import type { Payout } from '@spree/seller-sdk'
import { useNavigate, useParams } from '@tanstack/react-router'
import { useTranslation } from 'react-i18next'
import { sellerClient } from '../api-client'
import { useProfile } from '../hooks/use-profile'
import '../tables/payouts'

/** What the marketplace has sent this seller, and what is on its way. */
export function PayoutsPage({ search }: { search: ResourceSearch }) {
  const { t } = useTranslation()
  const { sellerId } = useParams({ from: '/_authenticated/$sellerId' })
  const navigate = useNavigate()
  const { data: profile } = useProfile()
  const moneyLocale = useMoneyLocale()

  useRowClickBridge('data-payout-id', (payoutId: string) =>
    navigate({ to: '/$sellerId/payouts/$payoutId', params: { sellerId, payoutId } }),
  )

  return (
    <div className="flex flex-col gap-4">
      <PageHeader
        title={t('payouts.title')}
        subtitle={t('payouts.subtitle')}
        // The marketplace's terms, read-only: the seller API refuses to write them.
        description={
          profile &&
          [
            `${t('profile.payout_schedule')}: ${profile.payouts_schedule_interval ?? '—'}`,
            `${t('profile.minimum_payout')}: ${formatAmount(profile.minimum_payout_amount, profile.default_currency, moneyLocale)}`,
            t('profile.operator_managed'),
          ].join(' · ')
        }
      />

      <ResourceTable<Payout>
        hideHeader
        tableKey="seller-payouts"
        queryKey="seller-payouts-list"
        queryFn={(params) => sellerClient().payouts.list(params)}
        searchParams={search}
      />
    </div>
  )
}

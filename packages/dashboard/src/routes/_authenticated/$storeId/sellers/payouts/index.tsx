import type { SellerPayout } from '@spree/admin-sdk'
import {
  adminClient,
  ResourceTable,
  resourceSearchSchema,
  Subject,
  usePermissions,
} from '@spree/dashboard-core'
import { RowActions, useRowClickBridge } from '@spree/dashboard-ui'
import { CheckCircleIcon } from '@spree/dashboard-ui/icons'
import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { PayoutCompleteDialog } from '../../../../../components/spree/sellers/payout-complete-dialog'
import { OWED_PAYOUT_STATUSES } from '../../../../../hooks/use-seller-ledger'
import '../../../../../tables/seller-ledger'

export const Route = createFileRoute('/_authenticated/$storeId/sellers/payouts/')({
  validateSearch: resourceSearchSchema,
  component: SellerPayoutsPage,
})

/**
 * What the marketplace owes its sellers, and what it has sent.
 *
 * The queue an operator works through on payout day: the built-in provider
 * records a settlement and waits to be told the bank transfer went out.
 */
function SellerPayoutsPage() {
  const { t } = useTranslation()
  const searchParams = Route.useSearch()
  const { storeId } = Route.useParams()
  const navigate = useNavigate()
  const { permissions } = usePermissions()
  const [completing, setCompleting] = useState<SellerPayout | null>(null)

  const canComplete = permissions.can('update', Subject.SellerPayout)

  useRowClickBridge('data-payout-id', (payoutId: string) =>
    navigate({ to: '/$storeId/sellers/payouts/$payoutId', params: { storeId, payoutId } }),
  )

  return (
    <>
      <ResourceTable<SellerPayout>
        tableKey="seller-payouts"
        queryKey="seller-payouts"
        queryFn={(params) => adminClient.sellerPayouts.list(params)}
        searchParams={searchParams}
        title={t('admin.nav.seller_payouts')}
        rowActions={(payout) => (
          <RowActions
            actions={[
              {
                key: 'complete',
                label: t('admin.payouts.complete.action'),
                icon: <CheckCircleIcon className="size-4" />,
                visible: canComplete && OWED_PAYOUT_STATUSES.includes(payout.status),
                onSelect: () => setCompleting(payout),
              },
            ]}
          />
        )}
      />

      {completing && (
        <PayoutCompleteDialog
          payout={completing}
          open
          onOpenChange={(open) => !open && setCompleting(null)}
        />
      )}
    </>
  )
}

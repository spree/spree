import {
  adminClient,
  formatStoreDateTime,
  PageHeader,
  Subject,
  usePermissions,
  useStore,
} from '@spree/dashboard-core'
import {
  Button,
  Card,
  CardHeader,
  CardTitle,
  ErrorState,
  Pagination,
  ResourceLayout,
  Skeleton,
  StatusBadge,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@spree/dashboard-ui'
import { HandCoinsIcon } from '@spree/dashboard-ui/icons'
import { createFileRoute, Link } from '@tanstack/react-router'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { ResourceDetailSkeleton } from '../../../../../components/spree/route-pending'
import { PayoutCompleteDialog } from '../../../../../components/spree/sellers/payout-complete-dialog'
import { ReadRow } from '../../../../../components/spree/sellers/seller-read-row'
import { usePayout, useSellerTransfers } from '../../../../../hooks/use-seller-ledger'

const OWED = ['pending', 'processing', 'unresolved']

export const Route = createFileRoute('/_authenticated/$storeId/sellers/payouts/$payoutId')({
  component: PayoutDetailPage,
})

/**
 * One settlement, and the earnings it covers.
 *
 * The itemisation is what makes a payout auditable: it names exactly which
 * orders were settled, so a figure on a bank statement can be traced back to
 * the sales behind it.
 */
function PayoutDetailPage() {
  const { t } = useTranslation()
  const { payoutId } = Route.useParams()
  const { permissions } = usePermissions()
  const { timezone } = useStore()
  const [completing, setCompleting] = useState(false)
  const [page, setPage] = useState(1)

  const { data: payout, isLoading, error, refetch } = usePayout(payoutId)
  const {
    data: transfers,
    isPending: transfersPending,
    isError: transfersFailed,
  } = useSellerTransfers({ payout_id_eq: payoutId }, page)

  if (isLoading) return <ResourceDetailSkeleton />
  if (error || !payout) {
    return (
      <ErrorState
        title={t('admin.payouts.load_error')}
        error={error as Error | undefined}
        onRetry={() => refetch()}
      />
    )
  }

  const rows = transfers?.data ?? []
  const canComplete =
    permissions.can('update', Subject.SellerPayout) && OWED.includes(payout.status)

  return (
    <>
      <ResourceLayout
        header={
          <PageHeader
            title={payout.display_amount}
            subtitle={payout.seller_name ?? undefined}
            backTo="sellers/payouts"
            badges={
              <StatusBadge
                status={payout.status}
                label={t(`admin.payouts.statuses.${payout.status}`, {
                  defaultValue: payout.status,
                })}
              />
            }
            actions={
              canComplete ? (
                <Button onClick={() => setCompleting(true)}>
                  {t('admin.payouts.complete.action')}
                </Button>
              ) : null
            }
            resource={{ id: payout.id }}
            jsonPreview={{
              title: `Payout ${payout.id}`,
              fetch: () => adminClient.sellerPayouts.get(payout.id),
              endpoint: `/api/v3/admin/seller_payouts/${payout.id}`,
            }}
          />
        }
        main={
          <Card>
            <CardHeader>
              <CardTitle>
                <HandCoinsIcon className="size-4" />
                {/* The settlement's own count, not the rows this page
                    happened to load — the list is paged. */}
                {t('admin.payouts.detail.covers', { count: payout.transfers_count })}
              </CardTitle>
            </CardHeader>

            {/* Only true once the earnings loaded: a pending or failed query
                says nothing about what this settlement covers. */}
            {transfersPending ? (
              <div className="px-6 pb-6">
                <Skeleton className="h-16 w-full" />
              </div>
            ) : transfersFailed ? (
              <p className="px-6 pb-6 text-sm text-destructive">
                {t('admin.payouts.detail.covers_error')}
              </p>
            ) : rows.length === 0 ? (
              <p className="px-6 pb-6 text-sm text-muted-foreground">
                {t('admin.payouts.detail.covers_empty')}
              </p>
            ) : (
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>{t('admin.payouts.columns.date')}</TableHead>
                    <TableHead>{t('admin.payouts.columns.order')}</TableHead>
                    <TableHead>{t('admin.payouts.columns.kind')}</TableHead>
                    <TableHead className="text-right">{t('admin.fields.amount.label')}</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {rows.map((transfer) => (
                    <TableRow key={transfer.id}>
                      <TableCell>{formatStoreDateTime(transfer.created_at, timezone)}</TableCell>
                      <TableCell>
                        {transfer.order_id ? (
                          <Link
                            to={'/$storeId/orders/$orderId' as string}
                            params={{ orderId: transfer.order_id }}
                            className="no-underline"
                          >
                            {transfer.order_number ?? transfer.order_id}
                          </Link>
                        ) : (
                          '—'
                        )}
                      </TableCell>
                      <TableCell className="text-muted-foreground">
                        {t(`admin.payouts.kinds.${transfer.kind}`, {
                          defaultValue: transfer.kind,
                        })}
                      </TableCell>
                      <TableCell className="text-right tabular-nums">
                        {transfer.display_amount}
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            )}
            {transfers?.meta && transfers.meta.pages > 1 && (
              <Pagination meta={transfers.meta} onPageChange={setPage} />
            )}
          </Card>
        }
        sidebar={
          <Card>
            <CardHeader>
              <CardTitle>{t('admin.payouts.detail.settlement')}</CardTitle>
            </CardHeader>
            <div className="flex flex-col gap-3 px-6 pb-6">
              <ReadRow label={t('admin.fields.amount.label')}>{payout.display_amount}</ReadRow>
              <ReadRow label={t('admin.payouts.columns.reference')}>{payout.reference}</ReadRow>
              <ReadRow label={t('admin.payouts.columns.provider')}>{payout.provider}</ReadRow>
              <ReadRow label={t('admin.payouts.detail.period')}>
                {payout.period_start && payout.period_end
                  ? `${formatStoreDateTime(payout.period_start, timezone)} – ${formatStoreDateTime(payout.period_end, timezone)}`
                  : null}
              </ReadRow>
            </div>
          </Card>
        }
      />

      {completing && <PayoutCompleteDialog payout={payout} open onOpenChange={setCompleting} />}
    </>
  )
}

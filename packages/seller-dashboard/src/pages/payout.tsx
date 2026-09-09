import { formatStoreDateTime, PageHeader } from '@spree/dashboard-core'
import {
  Card,
  CardHeader,
  CardTitle,
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
import { Link, useParams } from '@tanstack/react-router'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { CenteredMessage } from '../components/centered-message'
import { ReadRow } from '../components/read-row'
import { RetryableError } from '../components/retryable-error'
import { usePayout, useTransfers } from '../hooks/use-ledger'
import { useStoreTimezone } from '../hooks/use-store-timezone'

/**
 * One settlement, and the earnings it covers.
 *
 * The itemisation is the point: a seller reconciling a deposit against their
 * own books needs to see which sales it paid for, not just a total.
 */
export function PayoutPage() {
  const { t } = useTranslation()
  const { sellerId, payoutId } = useParams({ from: '/_authenticated/$sellerId/payouts/$payoutId' })

  const timezone = useStoreTimezone()
  const [page, setPage] = useState(1)

  const { data: payout, isLoading, isError, refetch } = usePayout(payoutId)
  const {
    data: transfers,
    isPending: transfersPending,
    isError: transfersFailed,
  } = useTransfers({ payout_id_eq: payoutId }, page)

  if (isLoading) return <CenteredMessage>{t('common.loading')}</CenteredMessage>
  if (isError) return <RetryableError onRetry={() => refetch()} />
  if (!payout) return <CenteredMessage>{t('payouts.not_found')}</CenteredMessage>

  const rows = transfers?.data ?? []

  return (
    <ResourceLayout
      header={
        <PageHeader
          title={payout.display_amount}
          subtitle={formatStoreDateTime(payout.created_at, timezone)}
          backTo="payouts"
          badges={
            <StatusBadge
              status={payout.status}
              label={t(`earnings.statuses.${payout.status}`, { defaultValue: payout.status })}
            />
          }
          resource={{ id: payout.id }}
        />
      }
      main={
        <Card>
          <CardHeader>
            <CardTitle>
              <HandCoinsIcon className="size-4" />
              {/* The settlement's own count, not the rows this page happened
                  to load — the list is paged. */}
              {t('payouts.detail.covers', { count: payout.transfers_count })}
            </CardTitle>
          </CardHeader>

          {/* The empty line is only true once the earnings actually loaded —
              a pending or failed query says nothing about what this
              settlement covers. */}
          {transfersPending ? (
            <div className="px-6 pb-6">
              <Skeleton className="h-16 w-full" />
            </div>
          ) : transfersFailed ? (
            <p className="px-6 pb-6 text-sm text-destructive">{t('payouts.detail.covers_error')}</p>
          ) : rows.length === 0 ? (
            <p className="px-6 pb-6 text-sm text-muted-foreground">
              {t('payouts.detail.covers_empty')}
            </p>
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>{t('earnings.columns.date')}</TableHead>
                  <TableHead>{t('earnings.columns.order')}</TableHead>
                  <TableHead>{t('earnings.columns.kind')}</TableHead>
                  <TableHead className="text-right">{t('earnings.columns.amount')}</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {rows.map((transfer) => (
                  <TableRow key={transfer.id}>
                    <TableCell>{formatStoreDateTime(transfer.created_at, timezone)}</TableCell>
                    <TableCell>
                      {transfer.order_id ? (
                        <Link
                          to="/$sellerId/orders/$orderId"
                          params={{ sellerId, orderId: transfer.order_id }}
                          className="no-underline"
                        >
                          {transfer.order_number ?? transfer.order_id}
                        </Link>
                      ) : (
                        '—'
                      )}
                    </TableCell>
                    <TableCell className="text-muted-foreground">
                      {t(`earnings.kinds.${transfer.kind}`, { defaultValue: transfer.kind })}
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
            <CardTitle>{t('payouts.detail.settlement')}</CardTitle>
          </CardHeader>
          <div className="flex flex-col gap-3 px-6 pb-6">
            <ReadRow label={t('payouts.columns.amount')}>{payout.display_amount}</ReadRow>
            <ReadRow label={t('payouts.columns.reference')}>{payout.reference}</ReadRow>
            <ReadRow label={t('payouts.detail.period')}>
              {payout.period_start && payout.period_end
                ? `${formatStoreDateTime(payout.period_start, timezone)} – ${formatStoreDateTime(payout.period_end, timezone)}`
                : null}
            </ReadRow>
          </div>
        </Card>
      }
    />
  )
}

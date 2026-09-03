import type { Order } from '@spree/admin-sdk'
import { LocaleLabel, useStore } from '@spree/dashboard-core'
import { Card, CardHeader, CardTitle, cn, Separator } from '@spree/dashboard-ui'
import { Link } from '@tanstack/react-router'
import i18n from 'i18next'
import type { ReactNode } from 'react'
import { useTranslation } from 'react-i18next'
import { useOrderCommissionLines } from '../../../hooks/use-order'
import { commissionLineTotals } from '../../../lib/commission-line-totals'

function formatDate(iso: string | null) {
  if (!iso) return '—'
  return new Date(iso).toLocaleDateString(i18n.language, {
    month: 'short',
    day: 'numeric',
    year: 'numeric',
    hour: 'numeric',
    minute: '2-digit',
  })
}

function SummaryRow({
  label,
  value,
  bold,
  danger,
  highlight,
}: {
  label: string
  value: ReactNode
  bold?: boolean
  danger?: boolean
  highlight?: boolean
}) {
  return (
    <div
      className={cn('flex items-center justify-between px-5 py-2.5', highlight && 'bg-muted/50')}
    >
      <span className="text-sm">{label}</span>
      <span className={cn('text-sm', bold && 'font-bold', danger && 'text-destructive')}>
        {value}
      </span>
    </div>
  )
}

export function OrderSummaryCard({ order }: { order: Order }) {
  const { t } = useTranslation()
  const { storeId } = useStore()
  const outstandingBalance = Number.parseFloat(order.amount_due)
  const {
    data: commissionLinesData,
    isSuccess: commissionLinesLoaded,
    isError: commissionLinesError,
  } = useOrderCommissionLines(order.id, { enabled: !!order.completed_at })
  const commissionLines = commissionLinesData?.data ?? []
  const commissionTotals =
    commissionLinesLoaded && commissionLines.length > 0
      ? commissionLineTotals(commissionLines, order.currency)
      : null

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('admin.pages.orders.detail.section_summary')}</CardTitle>
      </CardHeader>
      <div className="py-1">
        {order.created_by && (
          <SummaryRow
            label={t('admin.pages.orders.detail.summary.created_by')}
            value={order.created_by.full_name || order.created_by.email}
          />
        )}
        <SummaryRow
          label={t('admin.fields.created_at.label')}
          value={formatDate(order.created_at)}
        />

        {order.completed_at && (
          <SummaryRow
            label={t('admin.fields.completed_at.label')}
            value={formatDate(order.completed_at)}
          />
        )}

        {/* Keyed on the status rather than the timestamp: resuming an order
            puts it back to placed but leaves the cancellation stamps as
            history, and that history should stop being reported as the order's
            current state.

            Set apart from the timestamps above: a cancellation is its own
            story — when, who, why — and four rows of it run together with the
            order's own dates otherwise. */}
        {order.status === 'canceled' && order.canceled_at && (
          <>
            <Separator />
            <SummaryRow
              label={t('admin.orders.detail.summary.canceled_at')}
              value={formatDate(order.canceled_at)}
            />
            {order.canceler && (
              <SummaryRow
                label={t('admin.orders.detail.summary.canceler')}
                value={order.canceler.full_name || order.canceler.email}
              />
            )}
            {order.cancel_reason_name && (
              <SummaryRow
                label={t('admin.orders.detail.summary.cancel_reason')}
                value={order.cancel_reason_name}
              />
            )}
            {order.cancel_note && (
              <SummaryRow
                label={t('admin.orders.detail.summary.cancel_note')}
                value={order.cancel_note}
              />
            )}
          </>
        )}

        {order.approved_at && order.approver && (
          <SummaryRow
            label={t('admin.orders.detail.summary.approved_by')}
            value={order.approver.full_name || order.approver.email}
          />
        )}

        <Separator />

        {order.channel && (
          <SummaryRow
            label={t('admin.pages.orders.detail.summary.channel')}
            value={
              <Link
                to="/$storeId/settings/channels"
                params={{ storeId }}
                search={{ edit: order.channel.id }}
                className="text-foreground hover:underline"
              >
                {order.channel.name}
              </Link>
            }
          />
        )}

        {order.market && (
          <SummaryRow
            label={t('admin.pages.orders.detail.summary.market')}
            value={
              <Link
                to="/$storeId/settings/markets"
                params={{ storeId }}
                search={{ edit: order.market.id }}
                className="text-foreground hover:underline"
              >
                {order.market.name}
              </Link>
            }
          />
        )}
        <SummaryRow
          label={t('admin.pages.orders.detail.summary.locale')}
          value={order.locale ? <LocaleLabel code={order.locale} /> : '—'}
        />
        <SummaryRow label={t('admin.fields.currency.label')} value={order.currency} />

        <Separator />

        <SummaryRow label={t('admin.fields.subtotal.label')} value={order.display_item_total} />

        {Number.parseFloat(order.delivery_total) > 0 && (
          <SummaryRow
            label={t('admin.fields.shipping.label')}
            value={order.display_delivery_total}
          />
        )}

        {Number.parseFloat(order.discount_total) !== 0 && (
          <SummaryRow
            label={t('admin.orders.detail.summary.promotions')}
            value={order.display_discount_total}
          />
        )}

        {Number.parseFloat(order.adjustment_total) !== 0 && (
          <SummaryRow
            label={t('admin.orders.detail.summary.adjustments')}
            value={order.display_adjustment_total}
          />
        )}

        {Number.parseFloat(order.included_tax_total) > 0 && (
          <SummaryRow
            label={t('admin.orders.detail.summary.tax_included')}
            value={order.display_included_tax_total}
          />
        )}

        {(Number.parseFloat(order.additional_tax_total) > 0 ||
          (Boolean(order.completed_at) && Number.parseFloat(order.included_tax_total) === 0)) && (
          <SummaryRow
            label={t('admin.orders.detail.summary.tax_additional')}
            value={order.display_additional_tax_total}
          />
        )}

        <Separator />

        <SummaryRow label={t('admin.fields.total.label')} value={order.display_total} bold />

        {commissionLinesError && (
          <>
            <Separator />
            <SummaryRow
              label={t('admin.orders.detail.summary.commission_total')}
              value={
                <span className="text-muted-foreground">{t('admin.errors.failed_to_load')}</span>
              }
            />
          </>
        )}

        {commissionTotals && (
          <>
            <Separator />
            <SummaryRow
              label={t('admin.orders.detail.summary.commission_fee')}
              value={commissionTotals.displayAmount}
            />
            {commissionTotals.tax > 0 && (
              <SummaryRow
                label={t('admin.orders.detail.summary.commission_tax')}
                value={commissionTotals.displayTax}
              />
            )}
            <SummaryRow
              label={t('admin.orders.detail.summary.commission_total')}
              value={commissionTotals.displayTotal}
              bold
            />
          </>
        )}

        <Separator />

        <SummaryRow
          label={t('admin.orders.detail.summary.payment_total')}
          value={order.display_payment_total}
          highlight
        />
        <SummaryRow
          label={t('admin.orders.detail.summary.outstanding_balance')}
          value={order.display_amount_due}
          highlight
          danger={outstandingBalance > 0}
        />
      </div>
    </Card>
  )
}

import type { Order } from '@spree/admin-sdk'
import { isZeroMoney } from '@spree/admin-sdk'
import { isPositiveMoney, LocaleLabel, useStore } from '@spree/dashboard-core'
import { Card, CardHeader, CardTitle, cn, Separator } from '@spree/dashboard-ui'
import { Link } from '@tanstack/react-router'
import i18n from 'i18next'
import type { ReactNode } from 'react'
import { useTranslation } from 'react-i18next'
import { ActorLabel } from '../actor-label'
import { Money } from '../money'

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
  const outstanding = isPositiveMoney(order.amount_due)
  // Read off the order rather than summed from its commission lines: the
  // figures are persisted columns, so the fee VAT the platform files and the
  // seller reclaims is the same number everywhere it is shown.
  const commissionTaxed = isPositiveMoney(order.commission_tax_total)
  // Keyed on the seller, not on the amount: a zero-rated or exempt rate still
  // writes commission lines, and the card below lists them, so hiding the
  // summary at zero would have the two panels disagree about the same order.
  // A first-party order has no seller and is never commissioned.
  const showCommission = !!order.completed_at && !!order.seller_id

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('admin.pages.orders.detail.section_summary')}</CardTitle>
      </CardHeader>
      <div className="py-1">
        {order.created_by && (
          <SummaryRow
            label={t('admin.pages.orders.detail.summary.created_by')}
            value={<ActorLabel actor={order.created_by} />}
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
                value={<ActorLabel actor={order.canceler} />}
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
            value={<ActorLabel actor={order.approver} />}
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

        <SummaryRow
          label={t('admin.fields.subtotal.label')}
          value={<Money amount={order.item_total} currency={order.currency} />}
        />

        {isPositiveMoney(order.delivery_total) && (
          <SummaryRow
            label={t('admin.fields.shipping.label')}
            value={<Money amount={order.delivery_total} currency={order.currency} />}
          />
        )}

        {!isZeroMoney(order.discount_total) && (
          <SummaryRow
            label={t('admin.orders.detail.summary.promotions')}
            value={<Money amount={order.discount_total} currency={order.currency} />}
          />
        )}

        {!isZeroMoney(order.adjustment_total) && (
          <SummaryRow
            label={t('admin.orders.detail.summary.adjustments')}
            value={<Money amount={order.adjustment_total} currency={order.currency} />}
          />
        )}

        {isPositiveMoney(order.included_tax_total) && (
          <SummaryRow
            label={t('admin.orders.detail.summary.tax_included')}
            value={<Money amount={order.included_tax_total} currency={order.currency} />}
          />
        )}

        {(isPositiveMoney(order.additional_tax_total) ||
          (Boolean(order.completed_at) && isZeroMoney(order.included_tax_total))) && (
          <SummaryRow
            label={t('admin.orders.detail.summary.tax_additional')}
            value={<Money amount={order.additional_tax_total} currency={order.currency} />}
          />
        )}

        <Separator />

        <SummaryRow
          label={t('admin.fields.total.label')}
          value={<Money amount={order.total} currency={order.currency} />}
          bold
        />

        {/* Labelled "marketplace fee" rather than a bare "fee": Spree::Fee is
            a buyer-facing charge (handling, gift wrap, COD) that rolls into
            the order total, while this is billed to the seller and does not.
            The two must never read alike in one summary. */}
        {showCommission && (
          <>
            <Separator />
            <SummaryRow
              label={t('admin.orders.detail.summary.commission_fee')}
              value={<Money amount={order.commission_amount_total} currency={order.currency} />}
            />
            {commissionTaxed && (
              <SummaryRow
                label={t('admin.orders.detail.summary.commission_tax')}
                value={<Money amount={order.commission_tax_total} currency={order.currency} />}
              />
            )}
            <SummaryRow
              label={t('admin.orders.detail.summary.commission_total')}
              value={<Money amount={order.commission_total} currency={order.currency} />}
              bold
            />
          </>
        )}

        <Separator />

        <SummaryRow
          label={t('admin.orders.detail.summary.payment_total')}
          value={<Money amount={order.payment_total} currency={order.currency} />}
          highlight
        />
        <SummaryRow
          label={t('admin.orders.detail.summary.outstanding_balance')}
          value={<Money amount={order.amount_due} currency={order.currency} />}
          highlight
          danger={outstanding}
        />
      </div>
    </Card>
  )
}

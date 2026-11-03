import type { Order, OrderChangePreview } from '@spree/admin-sdk'
import { compareMoney, isZeroMoney } from '@spree/core'
import { isPositiveMoney, Money } from '@spree/dashboard-core'
import { Card, CardContent, CardHeader, CardTitle, cn, Separator } from '@spree/dashboard-ui'
import type { ReactNode } from 'react'
import { useTranslation } from 'react-i18next'
import { type OrderEditItemValues, projectedSubtotal } from '../../../schemas/order'
import { MoneyChange } from './money-change'

function TotalRow({ label, value, bold }: { label: string; value: ReactNode; bold?: boolean }) {
  return (
    <div className="flex items-center justify-between px-4 py-2.5">
      <span className="text-base">{label}</span>
      <span className={cn('text-base', bold && 'font-bold')}>{value}</span>
    </div>
  )
}

/** The saved amount, and what it becomes when an edit moves it. */
function Amount({
  before,
  after,
  currency,
}: {
  before: string | null | undefined
  after: string | null | undefined
  currency: string
}) {
  if (after == null || before == null || compareMoney(after, before) === 0) {
    return <Money amount={before} currency={currency} />
  }

  return <MoneyChange before={before} after={after} currency={currency} />
}

/** The note under the totals: what the figures above can be trusted for. */
function totalsHint({
  previewError,
  previewPending,
  serverPreview,
  subtotalChanged,
  totalProjectable,
}: {
  previewError?: Error | null
  previewPending: boolean
  serverPreview: boolean
  subtotalChanged: boolean
  totalProjectable: boolean
}): [string, Record<string, string>?] {
  if (previewError)
    return ['admin.orders.edit.totals_preview_failed', { message: previewError.message }]
  if (previewPending) return ['admin.orders.edit.totals_preview_loading']
  if (serverPreview) return ['admin.orders.edit.totals_preview_server_hint']
  if (!subtotalChanged) return ['admin.orders.edit.totals_hint']
  if (totalProjectable) return ['admin.orders.edit.totals_preview_confirm_hint']
  return ['admin.orders.edit.totals_preview_hint']
}

/**
 * The order's totals, previewing staged edits.
 *
 * A placed order is previewed by the server (`preview`), so every line —
 * shipping, tax and promotions included — shows what the edit does to it,
 * along with how far the customer's balance moves. A draft has no server
 * preview: its subtotal is projected exactly (price × quantity), and its
 * grand total only when every other line is zero.
 */
export function OrderTotalsCard({
  order,
  items,
  preview,
  previewPending = false,
  previewError,
}: {
  order: Order
  items: OrderEditItemValues[]
  preview?: OrderChangePreview
  previewPending?: boolean
  previewError?: Error | null
}) {
  const { t } = useTranslation()
  const currency = order.currency

  const projected = preview ? null : projectedSubtotal(items)
  const subtotalChanged = projected !== null && compareMoney(projected, order.item_total) !== 0

  // Derived from the order's own totals, so charges not itemised here count.
  const totalProjectable = subtotalChanged && compareMoney(order.total, order.item_total) === 0

  const after = {
    item_total: preview?.item_total ?? (subtotalChanged ? projected : null),
    delivery_total: preview?.delivery_total,
    discount_total: preview?.discount_total,
    included_tax_total: preview?.included_tax_total,
    additional_tax_total: preview?.additional_tax_total,
    total: preview?.total ?? (totalProjectable ? projected : null),
  }

  const shows = (saved: string | null | undefined, next: string | null | undefined) =>
    isPositiveMoney(saved) || isPositiveMoney(next)

  const [hintKey, hintValues] = totalsHint({
    previewError,
    previewPending,
    serverPreview: Boolean(preview),
    subtotalChanged,
    totalProjectable,
  })
  // How far the customer's balance moves; shown only when it moves at all.
  const balanceDelta = preview && !isZeroMoney(preview.balance_delta) ? preview.balance_delta : null

  return (
    <Card className="gap-0">
      <CardHeader>
        <CardTitle>{t('admin.orders.edit.totals_title')}</CardTitle>
      </CardHeader>

      <div className={cn('py-2', previewPending && 'opacity-60')} aria-busy={previewPending}>
        <TotalRow
          label={t('admin.fields.subtotal.label')}
          value={<Amount before={order.item_total} after={after.item_total} currency={currency} />}
        />

        {shows(order.delivery_total, after.delivery_total) && (
          <TotalRow
            label={t('admin.fields.shipping.label')}
            value={
              <Amount
                before={order.delivery_total}
                after={after.delivery_total}
                currency={currency}
              />
            }
          />
        )}

        {(!isZeroMoney(order.discount_total) ||
          (after.discount_total != null && !isZeroMoney(after.discount_total))) && (
          <TotalRow
            label={t('admin.orders.detail.summary.promotions')}
            value={
              <Amount
                before={order.discount_total}
                after={after.discount_total}
                currency={currency}
              />
            }
          />
        )}

        {shows(order.included_tax_total, after.included_tax_total) && (
          <TotalRow
            label={t('admin.orders.detail.summary.tax_included')}
            value={
              <Amount
                before={order.included_tax_total}
                after={after.included_tax_total}
                currency={currency}
              />
            }
          />
        )}

        {(shows(order.additional_tax_total, after.additional_tax_total) ||
          (Boolean(order.completed_at) && isZeroMoney(order.included_tax_total))) && (
          <TotalRow
            label={t('admin.orders.detail.summary.tax_additional')}
            value={
              <Amount
                before={order.additional_tax_total}
                after={after.additional_tax_total}
                currency={currency}
              />
            }
          />
        )}

        <Separator />

        <TotalRow
          label={t('admin.fields.total.label')}
          value={<Amount before={order.total} after={after.total} currency={currency} />}
          bold
        />

        {balanceDelta && (
          <TotalRow
            label={t('admin.orders.edit.balance_change')}
            value={
              <span data-testid="order-balance-change">
                {isPositiveMoney(balanceDelta) && '+'}
                <Money amount={balanceDelta} currency={currency} />
              </span>
            }
          />
        )}
      </div>

      <Separator />

      <CardContent className="space-y-2 px-4 py-4">
        {balanceDelta && (
          <p className="text-xs font-medium">
            {isPositiveMoney(balanceDelta)
              ? t('admin.orders.edit.balance_owed_hint')
              : t('admin.orders.edit.balance_refund_hint')}
          </p>
        )}
        <p
          className={cn('text-xs text-muted-foreground', previewError && 'text-destructive')}
          role={previewError ? 'alert' : undefined}
        >
          {t(hintKey, hintValues)}
        </p>
      </CardContent>
    </Card>
  )
}

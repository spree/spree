import type { Order } from '@spree/admin-sdk'
import { compareMoney, isZeroMoney } from '@spree/core'
import { isPositiveMoney, Money } from '@spree/dashboard-core'
import { Card, CardContent, CardHeader, CardTitle, cn, Separator } from '@spree/dashboard-ui'
import type { ReactNode } from 'react'
import { useTranslation } from 'react-i18next'
import { type OrderEditItemValues, projectedSubtotal } from '../../../schemas/order'

function TotalRow({ label, value, bold }: { label: string; value: ReactNode; bold?: boolean }) {
  return (
    <div className="flex items-center justify-between px-4 py-2.5">
      <span className="text-sm">{label}</span>
      <span className={cn('text-sm', bold && 'font-bold')}>{value}</span>
    </div>
  )
}

/**
 * The order's totals, previewing staged edits. The subtotal is exact
 * (price × quantity); the grand total is only projected when every other line
 * is zero, since shipping, tax and promotions are recomputed server-side.
 */
export function OrderTotalsCard({ order, items }: { order: Order; items: OrderEditItemValues[] }) {
  const { t } = useTranslation()

  const projected = projectedSubtotal(items)
  const subtotalChanged = projected !== null && compareMoney(projected, order.item_total) !== 0

  // Derived from the order's own totals, so charges not itemised here count.
  const totalProjectable = subtotalChanged && compareMoney(order.total, order.item_total) === 0

  return (
    <Card className="gap-0">
      <CardHeader>
        <CardTitle>{t('admin.orders.edit.totals_title')}</CardTitle>
      </CardHeader>

      <div className="py-2">
        <TotalRow
          label={t('admin.fields.subtotal.label')}
          value={
            subtotalChanged ? (
              <span className="flex items-center justify-end gap-2">
                <span className="text-muted-foreground line-through">
                  <Money amount={order.item_total} currency={order.currency} />
                </span>
                <span className="font-medium">
                  <Money amount={projected} currency={order.currency} />
                </span>
              </span>
            ) : (
              <Money amount={order.item_total} currency={order.currency} />
            )
          }
        />

        {isPositiveMoney(order.delivery_total) && (
          <TotalRow
            label={t('admin.fields.shipping.label')}
            value={<Money amount={order.delivery_total} currency={order.currency} />}
          />
        )}

        {!isZeroMoney(order.discount_total) && (
          <TotalRow
            label={t('admin.orders.detail.summary.promotions')}
            value={<Money amount={order.discount_total} currency={order.currency} />}
          />
        )}

        {isPositiveMoney(order.included_tax_total) && (
          <TotalRow
            label={t('admin.orders.detail.summary.tax_included')}
            value={<Money amount={order.included_tax_total} currency={order.currency} />}
          />
        )}

        {(isPositiveMoney(order.additional_tax_total) ||
          (Boolean(order.completed_at) && isZeroMoney(order.included_tax_total))) && (
          <TotalRow
            label={t('admin.orders.detail.summary.tax_additional')}
            value={<Money amount={order.additional_tax_total} currency={order.currency} />}
          />
        )}

        <Separator />

        <TotalRow
          label={t('admin.fields.total.label')}
          value={
            totalProjectable ? (
              <span className="flex items-center justify-end gap-2">
                <span className="font-normal text-muted-foreground line-through">
                  <Money amount={order.total} currency={order.currency} />
                </span>
                <span>
                  <Money amount={projected} currency={order.currency} />
                </span>
              </span>
            ) : (
              <Money amount={order.total} currency={order.currency} />
            )
          }
          bold
        />
      </div>

      <Separator />

      <CardContent className="px-4 py-4">
        <p className="text-xs text-muted-foreground">
          {!subtotalChanged
            ? t('admin.orders.edit.totals_hint')
            : totalProjectable
              ? t('admin.orders.edit.totals_preview_confirm_hint')
              : t('admin.orders.edit.totals_preview_hint')}
        </p>
      </CardContent>
    </Card>
  )
}

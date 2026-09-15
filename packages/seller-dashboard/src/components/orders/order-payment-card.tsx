import {
  Card,
  CardAction,
  CardContent,
  CardHeader,
  CardTitle,
  Separator,
  StatusBadge,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@spree/dashboard-ui'
import { CreditCardIcon } from '@spree/dashboard-ui/icons'
import type { Order } from '@spree/seller-sdk'
import { useTranslation } from 'react-i18next'
import { ReadRow } from '../read-row'

/**
 * What the buyer paid for this order.
 *
 * On a marketplace the customer pays once for a basket that may span several
 * sellers, so what this order has is a share of that payment rather than a
 * payment of its own — the shares are what the table lists. How the buyer
 * paid, and to which gateway, is the marketplace's business and is not here.
 *
 * An order placed with this seller alone does not split, so it has no shares
 * and only the totals above are shown.
 */
export function OrderPaymentCard({ order }: { order: Order }) {
  const { t } = useTranslation()
  const splits = order.payment_splits ?? []

  return (
    <Card>
      <CardHeader>
        <CardTitle>
          <CreditCardIcon className="size-4" />
          {t('orders.payment.title')}
        </CardTitle>
        {order.payment_status && (
          <CardAction>
            <StatusBadge
              status={order.payment_status}
              label={t(`orders.payment_statuses.${order.payment_status}`, {
                defaultValue: order.payment_status,
              })}
            />
          </CardAction>
        )}
      </CardHeader>

      <CardContent className="flex flex-col gap-3">
        <ReadRow label={t('orders.summary.payment_total')}>{order.display_payment_total}</ReadRow>
        <ReadRow label={t('orders.summary.outstanding_balance')}>
          {order.display_amount_due}
        </ReadRow>
      </CardContent>

      {splits.length > 0 && (
        <>
          <Separator />
          <p className="px-6 pt-4 text-sm text-muted-foreground">
            {t('orders.payment.share_help')}
          </p>
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>{t('orders.payment.authorized')}</TableHead>
                <TableHead>{t('orders.payment.captured')}</TableHead>
                <TableHead>{t('orders.payment.refunded')}</TableHead>
                <TableHead className="text-right">{t('orders.payment.refundable')}</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {splits.map((split) => (
                <TableRow key={split.id}>
                  <TableCell className="tabular-nums">{split.display_authorized_amount}</TableCell>
                  <TableCell className="tabular-nums">{split.display_captured_amount}</TableCell>
                  <TableCell className="tabular-nums">{split.display_refunded_amount}</TableCell>
                  <TableCell className="text-right tabular-nums">
                    {split.display_refundable_amount}
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </>
      )}
    </Card>
  )
}

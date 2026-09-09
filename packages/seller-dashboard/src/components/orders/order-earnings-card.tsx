import {
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  StatusBadge,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@spree/dashboard-ui'
import { BanknoteIcon } from '@spree/dashboard-ui/icons'
import type { Order } from '@spree/seller-sdk'
import { Link, useParams } from '@tanstack/react-router'
import { useTranslation } from 'react-i18next'
import { useTransfers } from '../../hooks/use-ledger'

/**
 * What this order earned the seller: the sale less the marketplace's
 * commission, credited once the goods went out, and a reversal row for
 * anything refunded since.
 *
 * Renders nothing until there is something to show — an order is not earned
 * until it is fulfilled, and an empty card on every open order would only be
 * noise.
 */
export function OrderEarningsCard({ order }: { order: Order }) {
  const { t } = useTranslation()
  const { sellerId } = useParams({ from: '/_authenticated/$sellerId' })
  const { data } = useTransfers({ order_id_eq: order.id })

  const transfers = data?.data ?? []
  if (transfers.length === 0) return null

  return (
    <Card>
      <CardHeader>
        <CardTitle>
          <BanknoteIcon className="size-4" />
          {t('orders.earnings.title')}
        </CardTitle>
      </CardHeader>

      <CardContent className="p-0">
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>{t('earnings.columns.kind')}</TableHead>
              <TableHead>{t('earnings.columns.status')}</TableHead>
              <TableHead>{t('orders.earnings.payout')}</TableHead>
              <TableHead className="text-right">{t('earnings.columns.amount')}</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {transfers.map((transfer) => (
              <TableRow key={transfer.id}>
                <TableCell>
                  {t(`earnings.kinds.${transfer.kind}`, { defaultValue: transfer.kind })}
                </TableCell>
                <TableCell>
                  <StatusBadge
                    status={transfer.status}
                    label={t(`earnings.statuses.${transfer.status}`, {
                      defaultValue: transfer.status,
                    })}
                  />
                </TableCell>
                <TableCell>
                  {transfer.payout_id ? (
                    <Link
                      to="/$sellerId/payouts/$payoutId"
                      params={{ sellerId, payoutId: transfer.payout_id }}
                    >
                      {t('orders.earnings.view_payout')}
                    </Link>
                  ) : (
                    <span className="text-muted-foreground">
                      {t('orders.earnings.not_settled')}
                    </span>
                  )}
                </TableCell>
                <TableCell className="text-right tabular-nums">{transfer.display_amount}</TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      </CardContent>
    </Card>
  )
}

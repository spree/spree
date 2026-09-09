import type { Order } from '@spree/admin-sdk'
import { formatStoreDateTime, useStore } from '@spree/dashboard-core'
import {
  Card,
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
import { Link } from '@tanstack/react-router'
import { useTranslation } from 'react-i18next'
import { useSellerTransfers } from '../../../hooks/use-seller-ledger'

/**
 * What this order earned its seller, and what a refund has taken back.
 *
 * Renders nothing on an order with no ledger rows — a first-party order has
 * none by definition, and a seller's order has none until it is fulfilled.
 */
export function SellerTransfersCard({ order }: { order: Order }) {
  const { t } = useTranslation()
  // Every admin reads the same instant the same way, whatever their browser
  // is set to — the store's timezone is what an order's dates mean.
  const { timezone } = useStore()
  const { data } = useSellerTransfers({ order_id_eq: order.id })

  const transfers = data?.data ?? []
  if (transfers.length === 0) return null

  return (
    <Card>
      <CardHeader>
        <CardTitle>
          <BanknoteIcon className="size-4" />
          {t('admin.payouts.order_card.title')}
        </CardTitle>
      </CardHeader>

      <Table>
        <TableHeader>
          <TableRow>
            <TableHead>{t('admin.payouts.columns.date')}</TableHead>
            <TableHead>{t('admin.payouts.columns.kind')}</TableHead>
            <TableHead>{t('admin.fields.status.label')}</TableHead>
            <TableHead>{t('admin.nav.seller_payouts')}</TableHead>
            <TableHead className="text-right">{t('admin.fields.amount.label')}</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {transfers.map((transfer) => (
            <TableRow key={transfer.id}>
              <TableCell className="whitespace-nowrap">
                {formatStoreDateTime(transfer.created_at, timezone)}
              </TableCell>
              <TableCell>
                {t(`admin.payouts.kinds.${transfer.kind}`, { defaultValue: transfer.kind })}
              </TableCell>
              <TableCell>
                <StatusBadge
                  status={transfer.status}
                  label={t(`admin.payouts.statuses.${transfer.status}`, {
                    defaultValue: transfer.status,
                  })}
                />
              </TableCell>
              <TableCell>
                {transfer.payout_id ? (
                  <Link
                    to={'/$storeId/sellers/payouts/$payoutId' as string}
                    params={{ payoutId: transfer.payout_id }}
                    className="no-underline"
                  >
                    {t('admin.payouts.order_card.view_payout')}
                  </Link>
                ) : (
                  <span className="text-muted-foreground">
                    {t('admin.payouts.order_card.not_settled')}
                  </span>
                )}
              </TableCell>
              <TableCell className="text-right tabular-nums">{transfer.display_amount}</TableCell>
            </TableRow>
          ))}
        </TableBody>
      </Table>
    </Card>
  )
}

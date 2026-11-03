import type { GiftCard, Order } from '@spree/admin-sdk'
import { Money, useStore } from '@spree/dashboard-core'
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
import { GiftIcon } from '@spree/dashboard-ui/icons'
import { Link } from '@tanstack/react-router'
import { format, parseISO } from 'date-fns'
import { useTranslation } from 'react-i18next'
import { translatedLabel } from '../../lib/translated-label'

interface IssuedRow {
  giftCard: GiftCard
  sentTo: string
}

/**
 * The gift cards the order bought, one per unit, with who each went to.
 * Codes stay masked here as on every order view; the gift card page shows
 * the card in full to staff who may read it.
 */
export function OrderIssuedGiftCardsCard({ order }: { order: Order }) {
  const { t } = useTranslation()
  const { storeId } = useStore()

  const rows: IssuedRow[] = (order.items ?? []).flatMap((item) =>
    (item.gift_cards ?? []).map((giftCard) => ({
      giftCard,
      sentTo: item.recipient?.email ?? order.email ?? '',
    })),
  )

  if (rows.length === 0) return null

  return (
    <Card>
      <CardHeader>
        <CardTitle>
          <GiftIcon className="size-4" />
          {t('admin.orders.detail.issued_gift_cards.title')}
        </CardTitle>
      </CardHeader>
      <CardContent>
        <div className="overflow-x-auto">
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>{t('admin.orders.detail.issued_gift_cards.columns.code')}</TableHead>
                <TableHead>{t('admin.orders.detail.issued_gift_cards.columns.amount')}</TableHead>
                <TableHead>{t('admin.orders.detail.issued_gift_cards.columns.sent_to')}</TableHead>
                <TableHead>{t('admin.orders.detail.issued_gift_cards.columns.expires')}</TableHead>
                <TableHead>{t('admin.fields.status.label')}</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {rows.map(({ giftCard, sentTo }) => (
                <TableRow key={giftCard.id}>
                  <TableCell className="font-mono">
                    <Link
                      to="/$storeId/loyalty/gift-cards"
                      params={{ storeId }}
                      search={{ edit: giftCard.id } as never}
                      className="hover:underline"
                    >
                      {giftCard.code}
                    </Link>
                  </TableCell>
                  <TableCell className="tabular-nums">
                    <Money amount={giftCard.amount} currency={giftCard.currency} />
                  </TableCell>
                  <TableCell className="text-muted-foreground">{sentTo}</TableCell>
                  <TableCell className="text-muted-foreground">
                    {/* A calendar date with no time or zone, so it is shown as written. */}
                    {giftCard.expires_at
                      ? format(parseISO(giftCard.expires_at), 'PP')
                      : t('admin.orders.detail.issued_gift_cards.never_expires')}
                  </TableCell>
                  <TableCell>
                    <StatusBadge
                      status={giftCard.status}
                      label={translatedLabel('admin.gift_cards.statuses', giftCard.status)}
                    />
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </div>
      </CardContent>
    </Card>
  )
}

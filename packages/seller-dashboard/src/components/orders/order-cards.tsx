import {
  AddressBlock,
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  Thumbnail,
} from '@spree/dashboard-ui'
import type { Order } from '@spree/seller-sdk'
import { useTranslation } from 'react-i18next'

/** What was bought. */
export function OrderItemsCard({ order }: { order: Order }) {
  const { t } = useTranslation()

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('orders.items')}</CardTitle>
      </CardHeader>
      <CardContent className="flex flex-col gap-3">
        {(order.items ?? []).map((item) => (
          <div key={item.id} className="flex items-center justify-between gap-3">
            <div className="flex min-w-0 items-center gap-3">
              {item.thumbnail_url && <Thumbnail src={item.thumbnail_url} alt={item.name ?? ''} />}
              <div className="min-w-0">
                <div className="truncate text-sm font-medium">{item.name}</div>
                <div className="truncate text-muted-foreground text-xs">
                  {[item.sku, item.options_text].filter(Boolean).join(' · ')}
                </div>
              </div>
            </div>
            <div className="flex shrink-0 items-center gap-4 text-sm">
              <span className="text-muted-foreground">× {item.quantity}</span>
              <span>{item.display_total}</span>
            </div>
          </div>
        ))}
      </CardContent>
    </Card>
  )
}

/**
 * What the sale came to.
 *
 * The seller's own figures — what the goods were worth, the tax on them and
 * the total. How the customer paid the marketplace is not shown here: that is
 * the group's payment, and what the seller is owed is the commission ledger.
 */
export function OrderSummaryCard({ order }: { order: Order }) {
  const { t } = useTranslation()

  const rows = [
    { label: t('orders.summary.item_total'), value: order.display_item_total },
    { label: t('orders.summary.tax_total'), value: order.display_tax_total },
  ].filter((row) => !!row.value)

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('orders.summary.title')}</CardTitle>
      </CardHeader>
      <CardContent className="flex flex-col gap-2 text-sm">
        {rows.map((row) => (
          <div key={row.label} className="flex items-center justify-between gap-3">
            <span className="text-muted-foreground">{row.label}</span>
            <span>{row.value}</span>
          </div>
        ))}
        <div className="flex items-center justify-between gap-3 border-t pt-2 font-medium">
          <span>{t('orders.summary.total')}</span>
          <span>{order.display_total}</span>
        </div>
      </CardContent>
    </Card>
  )
}

/**
 * Where the parcel goes and who the invoice is for.
 *
 * No email address: a seller reaching the customer about a delivery has the
 * phone on the shipping address, and an email is the one contact detail that
 * would let a marketplace's customer be taken off it.
 */
export function OrderCustomerCard({ order }: { order: Order }) {
  const { t } = useTranslation()

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('orders.customer.title')}</CardTitle>
      </CardHeader>
      <CardContent className="flex flex-col gap-4">
        {order.shipping_address && (
          <div className="flex flex-col gap-1">
            <p className="text-muted-foreground text-xs uppercase">
              {t('orders.shipping_address')}
            </p>
            <AddressBlock address={order.shipping_address} />
          </div>
        )}
        {order.billing_address && (
          <div className="flex flex-col gap-1">
            <p className="text-muted-foreground text-xs uppercase">{t('orders.billing_address')}</p>
            <AddressBlock address={order.billing_address} />
          </div>
        )}
      </CardContent>
    </Card>
  )
}

/** What the customer asked for when they placed the order. */
export function OrderNoteCard({ order }: { order: Order }) {
  const { t } = useTranslation()
  if (!order.customer_note) return null

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('orders.customer_note')}</CardTitle>
      </CardHeader>
      <CardContent>
        <p className="text-sm whitespace-pre-wrap">{order.customer_note}</p>
      </CardContent>
    </Card>
  )
}

import { AddressFormDialog } from '@spree/dashboard-core'
import {
  AddressBlock,
  Button,
  Card,
  CardAction,
  CardHeader,
  CardTitle,
  cn,
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
  Separator,
} from '@spree/dashboard-ui'
import { EllipsisVerticalIcon, PencilIcon } from '@spree/dashboard-ui/icons'
import type { Order, OrderAddressParams } from '@spree/seller-sdk'
import { type ReactNode, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { sellerClient } from '../../api-client'
import { useOrderMutation } from '../../hooks/use-order'

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
      <span
        className={cn('text-sm tabular-nums', bold && 'font-bold', danger && 'text-destructive')}
      >
        {value}
      </span>
    </div>
  )
}

function formatDate(iso: string | null | undefined) {
  if (!iso) return '—'
  return new Date(iso).toLocaleString()
}

/**
 * What the sale came to, and what has been paid against it.
 *
 * The same rows the operator sees on their own order page, so a seller
 * reconciling a payout is reading the same arithmetic — a row appears only
 * when it carries a figure, which is why a simple order shows three lines and
 * a discounted, taxed, shipped one shows eight.
 *
 * The items themselves are listed on the parcels above rather than repeated
 * here: what a seller needs from a line is which parcel it travels in.
 */
export function OrderSummaryCard({ order }: { order: Order }) {
  const { t } = useTranslation()

  const amount = (value: string | null | undefined) => Number.parseFloat(value ?? '0')
  const outstanding = amount(order.amount_due)
  const placed = Boolean(order.completed_at)

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('orders.summary.title')}</CardTitle>
      </CardHeader>

      <div className="py-1">
        <SummaryRow label={t('orders.summary.created_at')} value={formatDate(order.created_at)} />
        {order.completed_at && (
          <SummaryRow
            label={t('orders.summary.completed_at')}
            value={formatDate(order.completed_at)}
          />
        )}

        {order.canceled_at && (
          <>
            <Separator />
            <SummaryRow
              label={t('orders.summary.canceled_at')}
              value={formatDate(order.canceled_at)}
            />
            {order.cancel_reason_name && (
              <SummaryRow
                label={t('orders.summary.cancel_reason')}
                value={order.cancel_reason_name}
              />
            )}
            {order.cancel_note && (
              <SummaryRow label={t('orders.summary.cancel_note')} value={order.cancel_note} />
            )}
          </>
        )}

        <Separator />

        <SummaryRow label={t('orders.summary.currency')} value={order.currency} />

        <Separator />

        <SummaryRow label={t('orders.summary.subtotal')} value={order.display_item_total} />

        {amount(order.delivery_total) > 0 && (
          <SummaryRow label={t('orders.summary.shipping')} value={order.display_delivery_total} />
        )}

        {amount(order.discount_total) !== 0 && (
          <SummaryRow label={t('orders.summary.promotions')} value={order.display_discount_total} />
        )}

        {amount(order.adjustment_total) !== 0 && (
          <SummaryRow
            label={t('orders.summary.adjustments')}
            value={order.display_adjustment_total}
          />
        )}

        {amount(order.included_tax_total) > 0 && (
          <SummaryRow
            label={t('orders.summary.tax_included')}
            value={order.display_included_tax_total}
          />
        )}

        {/* Shown on a placed order even at zero, so "no tax was charged" reads
            as an answer rather than a missing row. */}
        {(amount(order.additional_tax_total) > 0 ||
          (placed && amount(order.included_tax_total) === 0)) && (
          <SummaryRow
            label={t('orders.summary.tax_additional')}
            value={order.display_additional_tax_total}
          />
        )}

        <Separator />

        <SummaryRow label={t('orders.summary.total')} value={order.display_total} bold />

        <Separator />

        <SummaryRow
          label={t('orders.summary.payment_total')}
          value={order.display_payment_total}
          highlight
        />
        <SummaryRow
          label={t('orders.summary.outstanding_balance')}
          value={order.display_amount_due}
          highlight
          danger={outstanding > 0}
        />
      </div>
    </Card>
  )
}

/**
 * Where the parcel goes and who the invoice is for, and correcting either.
 *
 * The seller is merchant of record for their own child order, so a delivery
 * address the buyer got wrong is theirs to fix and the invoice address is
 * what they bill against.
 *
 * No email address: a seller reaching the customer about a delivery has the
 * phone on the shipping address, and an email is the one contact detail that
 * would let a marketplace's customer be taken off it.
 */
export function OrderCustomerCard({ order }: { order: Order }) {
  const { t } = useTranslation()
  const [editing, setEditing] = useState<'shipping_address' | 'billing_address' | null>(null)

  const save = useOrderMutation(order.id, (params: { type: string; address: OrderAddressParams }) =>
    sellerClient().orders.address(order.id, { [params.type]: params.address }),
  )

  const editable = !order.canceled_at

  return (
    <>
      <Card>
        <CardHeader>
          <CardTitle>{t('orders.customer.title')}</CardTitle>
          {editable && (
            <CardAction>
              <DropdownMenu>
                <DropdownMenuTrigger
                  render={
                    <Button variant="ghost" size="icon-xs" aria-label={t('common.actions')}>
                      <EllipsisVerticalIcon className="size-4" />
                    </Button>
                  }
                />
                <DropdownMenuContent align="end">
                  <DropdownMenuItem onClick={() => setEditing('shipping_address')}>
                    <PencilIcon className="size-4" />
                    {t('orders.address_edit.shipping_title')}
                  </DropdownMenuItem>
                  <DropdownMenuItem onClick={() => setEditing('billing_address')}>
                    <PencilIcon className="size-4" />
                    {t('orders.address_edit.billing_title')}
                  </DropdownMenuItem>
                </DropdownMenuContent>
              </DropdownMenu>
            </CardAction>
          )}
        </CardHeader>
        <div className="flex flex-col gap-4 px-6 pb-6">
          <AddressBlock title={t('orders.shipping_address')} address={order.shipping_address} />
          <AddressBlock title={t('orders.billing_address')} address={order.billing_address} />
        </div>
      </Card>

      {/* Mounted only while open, so the form seeds from the address as it is
          now rather than freezing at first render. */}
      {editing && (
        <AddressFormDialog
          title={
            editing === 'shipping_address'
              ? t('orders.address_edit.shipping_title')
              : t('orders.address_edit.billing_title')
          }
          address={editing === 'shipping_address' ? order.shipping_address : order.billing_address}
          open
          onOpenChange={(open) => !open && setEditing(null)}
          onSave={(address) =>
            save.mutate(
              { type: editing, address },
              // Kept open on failure so the entered address is not lost.
              { onSuccess: () => setEditing(null) },
            )
          }
          isPending={save.isPending}
        />
      )}
    </>
  )
}

import { currencyParts } from '@spree/dashboard-core'
import {
  Badge,
  Button,
  Card,
  CardAction,
  CardContent,
  CardHeader,
  CardTitle,
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
  ReturnReceiveDialog,
  ReturnRefundDialog,
  StatusBadge,
  useConfirm,
} from '@spree/dashboard-ui'
import { EllipsisVerticalIcon, PlusIcon, RotateCcwIcon } from '@spree/dashboard-ui/icons'
import type { Order, Return, ReturnLineItem } from '@spree/seller-sdk'
import i18n from 'i18next'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { useOrderReturns, useReturnActions } from '../../hooks/use-post-sale'
import { lineLabel } from './line-label'
import { CreateReturnDialog, fulfilledUnits } from './post-sale-create-dialogs'

// Refunded and canceled returns are finished; offering a menu on them would
// open onto nothing.
const ACTIONABLE = ['requested', 'approved', 'received']

/**
 * Goods coming back on this order.
 *
 * Each status change is its own action rather than an editable field, because
 * each carries different arguments — receiving records what actually arrived,
 * refunding decides where the money goes.
 */
export function ReturnsCard({ order }: { order: Order }) {
  const { t } = useTranslation()
  const confirm = useConfirm()
  const { data } = useOrderReturns(order.id)
  const { approve, cancel } = useReturnActions(order.id)

  const [createOpen, setCreateOpen] = useState(false)
  const [receiving, setReceiving] = useState<Return | null>(null)
  const [refunding, setRefunding] = useState<Return | null>(null)

  const returns = data?.data ?? []
  const canCreate = fulfilledUnits(order).length > 0

  async function handleCancel(returnRecord: Return) {
    const ok = await confirm({
      title: t('orders.post_sale.returns.cancel_title'),
      message: t('orders.post_sale.returns.cancel_message'),
      variant: 'destructive',
      confirmLabel: t('orders.post_sale.cancel'),
    })
    if (!ok) return
    cancel.mutate(returnRecord.id)
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle>
          <RotateCcwIcon className="size-4" />
          {t('orders.post_sale.returns.title')}
        </CardTitle>
        {canCreate && (
          <CardAction>
            <Button variant="outline" size="sm" onClick={() => setCreateOpen(true)}>
              <PlusIcon className="size-4" />
              {t('orders.post_sale.returns.create')}
            </Button>
          </CardAction>
        )}
      </CardHeader>

      <CardContent className="flex flex-col gap-4">
        {returns.length === 0 ? (
          <p className="text-muted-foreground text-sm">{t('orders.post_sale.returns.empty')}</p>
        ) : (
          returns.map((returnRecord) => (
            <Card key={returnRecord.id} variant="nested">
              <CardHeader>
                <CardTitle className="text-sm font-medium">{returnRecord.number}</CardTitle>
                <CardAction className="flex items-center gap-2">
                  <StatusBadge
                    status={returnRecord.status}
                    label={t(`orders.post_sale.statuses.${returnRecord.status}`, {
                      defaultValue: returnRecord.status,
                    })}
                  />
                  {ACTIONABLE.includes(returnRecord.status) && (
                    <DropdownMenu>
                      <DropdownMenuTrigger asChild>
                        <Button variant="ghost" size="icon-xs">
                          <EllipsisVerticalIcon className="size-4" />
                          <span className="sr-only">{t('admin.actions.actions_menu')}</span>
                        </Button>
                      </DropdownMenuTrigger>
                      <DropdownMenuContent align="end">
                        {returnRecord.status === 'requested' && (
                          <DropdownMenuItem onClick={() => approve.mutate(returnRecord.id)}>
                            {t('orders.post_sale.approve')}
                          </DropdownMenuItem>
                        )}
                        {returnRecord.status === 'approved' && (
                          <DropdownMenuItem onClick={() => setReceiving(returnRecord)}>
                            {t('orders.post_sale.returns.receive')}
                          </DropdownMenuItem>
                        )}
                        {returnRecord.status === 'received' && (
                          <DropdownMenuItem onClick={() => setRefunding(returnRecord)}>
                            {t('orders.post_sale.returns.refund')}
                          </DropdownMenuItem>
                        )}
                        <DropdownMenuSeparator />
                        <DropdownMenuItem
                          variant="destructive"
                          onClick={() => handleCancel(returnRecord)}
                        >
                          {t('orders.post_sale.cancel')}
                        </DropdownMenuItem>
                      </DropdownMenuContent>
                    </DropdownMenu>
                  )}
                </CardAction>
              </CardHeader>

              <CardContent className="flex flex-col gap-1.5">
                {returnRecord.return_line_items?.map((line) => (
                  <ReturnLineRow key={line.id} line={line} />
                ))}
                <p className="text-muted-foreground text-sm">
                  {t('orders.post_sale.returns.refund_total', {
                    amount: returnRecord.display_refund_total,
                  })}
                </p>
              </CardContent>
            </Card>
          ))
        )}
      </CardContent>

      <CreateReturnDialog order={order} open={createOpen} onOpenChange={setCreateOpen} />
      {receiving && (
        <ReceiveDialog
          orderId={order.id}
          returnRecord={receiving}
          onOpenChange={() => setReceiving(null)}
        />
      )}
      {refunding && (
        <RefundDialog
          orderId={order.id}
          order={order}
          returnRecord={refunding}
          onOpenChange={() => setRefunding(null)}
        />
      )}
    </Card>
  )
}

function ReturnLineRow({ line }: { line: ReturnLineItem }) {
  const { t } = useTranslation()
  const label = lineLabel(line.name, line.variant, line.variant_id)

  return (
    <div className="flex items-center justify-between gap-3 text-sm">
      <span className="truncate">{label}</span>
      <span className="flex shrink-0 items-center gap-2 text-muted-foreground">
        {line.received_quantity > 0 && line.received_quantity < line.quantity && (
          <Badge variant="outline">
            {t('orders.post_sale.returns.partially_received', {
              received: line.received_quantity,
              quantity: line.quantity,
            })}
          </Badge>
        )}
        {!line.resellable && (
          <Badge variant="outline">{t('orders.post_sale.returns.not_resellable')}</Badge>
        )}
        × {line.quantity}
      </span>
    </div>
  )
}

/** What actually turned up, and whether it can go back on the shelf. */

/** What the seller records as having arrived back. */
function ReceiveDialog({
  orderId,
  returnRecord,
  onOpenChange,
}: {
  orderId: string
  returnRecord: Return
  onOpenChange: (open: boolean) => void
}) {
  const { receive } = useReturnActions(orderId)

  return (
    <ReturnReceiveDialog
      lines={(returnRecord.return_line_items ?? []).map((line) => ({
        id: line.id,
        label: lineLabel(line.name, line.variant, line.variant_id),
        quantity: line.quantity,
      }))}
      onClose={() => onOpenChange(false)}
      pending={receive.isPending}
      onSubmit={(items) => {
        receive
          .mutateAsync({ returnId: returnRecord.id, items })
          .then(() => onOpenChange(false))
          .catch(() => undefined)
      }}
    />
  )
}

/**
 * The seller took the money for their own child order, so giving it back is
 * theirs. The currency is the order's — a seller has none of their own.
 */
function RefundDialog({
  orderId,
  order,
  returnRecord,
  onOpenChange,
}: {
  orderId: string
  order: Order
  returnRecord: Return
  onOpenChange: (open: boolean) => void
}) {
  const { refund } = useReturnActions(orderId)
  const { symbol: currencySymbol } = currencyParts(order.currency, i18n.language)

  return (
    <ReturnRefundDialog
      refundableTotal={returnRecord.refundable_total}
      currencySymbol={currencySymbol}
      onClose={() => onOpenChange(false)}
      pending={refund.isPending}
      onSubmit={({ refundMethod, amount }) => {
        refund
          .mutateAsync({ returnId: returnRecord.id, refundMethod, amount })
          .then(() => onOpenChange(false))
          .catch(() => undefined)
      }}
    />
  )
}

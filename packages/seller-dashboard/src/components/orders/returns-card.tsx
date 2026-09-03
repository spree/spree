import {
  Badge,
  Button,
  Card,
  CardAction,
  CardContent,
  CardHeader,
  CardTitle,
  Dialog,
  DialogBody,
  DialogContent,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
  Field,
  FieldLabel,
  Input,
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
  StatusBadge,
  Switch,
  useConfirm,
} from '@spree/dashboard-ui'
import { EllipsisVerticalIcon, PlusIcon, RotateCcwIcon } from '@spree/dashboard-ui/icons'
import type { Order, Return, ReturnLineItem } from '@spree/seller-sdk'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { useOrderReturns, useReturnActions } from '../../hooks/use-post-sale'
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
        <CardTitle className="flex items-center gap-2">
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

      <CardContent className="flex flex-col gap-3">
        {returns.length === 0 ? (
          <p className="text-muted-foreground text-sm">{t('orders.post_sale.returns.empty')}</p>
        ) : (
          returns.map((returnRecord) => (
            <Card key={returnRecord.id} variant="nested">
              <CardHeader>
                <CardTitle className="text-sm">{returnRecord.number}</CardTitle>
                <CardAction className="flex items-center gap-2">
                  <StatusBadge
                    status={returnRecord.status}
                    label={t(`orders.post_sale.statuses.${returnRecord.status}`, {
                      defaultValue: returnRecord.status,
                    })}
                  />
                  {ACTIONABLE.includes(returnRecord.status) && (
                    <DropdownMenu>
                      <DropdownMenuTrigger
                        render={
                          <Button variant="ghost" size="icon" aria-label={t('common.actions')}>
                            <EllipsisVerticalIcon className="size-4" />
                          </Button>
                        }
                      />
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

              <CardContent className="flex flex-col gap-2">
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
          open
          onOpenChange={() => setReceiving(null)}
        />
      )}
      {refunding && (
        <RefundDialog
          orderId={order.id}
          returnRecord={refunding}
          open
          onOpenChange={() => setRefunding(null)}
        />
      )}
    </Card>
  )
}

function ReturnLineRow({ line }: { line: ReturnLineItem }) {
  const { t } = useTranslation()
  const label =
    [line.variant?.sku, line.variant?.options_text].filter(Boolean).join(' · ') ||
    line.variant_id ||
    ''

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
function ReceiveDialog({
  orderId,
  returnRecord,
  open,
  onOpenChange,
}: {
  orderId: string
  returnRecord: Return
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const { receive } = useReturnActions(orderId)

  const lines = returnRecord.return_line_items ?? []
  const [rows, setRows] = useState<Record<string, { quantity: number; resellable: boolean }>>(() =>
    Object.fromEntries(
      lines.map((line) => [line.id, { quantity: line.quantity, resellable: true }]),
    ),
  )

  async function handleReceive() {
    await receive
      .mutateAsync({
        returnId: returnRecord.id,
        items: lines.map((line) => ({
          return_line_item_id: line.id,
          quantity: rows[line.id]?.quantity ?? 0,
          resellable: rows[line.id]?.resellable ?? true,
        })),
      })
      .then(() => onOpenChange(false))
      .catch(() => undefined)
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{t('orders.post_sale.returns.receive_title')}</DialogTitle>
        </DialogHeader>
        <DialogBody>
          <div className="flex flex-col gap-3">
            {lines.map((line) => (
              <div key={line.id} className="flex items-center justify-between gap-3">
                <span className="min-w-0 truncate text-sm">
                  {[line.variant?.sku, line.variant?.options_text].filter(Boolean).join(' · ') ||
                    line.variant_id}
                </span>
                <div className="flex shrink-0 items-center gap-3">
                  <label className="flex items-center gap-2 text-xs" htmlFor={`resell-${line.id}`}>
                    {t('orders.post_sale.returns.resellable')}
                    <Switch
                      id={`resell-${line.id}`}
                      checked={rows[line.id]?.resellable ?? true}
                      onCheckedChange={(checked) =>
                        setRows((current) => ({
                          ...current,
                          [line.id]: {
                            quantity: current[line.id]?.quantity ?? 0,
                            resellable: !!checked,
                          },
                        }))
                      }
                    />
                  </label>
                  <Input
                    type="number"
                    min={0}
                    max={line.quantity}
                    className="w-20"
                    aria-label={t('orders.post_sale.returns.received_quantity')}
                    value={rows[line.id]?.quantity ?? 0}
                    onChange={(event) =>
                      setRows((current) => ({
                        ...current,
                        [line.id]: {
                          quantity: Math.max(
                            0,
                            Math.min(line.quantity, Number(event.target.value)),
                          ),
                          resellable: current[line.id]?.resellable ?? true,
                        },
                      }))
                    }
                  />
                </div>
              </div>
            ))}
          </div>
        </DialogBody>
        <DialogFooter>
          <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>
            {t('common.cancel')}
          </Button>
          <Button type="button" disabled={receive.isPending} onClick={handleReceive}>
            {t('orders.post_sale.returns.receive')}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}

/**
 * Giving the money back.
 *
 * Opens on what the return is still owed, which is also the most that can be
 * given back — the server refuses anything above it, and on a split checkout
 * bounds it again by this order's share of the payment.
 */
function RefundDialog({
  orderId,
  returnRecord,
  open,
  onOpenChange,
}: {
  orderId: string
  returnRecord: Return
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const { refund } = useReturnActions(orderId)

  const [amount, setAmount] = useState(returnRecord.refundable_total ?? '')
  const [method, setMethod] = useState<'original_payment' | 'store_credit'>('original_payment')

  const methodOptions = [
    { value: 'original_payment', label: t('orders.post_sale.returns.original_payment') },
    { value: 'store_credit', label: t('orders.post_sale.returns.store_credit') },
  ]

  async function handleRefund() {
    await refund
      .mutateAsync({ returnId: returnRecord.id, amount, refundMethod: method })
      .then(() => onOpenChange(false))
      .catch(() => undefined)
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{t('orders.post_sale.returns.refund_title')}</DialogTitle>
        </DialogHeader>
        <DialogBody>
          <div className="flex flex-col gap-4">
            <Field>
              <FieldLabel htmlFor="refund-amount">
                {t('orders.post_sale.returns.amount')}
              </FieldLabel>
              <Input
                id="refund-amount"
                type="number"
                step="0.01"
                min={0}
                value={amount}
                onChange={(event) => setAmount(event.target.value)}
              />
            </Field>

            <Field>
              <FieldLabel htmlFor="refund-method">
                {t('orders.post_sale.returns.refund_method')}
              </FieldLabel>
              <Select
                items={methodOptions}
                value={method}
                onValueChange={(value) =>
                  setMethod((value as 'original_payment' | 'store_credit') ?? 'original_payment')
                }
              >
                <SelectTrigger id="refund-method">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {methodOptions.map((option) => (
                    <SelectItem key={option.value} value={option.value}>
                      {option.label}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </Field>
          </div>
        </DialogBody>
        <DialogFooter>
          <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>
            {t('common.cancel')}
          </Button>
          <Button type="button" disabled={refund.isPending} onClick={handleRefund}>
            {t('orders.post_sale.returns.refund')}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}

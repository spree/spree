import type { Order, Return, ReturnLineItem } from '@spree/admin-sdk'
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
import {
  BanknoteIcon,
  CheckCircleIcon,
  EllipsisVerticalIcon,
  PackageCheckIcon,
  PlusIcon,
  RotateCcwIcon,
  XCircleIcon,
} from 'lucide-react'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { useOrderReturns, useReturnActions } from '../../hooks/use-returns'
import { CreateReturnDialog, fulfilledUnits } from './post-sale-create-dialogs'

type ReceiptRow = { quantity: number; resellable: boolean }

// Statuses that still offer an action; refunded and canceled are done and
// would render a menu button that opens onto nothing.
const RETURN_ACTIONABLE = ['requested', 'approved', 'received']

/** "Product — Small / Blue", falling back to the SKU or the raw id. */
function variantLabel(line: ReturnLineItem): string {
  const variant = line.variant
  if (!variant) return line.variant_id ?? ''

  const parts = [variant.product_name, variant.options_text].filter(Boolean)
  return parts.length > 0 ? parts.join(' — ') : (variant.sku ?? line.variant_id ?? '')
}

/**
 * Returns on an order. Each status change is a distinct action rather than an
 * editable status field, because each one carries its own arguments —
 * receiving records what actually arrived, refunding picks where the money
 * goes.
 */
export function OrderReturnsCard({ order }: { order: Order }) {
  const orderId = order.id
  const { t } = useTranslation()
  const confirm = useConfirm()
  const { data } = useOrderReturns(orderId)
  const { create, approve, receive, refund, cancel } = useReturnActions(orderId)

  const [creating, setCreating] = useState(false)
  const [receiving, setReceiving] = useState<Return | null>(null)
  const [refunding, setRefunding] = useState<Return | null>(null)

  const returns = data?.data ?? []
  const canCreate = fulfilledUnits(order).length > 0

  return (
    <>
      <Card>
        <CardHeader>
          <CardTitle>
            <RotateCcwIcon className="size-4" />
            {t('admin.pages.orders.detail.section_returns')}
            {returns.length > 0 && <Badge variant="outline">{returns.length}</Badge>}
          </CardTitle>
          <CardAction>
            <Button
              variant="outline"
              size="sm"
              disabled={!canCreate}
              title={canCreate ? undefined : t('admin.pages.orders.detail.returns.empty_no_units')}
              onClick={() => setCreating(true)}
            >
              <PlusIcon className="size-4" />
              {t('admin.pages.orders.detail.returns.actions.create')}
            </Button>
          </CardAction>
        </CardHeader>
        <CardContent className="flex flex-col gap-4">
          {returns.length === 0 && (
            <p className="text-sm text-muted-foreground">
              {canCreate
                ? t('admin.pages.orders.detail.returns.empty')
                : t('admin.pages.orders.detail.returns.empty_no_units')}
            </p>
          )}
          {returns.map((returnRecord) => (
            <div key={returnRecord.id} className="rounded-lg border p-4 flex flex-col gap-3">
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-2">
                  <StatusBadge status={returnRecord.status} />
                  <span className="text-sm font-medium">{returnRecord.number}</span>
                </div>

                {RETURN_ACTIONABLE.includes(returnRecord.status) && (
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
                          <CheckCircleIcon className="size-4" />
                          {t('admin.pages.orders.detail.returns.actions.approve')}
                        </DropdownMenuItem>
                      )}
                      {returnRecord.status === 'approved' && (
                        <DropdownMenuItem onClick={() => setReceiving(returnRecord)}>
                          <PackageCheckIcon className="size-4" />
                          {t('admin.pages.orders.detail.returns.actions.receive')}
                        </DropdownMenuItem>
                      )}
                      {returnRecord.status === 'received' && (
                        <DropdownMenuItem onClick={() => setRefunding(returnRecord)}>
                          <BanknoteIcon className="size-4" />
                          {t('admin.pages.orders.detail.returns.actions.refund')}
                        </DropdownMenuItem>
                      )}
                      {['requested', 'approved'].includes(returnRecord.status) && (
                        <>
                          <DropdownMenuSeparator />
                          <DropdownMenuItem
                            className="text-destructive focus:text-destructive"
                            onClick={async () => {
                              if (
                                await confirm({
                                  message: t('admin.pages.orders.detail.returns.confirm.cancel'),
                                  variant: 'destructive',
                                  confirmLabel: t('admin.actions.cancel'),
                                })
                              ) {
                                cancel.mutate({ returnId: returnRecord.id })
                              }
                            }}
                          >
                            <XCircleIcon className="size-4" />
                            {t('admin.actions.cancel')}
                          </DropdownMenuItem>
                        </>
                      )}
                    </DropdownMenuContent>
                  </DropdownMenu>
                )}
              </div>

              <div className="flex flex-col gap-1.5">
                {(returnRecord.return_line_items ?? []).map((line) => (
                  <ReturnLineRow key={line.id} line={line} status={returnRecord.status} />
                ))}
              </div>

              <div className="flex items-center justify-between text-sm border-t pt-3">
                <span className="text-muted-foreground">
                  {t('admin.pages.orders.detail.returns.refund_total')}
                </span>
                <span className="font-medium">{returnRecord.display_refund_total}</span>
              </div>
            </div>
          ))}
        </CardContent>
      </Card>

      {creating && (
        <CreateReturnDialog
          order={order}
          onClose={() => setCreating(false)}
          onSubmit={(params) => {
            create.mutate(params)
            setCreating(false)
          }}
        />
      )}

      {receiving && (
        <ReceiveDialog
          returnRecord={receiving}
          onClose={() => setReceiving(null)}
          onSubmit={(items) => {
            receive.mutate({ returnId: receiving.id, items })
            setReceiving(null)
          }}
        />
      )}

      {refunding && (
        <RefundDialog
          returnRecord={refunding}
          onClose={() => setRefunding(null)}
          onSubmit={(params) => {
            refund.mutate({ returnId: refunding.id, ...params })
            setRefunding(null)
          }}
        />
      )}
    </>
  )
}

function ReturnLineRow({ line, status }: { line: ReturnLineItem; status: string }) {
  const { t } = useTranslation()
  const received = ['received', 'refunded'].includes(status)

  return (
    <div className="flex items-center justify-between text-sm">
      <span className="truncate">{variantLabel(line)}</span>
      <span className="flex items-center gap-2 text-muted-foreground">
        {received && line.received_quantity !== line.quantity && (
          <Badge variant="outline">
            {t('admin.pages.orders.detail.returns.received_of', {
              received: line.received_quantity,
              requested: line.quantity,
            })}
          </Badge>
        )}
        {received && !line.resellable && (
          <Badge variant="outline">{t('admin.pages.orders.detail.returns.not_resellable')}</Badge>
        )}
        <span>×{line.quantity}</span>
      </span>
    </div>
  )
}

/**
 * Partial and damaged receipt is the normal case, so the dialog opens with
 * every line editable rather than hiding that behind an "advanced" toggle.
 */
function ReceiveDialog({
  returnRecord,
  onClose,
  onSubmit,
}: {
  returnRecord: Return
  onClose: () => void
  onSubmit: (
    items: Array<{ return_line_item_id: string; quantity: number; resellable: boolean }>,
  ) => void
}) {
  const { t } = useTranslation()
  const lines = returnRecord.return_line_items ?? []
  const [rows, setRows] = useState<Record<string, ReceiptRow>>(() =>
    Object.fromEntries(
      lines.map((line) => [line.id, { quantity: line.quantity, resellable: true }]),
    ),
  )

  return (
    <Dialog open onOpenChange={(open) => !open && onClose()}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{t('admin.pages.orders.detail.returns.receive_title')}</DialogTitle>
        </DialogHeader>
        <DialogBody className="flex flex-col gap-4">
          {lines.map((line) => (
            <div key={line.id} className="flex flex-col gap-2 rounded-lg border p-3">
              <span className="text-sm font-medium">{variantLabel(line)}</span>
              <div className="flex items-center gap-4">
                <Field className="flex-1">
                  <FieldLabel htmlFor={`qty-${line.id}`}>
                    {t('admin.pages.orders.detail.returns.received_quantity')}
                  </FieldLabel>
                  <Input
                    id={`qty-${line.id}`}
                    type="number"
                    min={0}
                    max={line.quantity}
                    value={rows[line.id]?.quantity ?? 0}
                    onChange={(event) =>
                      setRows((current) => ({
                        ...current,
                        [line.id]: {
                          quantity: Math.min(Number(event.target.value), line.quantity),
                          resellable: current[line.id]?.resellable ?? true,
                        },
                      }))
                    }
                  />
                </Field>
                <Field orientation="horizontal">
                  <FieldLabel htmlFor={`resellable-${line.id}`}>
                    {t('admin.pages.orders.detail.returns.resellable')}
                  </FieldLabel>
                  <Switch
                    id={`resellable-${line.id}`}
                    checked={rows[line.id]?.resellable ?? true}
                    onCheckedChange={(checked) =>
                      setRows((current) => ({
                        ...current,
                        [line.id]: {
                          quantity: current[line.id]?.quantity ?? 0,
                          resellable: checked,
                        },
                      }))
                    }
                  />
                </Field>
              </div>
            </div>
          ))}
        </DialogBody>
        <DialogFooter>
          <Button variant="outline" onClick={onClose}>
            {t('admin.actions.cancel')}
          </Button>
          <Button
            onClick={() =>
              onSubmit(
                lines.map((line) => ({
                  return_line_item_id: line.id,
                  quantity: rows[line.id]?.quantity ?? 0,
                  resellable: rows[line.id]?.resellable ?? true,
                })),
              )
            }
          >
            {t('admin.pages.orders.detail.returns.actions.receive')}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}

function RefundDialog({
  returnRecord,
  onClose,
  onSubmit,
}: {
  returnRecord: Return
  onClose: () => void
  onSubmit: (params: { refundMethod: 'original_payment' | 'store_credit'; amount?: string }) => void
}) {
  const { t } = useTranslation()
  const [refundMethod, setRefundMethod] = useState<'original_payment' | 'store_credit'>(
    'original_payment',
  )
  const [amount, setAmount] = useState(returnRecord.refundable_total)

  const methodOptions = [
    {
      value: 'original_payment',
      label: t('admin.pages.orders.detail.returns.refund_methods.original_payment'),
    },
    {
      value: 'store_credit',
      label: t('admin.pages.orders.detail.returns.refund_methods.store_credit'),
    },
  ]

  return (
    <Dialog open onOpenChange={(open) => !open && onClose()}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{t('admin.pages.orders.detail.returns.refund_title')}</DialogTitle>
        </DialogHeader>
        <DialogBody className="flex flex-col gap-4">
          <Field>
            <FieldLabel htmlFor="refund-amount">
              {t('admin.pages.orders.detail.returns.refund_amount')}
            </FieldLabel>
            <Input
              id="refund-amount"
              value={amount}
              onChange={(event) => setAmount(event.target.value)}
            />
          </Field>
          <Field>
            <FieldLabel htmlFor="refund-method">
              {t('admin.pages.orders.detail.returns.refund_method')}
            </FieldLabel>
            <Select
              items={methodOptions}
              value={refundMethod}
              onValueChange={(value) =>
                setRefundMethod(value as 'original_payment' | 'store_credit')
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
        </DialogBody>
        <DialogFooter>
          <Button variant="outline" onClick={onClose}>
            {t('admin.actions.cancel')}
          </Button>
          <Button onClick={() => onSubmit({ refundMethod, amount })}>
            {t('admin.pages.orders.detail.returns.actions.refund')}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}

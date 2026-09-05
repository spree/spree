import type { Order, Return, ReturnLineItem } from '@spree/admin-sdk'
import { currencyParts, useStore } from '@spree/dashboard-core'
import {
  Badge,
  Button,
  Card,
  CardAction,
  CardContent,
  CardFooter,
  CardHeader,
  CardTitle,
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
  type RefundMethod,
  ReturnReceiveDialog,
  ReturnRefundDialog,
  StatusBadge,
  useConfirm,
} from '@spree/dashboard-ui'
import {
  BanknoteIcon,
  CheckCircleIcon,
  EllipsisVerticalIcon,
  PackageCheckIcon,
  PlusIcon,
  RotateCcwIcon,
  TagIcon,
  XCircleIcon,
} from '@spree/dashboard-ui/icons'
import i18n from 'i18next'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { useOrderReturns, useReturnActions } from '../../hooks/use-returns'
import { ShippingDocuments } from './orders/shipping-documents'
import { ShippingLabelRow } from './orders/shipping-label-row'
import { CreateReturnDialog, fulfilledUnits } from './post-sale-create-dialogs'

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
  const { create, approve, receive, refund, cancel, buyLabel, refundLabel, deleteLabel } =
    useReturnActions(orderId)

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
            <Card key={returnRecord.id} variant="nested">
              <CardHeader>
                <CardTitle className="text-sm font-medium">
                  <StatusBadge status={returnRecord.status} />
                  <span className="text-sm font-medium">{returnRecord.number}</span>
                </CardTitle>

                {RETURN_ACTIONABLE.includes(returnRecord.status) && (
                  <CardAction>
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
                              variant="destructive"
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
                  </CardAction>
                )}
              </CardHeader>

              <ReturnLabel
                returnRecord={returnRecord}
                onBuy={() => buyLabel.mutate({ returnId: returnRecord.id })}
                onRefund={(labelId) => refundLabel.mutate({ returnId: returnRecord.id, labelId })}
                onDelete={(labelId) => deleteLabel.mutate({ returnId: returnRecord.id, labelId })}
                isBuying={buyLabel.isPending}
                isRefunding={refundLabel.isPending}
              />

              <CardContent className="flex flex-col gap-1.5">
                {(returnRecord.return_line_items ?? []).map((line) => (
                  <ReturnLineRow key={line.id} line={line} status={returnRecord.status} />
                ))}
                {returnRecord.stock_location?.name && (
                  <p className="text-sm text-muted-foreground">
                    {t('admin.pages.orders.detail.returns.returning_to', {
                      name: returnRecord.stock_location.name,
                    })}
                  </p>
                )}
              </CardContent>

              <CardFooter className="justify-between text-sm">
                <span className="text-muted-foreground">
                  {t('admin.pages.orders.detail.returns.refund_total')}
                </span>
                <span className="font-medium">{returnRecord.display_refund_total}</span>
              </CardFooter>
            </Card>
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

/** A return is only worth a label while the goods are still coming back. */
const RETURN_LABEL_STATUSES = ['requested', 'approved']

/**
 * The prepaid label for the parcel coming back, and the button to buy one.
 *
 * Bought through the carrier that shipped the goods out, since that is the
 * account the merchant has. Refunding and printing are the same actions an
 * outbound label offers, so they share a component.
 */
function ReturnLabel({
  returnRecord,
  onBuy,
  onRefund,
  onDelete,
  isBuying,
  isRefunding,
}: {
  returnRecord: Return
  onBuy: () => void
  onRefund: (labelId: string) => void
  onDelete: (labelId: string) => void
  isBuying: boolean
  isRefunding: boolean
}) {
  const { t } = useTranslation()
  const confirm = useConfirm()

  const activeLabel = (returnRecord.labels ?? []).find((label) => label.status !== 'refunded')
  const canBuy = !activeLabel && RETURN_LABEL_STATUSES.includes(returnRecord.status)

  if (activeLabel) {
    return (
      <>
        <ShippingLabelRow
          label={activeLabel}
          isRefunding={isRefunding}
          onRefund={() => onRefund(activeLabel.id)}
          onDelete={() => onDelete(activeLabel.id)}
        />
        <ShippingDocuments documents={returnRecord.documents} />
      </>
    )
  }

  if (!canBuy) return null

  return (
    <CardContent className="flex items-center justify-between border-b border-border-subtle py-3 text-sm">
      <span className="text-muted-foreground">
        {t('admin.pages.orders.detail.returns.no_label')}
      </span>
      <Button
        type="button"
        size="sm"
        variant="outline"
        disabled={isBuying}
        onClick={async () => {
          // Buying charges the carrier account, so it gets an explicit yes
          // even though nothing is destroyed.
          if (
            await confirm({
              message: t('admin.pages.orders.detail.returns.buy_label_confirm'),
              confirmLabel: t('admin.pages.orders.detail.returns.buy_label'),
            })
          ) {
            onBuy()
          }
        }}
      >
        <TagIcon data-icon="inline-start" />
        {isBuying ? t('admin.actions.saving') : t('admin.pages.orders.detail.returns.buy_label')}
      </Button>
    </CardContent>
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
  return (
    <ReturnReceiveDialog
      lines={(returnRecord.return_line_items ?? []).map((line) => ({
        id: line.id,
        label: variantLabel(line),
        quantity: line.quantity,
      }))}
      onClose={onClose}
      onSubmit={onSubmit}
    />
  )
}

function RefundDialog({
  returnRecord,
  onClose,
  onSubmit,
}: {
  returnRecord: Return
  onClose: () => void
  onSubmit: (params: { refundMethod: RefundMethod; amount?: string }) => void
}) {
  const { defaultCurrency } = useStore()
  const { symbol: currencySymbol } = currencyParts(defaultCurrency, i18n.language)

  return (
    <ReturnRefundDialog
      refundableTotal={returnRecord.refundable_total}
      currencySymbol={currencySymbol}
      onClose={onClose}
      onSubmit={onSubmit}
    />
  )
}

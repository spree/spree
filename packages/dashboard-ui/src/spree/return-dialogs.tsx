import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { Button } from '../ui/button'
import {
  Dialog,
  DialogBody,
  DialogContent,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '../ui/dialog'
import { Field, FieldLabel } from '../ui/field'
import { Input } from '../ui/input'
import { InputGroup, InputGroupAddon, InputGroupInput, InputGroupText } from '../ui/input-group'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '../ui/select'
import { Switch } from '../ui/switch'

/** How money goes back to the buyer. */
export type RefundMethod = 'original_payment' | 'store_credit'

/** One line of a return, as the receipt form needs it. */
export type ReturnLineForReceipt = {
  id: string
  label: string
  quantity: number
}

type ReceiptRow = { quantity: number; resellable: boolean }

/**
 * Records what actually arrived: a quantity per line, and whether each can go
 * back on the shelf.
 *
 * Deliberately not defaulted server-side — an omitted `items` means "receive
 * everything as requested", so a partial receipt has to say so line by line.
 * Shared by the operator's order page and the seller's.
 */
export function ReturnReceiveDialog({
  lines,
  onClose,
  onSubmit,
  pending = false,
}: {
  lines: ReturnLineForReceipt[]
  onClose: () => void
  onSubmit: (
    items: Array<{ return_line_item_id: string; quantity: number; resellable: boolean }>,
  ) => void
  pending?: boolean
}) {
  const { t } = useTranslation()
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
            <div key={line.id} className="flex flex-col gap-3">
              <span className="font-medium text-sm">{line.label}</span>
              <div className="flex flex-col gap-3">
                <Field>
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
                          // `min`/`max` bind the stepper only — a typed value
                          // reaches onChange unclamped.
                          quantity: Math.max(
                            0,
                            Math.min(Number(event.target.value) || 0, line.quantity),
                          ),
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
          <Button type="button" variant="outline" onClick={onClose} disabled={pending}>
            {t('admin.actions.cancel')}
          </Button>
          <Button
            type="button"
            disabled={pending}
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

/**
 * Gives the money back: how much, and by what means.
 *
 * The currency symbol comes from the caller — the operator's panel reads it
 * from the store it is looking at, and a seller has no currency of their own.
 */
export function ReturnRefundDialog({
  refundableTotal,
  currencySymbol,
  onClose,
  onSubmit,
  pending = false,
}: {
  refundableTotal: string
  currencySymbol: string
  onClose: () => void
  onSubmit: (params: { refundMethod: RefundMethod; amount?: string }) => void
  pending?: boolean
}) {
  const { t } = useTranslation()
  const [refundMethod, setRefundMethod] = useState<RefundMethod>('original_payment')
  const [amount, setAmount] = useState(refundableTotal)

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
            <InputGroup>
              <InputGroupAddon>
                <InputGroupText>{currencySymbol}</InputGroupText>
              </InputGroupAddon>
              <InputGroupInput
                id="refund-amount"
                type="number"
                step="0.01"
                min="0"
                value={amount}
                onChange={(event) => setAmount(event.target.value)}
              />
            </InputGroup>
          </Field>
          <Field>
            <FieldLabel htmlFor="refund-method">
              {t('admin.pages.orders.detail.returns.refund_method')}
            </FieldLabel>
            <Select
              items={methodOptions}
              value={refundMethod}
              onValueChange={(value) => setRefundMethod(value as RefundMethod)}
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
          <Button type="button" variant="outline" onClick={onClose} disabled={pending}>
            {t('admin.actions.cancel')}
          </Button>
          <Button
            type="button"
            disabled={pending}
            onClick={() => onSubmit({ refundMethod, amount })}
          >
            {t('admin.pages.orders.detail.returns.actions.refund')}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}

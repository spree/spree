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
import { Field, FieldDescription, FieldLabel } from '../ui/field'
import { Input } from '../ui/input'
import { InputGroup, InputGroupAddon, InputGroupInput, InputGroupText } from '../ui/input-group'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '../ui/select'

/** How money goes back to the buyer. */
export type RefundMethod = 'original_payment' | 'store_credit'

/** One line of a return, as the receipt form needs it. */
export type ReturnLineForReceipt = {
  id: string
  label: string
  /** The units still to come: what was announced less what earlier receipts counted. */
  quantity: number
}

/** One row of a receipt. A line split between resellable and not is named twice. */
export type ReturnReceiptItem = {
  return_line_item_id: string
  quantity: number
  resellable: boolean
}

type ReceiptRow = { resellable: number; unresellable: number }

/** The rows a receipt sends, leaving out any part with no units. */
export function receiptItems(rows: Record<string, ReceiptRow>): ReturnReceiptItem[] {
  return Object.entries(rows).flatMap(([id, row]) => [
    ...(row.resellable > 0
      ? [{ return_line_item_id: id, quantity: row.resellable, resellable: true }]
      : []),
    ...(row.unresellable > 0
      ? [{ return_line_item_id: id, quantity: row.unresellable, resellable: false }]
      : []),
  ])
}

/**
 * Records what actually arrived: per line, how many units can go back on the
 * shelf and how many cannot. Units left at zero stay outstanding and can be
 * received later.
 *
 * Deliberately not defaulted server-side — an omitted `items` means "receive
 * everything still to come", so a partial receipt has to say so line by line.
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
  onSubmit: (items: ReturnReceiptItem[]) => void
  pending?: boolean
}) {
  const { t } = useTranslation()
  const [rows, setRows] = useState<Record<string, ReceiptRow>>(() =>
    Object.fromEntries(
      lines.map((line) => [line.id, { resellable: line.quantity, unresellable: 0 }]),
    ),
  )
  const items = receiptItems(rows)

  // `min`/`max` bind the stepper only — a typed value reaches onChange
  // unclamped. The two parts of a line share its units, so raising one takes
  // units from the other rather than refusing the value: the dialog opens with
  // every unit resellable, and marking one damaged must not need two edits.
  const setPart = (line: ReturnLineForReceipt, part: keyof ReceiptRow, value: string) =>
    setRows((current) => {
      const row = current[line.id] ?? { resellable: 0, unresellable: 0 }
      const otherPart: keyof ReceiptRow = part === 'resellable' ? 'unresellable' : 'resellable'
      const count = Math.max(0, Math.min(Math.trunc(Number(value)) || 0, line.quantity))
      return {
        ...current,
        [line.id]: {
          ...row,
          [part]: count,
          [otherPart]: Math.min(row[otherPart], line.quantity - count),
        },
      }
    })

  const parts: Array<{ part: keyof ReceiptRow; label: string }> = [
    { part: 'resellable', label: t('admin.pages.orders.detail.returns.resellable') },
    { part: 'unresellable', label: t('admin.pages.orders.detail.returns.not_resellable') },
  ]

  return (
    <Dialog open onOpenChange={(open) => !open && onClose()}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{t('admin.pages.orders.detail.returns.receive_title')}</DialogTitle>
        </DialogHeader>
        <DialogBody className="flex flex-col gap-4">
          {lines.map((line) => (
            <div key={line.id} className="flex flex-col gap-3">
              <div className="flex items-baseline justify-between gap-3">
                <span id={`return-line-${line.id}`} className="font-medium text-base">
                  {line.label}
                </span>
                <span className="shrink-0 text-muted-foreground text-sm">
                  {t('admin.pages.orders.detail.returns.units_to_receive', {
                    count: line.quantity,
                  })}
                </span>
              </div>
              <fieldset
                aria-labelledby={`return-line-${line.id}`}
                className="grid min-w-0 grid-cols-2 gap-3"
              >
                {parts.map(({ part, label }) => (
                  <Field key={part}>
                    <FieldLabel htmlFor={`${part}-${line.id}`}>{label}</FieldLabel>
                    <Input
                      id={`${part}-${line.id}`}
                      type="number"
                      min={0}
                      max={line.quantity}
                      value={rows[line.id]?.[part] ?? 0}
                      onChange={(event) => setPart(line, part, event.target.value)}
                    />
                  </Field>
                ))}
              </fieldset>
            </div>
          ))}
        </DialogBody>
        <DialogFooter>
          <Button type="button" variant="outline" onClick={onClose} disabled={pending}>
            {t('admin.actions.cancel')}
          </Button>
          <Button
            type="button"
            disabled={pending || items.length === 0}
            onClick={() => onSubmit(items)}
          >
            {t('admin.pages.orders.detail.returns.actions.receive')}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}

/**
 * Gives the money back: how much, and by what means. A return owed nothing
 * (a free gift sent back) is completed instead, with nothing to choose.
 *
 * The currency symbol comes from the caller — the operator's panel reads it
 * from the store it is looking at, and a seller has no currency of their own.
 * `refundTaxTotal` is the formatted tax inside `refundableTotal`, shown so a
 * merchant knows the pre-filled amount gives the tax back too.
 */
export function ReturnRefundDialog({
  refundableTotal,
  owesNothing,
  refundTaxTotal,
  currencySymbol,
  onClose,
  onSubmit,
  pending = false,
}: {
  refundableTotal: string
  /** True when the return is owed nothing, so it is completed rather than refunded. */
  owesNothing: boolean
  refundTaxTotal?: string
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
          <DialogTitle>
            {owesNothing
              ? t('admin.pages.orders.detail.returns.complete_title')
              : t('admin.pages.orders.detail.returns.refund_title')}
          </DialogTitle>
        </DialogHeader>
        <DialogBody className="flex flex-col gap-4">
          {owesNothing ? (
            <p className="text-muted-foreground text-base">
              {t('admin.pages.orders.detail.returns.nothing_owed')}
            </p>
          ) : (
            <>
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
                    step="any"
                    min="0"
                    value={amount}
                    onChange={(event) => setAmount(event.target.value)}
                  />
                </InputGroup>
                {refundTaxTotal && (
                  <FieldDescription>
                    {t('admin.pages.orders.detail.returns.refund_includes_tax', {
                      tax: refundTaxTotal,
                    })}
                  </FieldDescription>
                )}
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
            </>
          )}
        </DialogBody>
        <DialogFooter>
          <Button type="button" variant="outline" onClick={onClose} disabled={pending}>
            {t('admin.actions.cancel')}
          </Button>
          <Button
            type="button"
            disabled={pending}
            onClick={() => onSubmit({ refundMethod, amount: owesNothing ? undefined : amount })}
          >
            {owesNothing
              ? t('admin.pages.orders.detail.returns.actions.complete')
              : t('admin.pages.orders.detail.returns.actions.refund')}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}

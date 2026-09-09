import { type ReactNode, useState } from 'react'
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
import { Textarea } from '../ui/textarea'
import {
  type PostSaleSelection,
  type PostSaleUnit,
  QuantityPicker,
  selectedUnits,
} from './post-sale-fields'

/**
 * Opens a return: which units are coming back, why, and any note.
 *
 * `extraFields` is where a surface adds what only it can offer — the
 * operator's shelf picker, for instance — so the shape stays one component.
 * Shared by the operator's order page and the seller's.
 */
export function CreateReturnDialog({
  units,
  reasonField,
  extraFields,
  onClose,
  onSubmit,
  pending = false,
}: {
  units: PostSaleUnit[]
  /** The reason picker, wired to whichever vocabulary the caller reads. */
  reasonField?: ReactNode
  extraFields?: ReactNode
  onClose: () => void
  onSubmit: (params: {
    items: Array<{ fulfillment_item_id: string; quantity: number }>
    memo?: string
  }) => void
  pending?: boolean
}) {
  const { t } = useTranslation()
  const [selection, setSelection] = useState<PostSaleSelection>({})
  const [memo, setMemo] = useState('')

  const chosen = selectedUnits(selection)

  return (
    <Dialog open onOpenChange={(open) => !open && onClose()}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{t('admin.pages.orders.detail.returns.create_title')}</DialogTitle>
        </DialogHeader>
        <DialogBody className="flex flex-col gap-4">
          <QuantityPicker units={units} selection={selection} onChange={setSelection} />
          {reasonField}
          {extraFields}
          <Field>
            <FieldLabel htmlFor="return-memo">
              {t('admin.pages.orders.detail.returns.memo')}
            </FieldLabel>
            <Textarea
              id="return-memo"
              value={memo}
              onChange={(event) => setMemo(event.target.value)}
            />
          </Field>
        </DialogBody>
        <DialogFooter>
          <Button type="button" variant="outline" onClick={onClose} disabled={pending}>
            {t('admin.actions.cancel')}
          </Button>
          <Button
            type="button"
            disabled={chosen.length === 0 || pending}
            onClick={() =>
              onSubmit({
                items: chosen.map(([id, quantity]) => ({
                  fulfillment_item_id: id,
                  quantity,
                })),
                memo: memo.trim() || undefined,
              })
            }
          >
            {t('admin.pages.orders.detail.returns.actions.create')}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}

/** A line the claim can name, with what one unit of it cost. */
export type ClaimableLine = PostSaleUnit & {
  /** Unit price, used to default the refund to what was actually paid. */
  price?: string | null
}

/**
 * Reports a problem with a delivery: which lines, how many, and what to give
 * back for each.
 *
 * A claim is about what was bought rather than what shipped — goods that
 * never arrived are exactly what one is for — so the lines come from the
 * order, not from its fulfillments.
 */
export function CreateClaimDialog({
  lines,
  currencySymbol,
  reasonField,
  onClose,
  onSubmit,
  pending = false,
}: {
  lines: ClaimableLine[]
  currencySymbol: string
  reasonField?: ReactNode
  onClose: () => void
  onSubmit: (params: {
    items: Array<{
      line_item_id: string
      quantity: number
      description?: string
      refund_amount?: string
    }>
    memo?: string
  }) => void
  pending?: boolean
}) {
  const { t } = useTranslation()
  const [selection, setSelection] = useState<PostSaleSelection>({})
  const [amounts, setAmounts] = useState<Record<string, string>>({})
  const [memo, setMemo] = useState('')

  const chosen = selectedUnits(selection)

  return (
    <Dialog open onOpenChange={(open) => !open && onClose()}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{t('admin.pages.orders.detail.claims.create_title')}</DialogTitle>
        </DialogHeader>
        <DialogBody className="flex flex-col gap-4">
          <div className="flex flex-col gap-2">
            {lines.map((line) => {
              const chosenQuantity = selection[line.id] ?? 0

              return (
                <div key={line.id} className="flex flex-col gap-2 rounded-lg border p-3">
                  <div className="flex items-center justify-between gap-4">
                    <span className="min-w-0 truncate text-sm">{line.label}</span>
                    <Input
                      type="number"
                      min={0}
                      max={line.quantity}
                      className="w-20"
                      value={chosenQuantity}
                      aria-label={line.label}
                      onChange={(event) => {
                        const quantity = Math.max(
                          0,
                          Math.min(Number(event.target.value), line.quantity),
                        )
                        setSelection({ ...selection, [line.id]: quantity })
                        // Default the refund to what was paid for those units;
                        // the merchant can still overwrite it.
                        if (quantity > 0 && !amounts[line.id]) {
                          const unitPrice = Number(line.price)
                          if (Number.isFinite(unitPrice)) {
                            setAmounts((current) => ({
                              ...current,
                              [line.id]: (unitPrice * quantity).toFixed(2),
                            }))
                          }
                        }
                      }}
                    />
                  </div>
                  {chosenQuantity > 0 && (
                    <Field>
                      <FieldLabel htmlFor={`claim-amount-${line.id}`}>
                        {t('admin.pages.orders.detail.claims.refund_amount')}
                      </FieldLabel>
                      <InputGroup>
                        <InputGroupAddon>
                          <InputGroupText>{currencySymbol}</InputGroupText>
                        </InputGroupAddon>
                        <InputGroupInput
                          id={`claim-amount-${line.id}`}
                          type="number"
                          step="0.01"
                          min="0"
                          value={amounts[line.id] ?? ''}
                          onChange={(event) =>
                            setAmounts({ ...amounts, [line.id]: event.target.value })
                          }
                        />
                      </InputGroup>
                    </Field>
                  )}
                </div>
              )
            })}
          </div>

          {reasonField}
          <Field>
            <FieldLabel htmlFor="claim-memo">
              {t('admin.pages.orders.detail.returns.memo')}
            </FieldLabel>
            <Textarea
              id="claim-memo"
              value={memo}
              onChange={(event) => setMemo(event.target.value)}
            />
          </Field>
        </DialogBody>
        <DialogFooter>
          <Button type="button" variant="outline" onClick={onClose} disabled={pending}>
            {t('admin.actions.cancel')}
          </Button>
          <Button
            type="button"
            disabled={chosen.length === 0 || pending}
            onClick={() =>
              onSubmit({
                items: chosen.map(([id, quantity]) => ({
                  line_item_id: id,
                  quantity,
                  refund_amount: amounts[id] || undefined,
                })),
                memo: memo.trim() || undefined,
              })
            }
          >
            {t('admin.pages.orders.detail.claims.actions.create')}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}

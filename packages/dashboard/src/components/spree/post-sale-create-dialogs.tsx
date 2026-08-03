import type { Order } from '@spree/admin-sdk'
import {
  Button,
  Dialog,
  DialogBody,
  DialogContent,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  Field,
  FieldLabel,
  Input,
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
  Textarea,
} from '@spree/dashboard-ui'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'

/** A fulfilled unit the customer could send back. */
export type FulfilledUnit = {
  id: string
  label: string
  quantity: number
}

/**
 * Every fulfilled unit on the order, flattened out of its fulfillments —
 * a return or exchange is against a shipped unit, not a line item.
 */
export function fulfilledUnits(order: Order): FulfilledUnit[] {
  return (order.fulfillments ?? []).flatMap((fulfillment) =>
    (fulfillment.fulfillment_items ?? []).map((item) => ({
      id: item.id,
      label: [item.name, item.options_text].filter(Boolean).join(' — ') || item.id,
      quantity: item.quantity,
    })),
  )
}

type Selection = Record<string, number>

/** Shared item picker: a quantity per unit, zero meaning "not included". */
function QuantityPicker({
  units,
  selection,
  onChange,
}: {
  units: Array<{ id: string; label: string; quantity: number }>
  selection: Selection
  onChange: (selection: Selection) => void
}) {
  return (
    <div className="flex flex-col gap-2">
      {units.map((unit) => (
        <div
          key={unit.id}
          className="flex items-center justify-between gap-4 rounded-lg border p-3"
        >
          <span className="text-sm truncate">{unit.label}</span>
          <Input
            type="number"
            min={0}
            max={unit.quantity}
            className="w-20"
            value={selection[unit.id] ?? 0}
            onChange={(event) =>
              onChange({
                ...selection,
                [unit.id]: Math.max(0, Math.min(Number(event.target.value), unit.quantity)),
              })
            }
          />
        </div>
      ))}
    </div>
  )
}

function selectedItems(selection: Selection): Array<[string, number]> {
  return Object.entries(selection).filter(([, quantity]) => quantity > 0)
}

export function CreateReturnDialog({
  order,
  onClose,
  onSubmit,
}: {
  order: Order
  onClose: () => void
  onSubmit: (params: {
    items: Array<{ fulfillment_item_id: string; quantity: number }>
    memo?: string
  }) => void
}) {
  const { t } = useTranslation()
  const units = fulfilledUnits(order)
  const [selection, setSelection] = useState<Selection>({})
  const [memo, setMemo] = useState('')

  const chosen = selectedItems(selection)

  return (
    <Dialog open onOpenChange={(open) => !open && onClose()}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{t('admin.pages.orders.detail.returns.create_title')}</DialogTitle>
        </DialogHeader>
        <DialogBody className="flex flex-col gap-4">
          <QuantityPicker units={units} selection={selection} onChange={setSelection} />
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
          <Button variant="outline" onClick={onClose}>
            {t('admin.actions.cancel')}
          </Button>
          <Button
            disabled={chosen.length === 0}
            onClick={() =>
              onSubmit({
                items: chosen.map(([id, quantity]) => ({
                  fulfillment_item_id: id,
                  quantity,
                })),
                memo: memo || undefined,
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

/**
 * An exchange needs a replacement variant per unit. The variant is entered by
 * prefixed id rather than picked from a catalog browser — a full product
 * picker is worth building, but this keeps the flow usable meanwhile.
 */
export function CreateExchangeDialog({
  order,
  onClose,
  onSubmit,
}: {
  order: Order
  onClose: () => void
  onSubmit: (params: {
    items: Array<{ fulfillment_item_id: string; new_variant_id: string; quantity: number }>
    memo?: string
  }) => void
}) {
  const { t } = useTranslation()
  const units = fulfilledUnits(order)
  const [selection, setSelection] = useState<Selection>({})
  const [replacements, setReplacements] = useState<Record<string, string>>({})
  const [memo, setMemo] = useState('')

  const chosen = selectedItems(selection)
  const ready = chosen.length > 0 && chosen.every(([id]) => replacements[id]?.trim())

  return (
    <Dialog open onOpenChange={(open) => !open && onClose()}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{t('admin.pages.orders.detail.exchanges.create_title')}</DialogTitle>
        </DialogHeader>
        <DialogBody className="flex flex-col gap-4">
          {units.map((unit) => (
            <div key={unit.id} className="flex flex-col gap-2 rounded-lg border p-3">
              <div className="flex items-center justify-between gap-4">
                <span className="text-sm truncate">{unit.label}</span>
                <Input
                  type="number"
                  min={0}
                  max={unit.quantity}
                  className="w-20"
                  value={selection[unit.id] ?? 0}
                  onChange={(event) =>
                    setSelection({
                      ...selection,
                      [unit.id]: Math.max(0, Math.min(Number(event.target.value), unit.quantity)),
                    })
                  }
                />
              </div>
              {(selection[unit.id] ?? 0) > 0 && (
                <Field>
                  <FieldLabel htmlFor={`replacement-${unit.id}`}>
                    {t('admin.pages.orders.detail.exchanges.replacement_variant')}
                  </FieldLabel>
                  <Input
                    id={`replacement-${unit.id}`}
                    placeholder="variant_..."
                    value={replacements[unit.id] ?? ''}
                    onChange={(event) =>
                      setReplacements({ ...replacements, [unit.id]: event.target.value })
                    }
                  />
                </Field>
              )}
            </div>
          ))}
          <Field>
            <FieldLabel htmlFor="exchange-memo">
              {t('admin.pages.orders.detail.returns.memo')}
            </FieldLabel>
            <Textarea
              id="exchange-memo"
              value={memo}
              onChange={(event) => setMemo(event.target.value)}
            />
          </Field>
        </DialogBody>
        <DialogFooter>
          <Button variant="outline" onClick={onClose}>
            {t('admin.actions.cancel')}
          </Button>
          <Button
            disabled={!ready}
            onClick={() =>
              onSubmit({
                items: chosen.map(([id, quantity]) => ({
                  fulfillment_item_id: id,
                  new_variant_id: replacements[id].trim(),
                  quantity,
                })),
                memo: memo || undefined,
              })
            }
          >
            {t('admin.pages.orders.detail.exchanges.actions.create')}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}

const CLAIM_TYPES = ['damaged', 'missing', 'wrong_item', 'other'] as const

/** A claim is against ordered line items — nothing has to have shipped. */
export function CreateClaimDialog({
  order,
  onClose,
  onSubmit,
}: {
  order: Order
  onClose: () => void
  onSubmit: (params: {
    items: Array<{
      line_item_id: string
      quantity: number
      description?: string
      refund_amount?: string
    }>
    claim_type: string
    memo?: string
  }) => void
}) {
  const { t } = useTranslation()
  const items = order.items ?? []
  const [selection, setSelection] = useState<Selection>({})
  const [amounts, setAmounts] = useState<Record<string, string>>({})
  const [claimType, setClaimType] = useState<string>('damaged')
  const [memo, setMemo] = useState('')

  const chosen = selectedItems(selection)
  const typeOptions = CLAIM_TYPES.map((value) => ({
    value,
    label: t(`admin.pages.orders.detail.claims.types.${value}`),
  }))

  return (
    <Dialog open onOpenChange={(open) => !open && onClose()}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{t('admin.pages.orders.detail.claims.create_title')}</DialogTitle>
        </DialogHeader>
        <DialogBody className="flex flex-col gap-4">
          <Field>
            <FieldLabel htmlFor="claim-type">
              {t('admin.pages.orders.detail.claims.claim_type')}
            </FieldLabel>
            <Select items={typeOptions} value={claimType} onValueChange={setClaimType}>
              <SelectTrigger id="claim-type">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {typeOptions.map((option) => (
                  <SelectItem key={option.value} value={option.value}>
                    {option.label}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </Field>

          <div className="flex flex-col gap-2">
            {items.map((item) => {
              const label = [item.name, item.options_text].filter(Boolean).join(' — ') || item.id
              const chosenQuantity = selection[item.id] ?? 0

              return (
                <div key={item.id} className="flex flex-col gap-2 rounded-lg border p-3">
                  <div className="flex items-center justify-between gap-4">
                    <span className="text-sm truncate">{label}</span>
                    <Input
                      type="number"
                      min={0}
                      max={item.quantity}
                      className="w-20"
                      value={chosenQuantity}
                      onChange={(event) => {
                        const quantity = Math.max(
                          0,
                          Math.min(Number(event.target.value), item.quantity),
                        )
                        setSelection({ ...selection, [item.id]: quantity })
                        // Default the refund to what was paid for those units;
                        // the merchant can still overwrite it.
                        if (quantity > 0 && !amounts[item.id]) {
                          const unitPrice = Number(item.price)
                          if (Number.isFinite(unitPrice)) {
                            setAmounts((current) => ({
                              ...current,
                              [item.id]: (unitPrice * quantity).toFixed(2),
                            }))
                          }
                        }
                      }}
                    />
                  </div>
                  {chosenQuantity > 0 && (
                    <Field>
                      <FieldLabel htmlFor={`claim-amount-${item.id}`}>
                        {t('admin.pages.orders.detail.claims.refund_amount')}
                      </FieldLabel>
                      <Input
                        id={`claim-amount-${item.id}`}
                        value={amounts[item.id] ?? ''}
                        onChange={(event) =>
                          setAmounts({ ...amounts, [item.id]: event.target.value })
                        }
                      />
                    </Field>
                  )}
                </div>
              )
            })}
          </div>

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
          <Button variant="outline" onClick={onClose}>
            {t('admin.actions.cancel')}
          </Button>
          <Button
            disabled={chosen.length === 0}
            onClick={() =>
              onSubmit({
                items: chosen.map(([id, quantity]) => ({
                  line_item_id: id,
                  quantity,
                  refund_amount: amounts[id] || undefined,
                })),
                claim_type: claimType,
                memo: memo || undefined,
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

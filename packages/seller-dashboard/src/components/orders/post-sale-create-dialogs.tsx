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
import type { Order } from '@spree/seller-sdk'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { useClaimActions, useReturnActions } from '../../hooks/use-post-sale'
import { type ReasonKind, useReasons } from '../../hooks/use-reasons'

/** Units that actually went out, which is all that can come back. */
export function fulfilledUnits(order: Order) {
  return (order.fulfillments ?? []).flatMap((fulfillment) =>
    (fulfillment.fulfillment_items ?? []).map((item) => ({
      id: item.id,
      label: [item.name, item.options_text].filter(Boolean).join(' — ') || item.id,
      quantity: item.quantity,
    })),
  )
}

type Selection = Record<string, number>

/** A quantity per unit; zero means "not included". */
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
        <div key={unit.id} className="flex items-center justify-between gap-3">
          <span className="min-w-0 truncate text-sm">{unit.label}</span>
          <Input
            type="number"
            min={0}
            max={unit.quantity}
            value={selection[unit.id] ?? 0}
            className="w-20"
            aria-label={unit.label}
            onChange={(event) =>
              onChange({
                ...selection,
                [unit.id]: Math.max(0, Math.min(unit.quantity, Number(event.target.value))),
              })
            }
          />
        </div>
      ))}
    </div>
  )
}

/**
 * The reason picker. Optional by design — the API takes a record without one,
 * so a marketplace that has not filled in its vocabulary yet is not blocked.
 */
function ReasonField({
  kind,
  value,
  onChange,
}: {
  kind: ReasonKind
  value: string
  onChange: (value: string) => void
}) {
  const { t } = useTranslation()
  const { data } = useReasons(kind)

  const reasons = data?.data ?? []
  if (reasons.length === 0) return null

  const options = reasons.map((reason) => ({ value: reason.id, label: reason.name }))

  return (
    <Field>
      <FieldLabel htmlFor={`reason-${kind}`}>{t('orders.post_sale.reason')}</FieldLabel>
      <Select
        items={options}
        value={value}
        onValueChange={(next) => onChange((next as string) ?? '')}
      >
        <SelectTrigger id={`reason-${kind}`}>
          <SelectValue />
        </SelectTrigger>
        <SelectContent>
          {options.map((option) => (
            <SelectItem key={option.value} value={option.value}>
              {option.label}
            </SelectItem>
          ))}
        </SelectContent>
      </Select>
    </Field>
  )
}

function selectedItems(selection: Selection) {
  return Object.entries(selection)
    .filter(([, quantity]) => quantity > 0)
    .map(([id, quantity]) => ({ id, quantity }))
}

export function CreateReturnDialog({
  order,
  open,
  onOpenChange,
}: {
  order: Order
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const { create } = useReturnActions(order.id)
  const units = fulfilledUnits(order)

  const [selection, setSelection] = useState<Selection>({})
  const [reasonId, setReasonId] = useState('')
  const [memo, setMemo] = useState('')

  const chosen = selectedItems(selection)

  async function handleCreate() {
    await create
      .mutateAsync({
        items: chosen.map((item) => ({ fulfillment_item_id: item.id, quantity: item.quantity })),
        reason_id: reasonId || undefined,
        memo: memo.trim() || undefined,
      })
      .then(() => {
        setSelection({})
        setMemo('')
        onOpenChange(false)
      })
      .catch(() => undefined)
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{t('orders.post_sale.returns.create_title')}</DialogTitle>
        </DialogHeader>
        <DialogBody>
          <div className="flex flex-col gap-4">
            <QuantityPicker units={units} selection={selection} onChange={setSelection} />
            <ReasonField kind="return-reasons" value={reasonId} onChange={setReasonId} />
            <Field>
              <FieldLabel htmlFor="return-memo">{t('orders.post_sale.memo')}</FieldLabel>
              <Textarea
                id="return-memo"
                value={memo}
                onChange={(event) => setMemo(event.target.value)}
              />
            </Field>
          </div>
        </DialogBody>
        <DialogFooter>
          <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>
            {t('common.cancel')}
          </Button>
          <Button
            type="button"
            disabled={chosen.length === 0 || create.isPending}
            onClick={handleCreate}
          >
            {t('orders.post_sale.returns.create')}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}

export function CreateClaimDialog({
  order,
  open,
  onOpenChange,
}: {
  order: Order
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const { create } = useClaimActions(order.id)

  // A claim is about what was bought, not about what shipped — goods that
  // never arrived are exactly what one is for.
  const units = (order.items ?? []).map((item) => ({
    id: item.id,
    label: [item.name, item.options_text].filter(Boolean).join(' — ') || item.id,
    quantity: item.quantity,
  }))

  const [selection, setSelection] = useState<Selection>({})
  const [reasonId, setReasonId] = useState('')
  const [description, setDescription] = useState('')

  const chosen = selectedItems(selection)

  async function handleCreate() {
    await create
      .mutateAsync({
        items: chosen.map((item) => ({
          line_item_id: item.id,
          quantity: item.quantity,
          description: description.trim() || undefined,
        })),
        reason_id: reasonId || undefined,
      })
      .then(() => {
        setSelection({})
        setDescription('')
        onOpenChange(false)
      })
      .catch(() => undefined)
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{t('orders.post_sale.claims.create_title')}</DialogTitle>
        </DialogHeader>
        <DialogBody>
          <div className="flex flex-col gap-4">
            <QuantityPicker units={units} selection={selection} onChange={setSelection} />
            <ReasonField kind="claim-reasons" value={reasonId} onChange={setReasonId} />
            <Field>
              <FieldLabel htmlFor="claim-description">
                {t('orders.post_sale.claims.description')}
              </FieldLabel>
              <Textarea
                id="claim-description"
                value={description}
                onChange={(event) => setDescription(event.target.value)}
              />
            </Field>
          </div>
        </DialogBody>
        <DialogFooter>
          <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>
            {t('common.cancel')}
          </Button>
          <Button
            type="button"
            disabled={chosen.length === 0 || create.isPending}
            onClick={handleCreate}
          >
            {t('orders.post_sale.claims.create')}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}

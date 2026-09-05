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
  QuantityPicker,
  ReasonField,
  type PostSaleSelection as Selection,
  selectedUnits as selectedItems,
  Textarea,
} from '@spree/dashboard-ui'
import type { Order } from '@spree/seller-sdk'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { useClaimActions, useReturnActions } from '../../hooks/use-post-sale'
import { useReasons } from '../../hooks/use-reasons'
import { unitLabel } from './line-label'

/** Units that actually went out, which is all that can come back. */
export function fulfilledUnits(order: Order) {
  return (order.fulfillments ?? []).flatMap((fulfillment) =>
    (fulfillment.fulfillment_items ?? []).map((item) => ({
      id: item.id,
      label: unitLabel(item),
      quantity: item.quantity,
    })),
  )
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
        items: chosen.map(([id, quantity]) => ({ fulfillment_item_id: id, quantity })),
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
            <ReturnReasonField value={reasonId} onChange={setReasonId} />
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
    label: unitLabel(item),
    quantity: item.quantity,
  }))

  const [selection, setSelection] = useState<Selection>({})
  const [reasonId, setReasonId] = useState('')
  const [description, setDescription] = useState('')

  const chosen = selectedItems(selection)

  async function handleCreate() {
    await create
      .mutateAsync({
        items: chosen.map(([id, quantity]) => ({
          line_item_id: id,
          quantity,
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
            <ClaimReasonField value={reasonId} onChange={setReasonId} />
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

/**
 * The seller picks from the marketplace's vocabulary — the operator decides
 * what the reasons are, so this reads the store's list rather than one of the
 * seller's own.
 */
function ReturnReasonField({
  value,
  onChange,
}: {
  value: string
  onChange: (value: string) => void
}) {
  const { t } = useTranslation()
  const { data } = useReasons('return-reasons')

  return (
    <ReasonField
      id="return"
      reasons={(data?.data ?? []).filter((reason) => reason.active)}
      value={value}
      onChange={onChange}
      label={t('orders.post_sale.reason')}
    />
  )
}

function ClaimReasonField({
  value,
  onChange,
}: {
  value: string
  onChange: (value: string) => void
}) {
  const { t } = useTranslation()
  const { data } = useReasons('claim-reasons')

  return (
    <ReasonField
      id="claim"
      reasons={(data?.data ?? []).filter((reason) => reason.active)}
      value={value}
      onChange={onChange}
      label={t('orders.post_sale.reason')}
    />
  )
}

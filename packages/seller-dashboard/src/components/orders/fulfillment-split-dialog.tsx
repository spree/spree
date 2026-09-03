import {
  Button,
  Dialog,
  DialogBody,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  Field,
  FieldError,
  FieldLabel,
  Input,
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
  useConfirm,
} from '@spree/dashboard-ui'
import type { Fulfillment } from '@spree/seller-sdk'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { useFulfillmentActions } from '../../hooks/use-fulfillments'
import { unitLabel } from './line-label'

/**
 * Moves part of a parcel onto one of its own, for goods leaving separately.
 *
 * One variant at a time, which is the granularity the transfer works at —
 * splitting several apart is several splits.
 */
export function FulfillmentSplitDialog({
  orderId,
  fulfillment,
  open,
  onOpenChange,
}: {
  orderId: string
  fulfillment: Fulfillment
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const confirm = useConfirm()
  const { split } = useFulfillmentActions(orderId)

  const units = (fulfillment.fulfillment_items ?? []).map((item) => ({
    value: item.variant_id ?? item.id,
    label: unitLabel(item),
    quantity: item.quantity,
  }))

  const [variantId, setVariantId] = useState(units[0]?.value ?? '')
  const [quantity, setQuantity] = useState(1)

  const selected = units.find((unit) => unit.value === variantId)
  const totalUnits = units.reduce((total, unit) => total + unit.quantity, 0)
  // Moving everything is not a split — it empties the parcel and leaves an
  // orphan behind, which is never what was meant.
  const wouldEmpty = quantity >= totalUnits
  const invalid = !variantId || quantity < 1 || wouldEmpty || quantity > (selected?.quantity ?? 0)

  async function handleSplit() {
    const ok = await confirm({
      title: t('orders.fulfillments.split_title'),
      message: t('orders.fulfillments.confirm_split'),
      confirmLabel: t('orders.fulfillments.split'),
    })
    if (!ok) return

    await split
      .mutateAsync({ fulfillmentId: fulfillment.id, variant_id: variantId, quantity })
      .then(() => onOpenChange(false))
      .catch(() => undefined)
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{t('orders.fulfillments.split_title')}</DialogTitle>
          <DialogDescription>{t('orders.fulfillments.split_description')}</DialogDescription>
        </DialogHeader>

        <DialogBody>
          <div className="flex flex-col gap-4">
            <Field>
              <FieldLabel htmlFor="split-variant">{t('orders.fulfillments.split_item')}</FieldLabel>
              <Select
                items={units}
                value={variantId}
                onValueChange={(value) => setVariantId((value as string) ?? '')}
              >
                <SelectTrigger id="split-variant">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {units.map((unit) => (
                    <SelectItem key={unit.value} value={unit.value}>
                      {unit.label}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </Field>

            <Field>
              <FieldLabel htmlFor="split-quantity">
                {t('orders.fulfillments.split_quantity')}
              </FieldLabel>
              <Input
                id="split-quantity"
                type="number"
                min={1}
                max={selected?.quantity ?? 1}
                value={quantity}
                onChange={(event) => setQuantity(Number(event.target.value))}
              />
              {wouldEmpty && <FieldError>{t('orders.fulfillments.split_would_empty')}</FieldError>}
            </Field>
          </div>
        </DialogBody>

        <DialogFooter>
          <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>
            {t('common.cancel')}
          </Button>
          <Button type="button" disabled={invalid || split.isPending} onClick={handleSplit}>
            {split.isPending ? t('orders.fulfillments.splitting') : t('orders.fulfillments.split')}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}

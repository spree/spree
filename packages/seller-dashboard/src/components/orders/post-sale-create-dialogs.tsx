import { currencyParts } from '@spree/dashboard-core'
import {
  Field,
  FieldLabel,
  ReasonField,
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
  CreateClaimDialog as SharedCreateClaimDialog,
  CreateReturnDialog as SharedCreateReturnDialog,
} from '@spree/dashboard-ui'
import type { Order } from '@spree/seller-sdk'
import i18n from 'i18next'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { useClaimActions, useReturnActions } from '../../hooks/use-post-sale'
import { useReasons } from '../../hooks/use-reasons'
import { useStockLocations } from '../../hooks/use-stock-locations'
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

/**
 * Takes goods back on one of this seller's orders.
 *
 * The shelf list is the seller's own, so a marketplace warehouse never
 * appears — and the server refuses one anyway. Shelves that accept returns
 * lead, the rest stay selectable, since a one-off return has to be routable
 * somewhere even when none is flagged.
 */
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
  const [reasonId, setReasonId] = useState('')
  const [stockLocationId, setStockLocationId] = useState('')
  const { data: locationsData } = useStockLocations(open)

  const locationOptions = (locationsData?.data ?? [])
    .filter((location) => location.active)
    .sort((a, b) => Number(b.returns_enabled) - Number(a.returns_enabled))
    .map((location) => ({
      value: location.id,
      label: location.returns_enabled
        ? location.name
        : t('admin.pages.orders.detail.returns.location_no_returns', { name: location.name }),
    }))

  if (!open) return null

  return (
    <SharedCreateReturnDialog
      units={fulfilledUnits(order)}
      reasonField={<ReturnReasonField value={reasonId} onChange={setReasonId} />}
      extraFields={
        <Field>
          <FieldLabel htmlFor="return-location">
            {t('admin.pages.orders.detail.returns.location')}
          </FieldLabel>
          <Select
            items={locationOptions}
            value={stockLocationId}
            onValueChange={(value) => setStockLocationId((value as string) ?? '')}
          >
            <SelectTrigger id="return-location">
              <SelectValue placeholder={t('admin.pages.orders.detail.returns.location_default')} />
            </SelectTrigger>
            <SelectContent>
              {locationOptions.map((option) => (
                <SelectItem key={option.value} value={option.value}>
                  {option.label}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        </Field>
      }
      onClose={() => onOpenChange(false)}
      pending={create.isPending}
      onSubmit={({ items, memo }) => {
        create
          .mutateAsync({
            items,
            memo,
            reason_id: reasonId || undefined,
            stock_location_id: stockLocationId || undefined,
          })
          .then(() => onOpenChange(false))
          .catch(() => undefined)
      }}
    />
  )
}

/**
 * Reports a problem with a delivery on one of this seller's orders.
 *
 * The lines come from the order rather than its parcels: a claim is about
 * what was bought, and goods that never arrived are exactly what one is for.
 */
export function CreateClaimDialog({
  order,
  open,
  onOpenChange,
}: {
  order: Order
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { create } = useClaimActions(order.id)
  const [reasonId, setReasonId] = useState('')
  const { symbol: currencySymbol } = currencyParts(order.currency, i18n.language)

  if (!open) return null

  return (
    <SharedCreateClaimDialog
      lines={(order.items ?? []).map((item) => ({
        id: item.id,
        label: unitLabel(item),
        quantity: item.quantity,
        price: item.price,
      }))}
      currencySymbol={currencySymbol}
      reasonField={<ClaimReasonField value={reasonId} onChange={setReasonId} />}
      onClose={() => onOpenChange(false)}
      pending={create.isPending}
      onSubmit={({ items, memo }) => {
        create
          .mutateAsync({ items, memo, reason_id: reasonId || undefined })
          .then(() => onOpenChange(false))
          .catch(() => undefined)
      }}
    />
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

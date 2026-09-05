import type { Claim, Order, Variant } from '@spree/admin-sdk'
import {
  adminClient,
  currencyParts,
  ResourceCombobox,
  useStockLocations,
  useStore,
} from '@spree/dashboard-core'
import {
  Button,
  type ClaimResolution,
  ClaimResolveDialog,
  Dialog,
  DialogBody,
  DialogContent,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  Field,
  FieldLabel,
  Input,
  type RefundMethod,
  Select,
  SelectContent,
  SelectItem,
  type PostSaleSelection as Selection,
  SelectTrigger,
  SelectValue,
  CreateClaimDialog as SharedCreateClaimDialog,
  CreateReturnDialog as SharedCreateReturnDialog,
  selectedUnits as selectedItems,
  Textarea,
} from '@spree/dashboard-ui'
import i18n from 'i18next'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { ReasonField } from './reason-field'

/** A fulfilled unit the customer could send back. */
export type FulfilledUnit = {
  id: string
  label: string
  quantity: number
}

/**
 * Every unit on the order, flattened out of its fulfillments. A return or
 * exchange is against a fulfillment item rather than a line item, but it does
 * not require the goods to have shipped — the backend only asks that the
 * order is complete and not canceled, and a merchant may well open a return
 * on something still in the warehouse.
 */
/** `id` always comes back, so it need not be listed. */
const VARIANT_PICKER_FIELDS = ['product_name', 'sku', 'options_text']

export function fulfilledUnits(order: Order): FulfilledUnit[] {
  return (order.fulfillments ?? []).flatMap((fulfillment) =>
    (fulfillment.fulfillment_items ?? []).map((item) => ({
      id: item.id,
      label: [item.name, item.options_text].filter(Boolean).join(' — ') || item.id,
      quantity: item.quantity,
    })),
  )
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
    reasonId?: string
    stockLocationId?: string
  }) => void
}) {
  const { t } = useTranslation()
  const [reasonId, setReasonId] = useState('')
  const [stockLocationId, setStockLocationId] = useState('')
  const { data: stockLocationData } = useStockLocations()

  // Locations that accept returns lead, and one of them is the default: a
  // merchant sending goods anywhere else is making a deliberate exception.
  // The rest stay selectable, since a one-off return has to be routable
  // somewhere even when no location is flagged.
  const locationOptions = (stockLocationData?.data ?? [])
    .filter((location) => location.active)
    // A location that predates the flag accepts returns, which is how goods
    // behaved before it existed — the same default the form applies.
    .sort((a, b) => Number(b.returns_enabled ?? true) - Number(a.returns_enabled ?? true))
    .map((location) => ({
      value: location.id,
      label:
        (location.returns_enabled ?? true)
          ? location.name
          : t('admin.pages.orders.detail.returns.location_no_returns', { name: location.name }),
    }))

  return (
    <SharedCreateReturnDialog
      units={fulfilledUnits(order)}
      reasonField={<ReasonField kind="return-reasons" value={reasonId} onChange={setReasonId} />}
      extraFields={
        <Field>
          <FieldLabel htmlFor="return-location">
            {t('admin.pages.orders.detail.returns.location')}
          </FieldLabel>
          <Select
            items={locationOptions}
            value={stockLocationId}
            onValueChange={(value) => setStockLocationId(value as string)}
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
      onClose={onClose}
      onSubmit={({ items, memo }) =>
        onSubmit({
          items,
          memo,
          reasonId: reasonId || undefined,
          stockLocationId: stockLocationId || undefined,
        })
      }
    />
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
    reasonId?: string
  }) => void
}) {
  const { t } = useTranslation()
  const units = fulfilledUnits(order)
  const [selection, setSelection] = useState<Selection>({})
  const [replacements, setReplacements] = useState<Record<string, string>>({})
  const [memo, setMemo] = useState('')
  const [reasonId, setReasonId] = useState('')

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
                  <ResourceCombobox<Variant>
                    queryKey={`exchange-replacement-${unit.id}`}
                    value={replacements[unit.id] ?? ''}
                    onChange={(id) => setReplacements({ ...replacements, [unit.id]: id ?? '' })}
                    // Only what the option renders. This trims the response;
                    // the server still computes the rest.
                    search={(query) =>
                      adminClient.variants.list({
                        search: query,
                        limit: 8,
                        fields: VARIANT_PICKER_FIELDS,
                      })
                    }
                    hydrate={(ids) =>
                      adminClient.variants.list({
                        id_in: ids,
                        limit: ids.length,
                        fields: VARIANT_PICKER_FIELDS,
                      })
                    }
                    getOptionLabel={(variant) => variant.product_name ?? variant.sku ?? variant.id}
                    renderOption={(variant) => (
                      <div className="flex flex-col">
                        <span className="font-medium">
                          {variant.product_name ?? variant.sku ?? variant.id}
                        </span>
                        <span className="text-xs text-muted-foreground">
                          {variant.options_text && <span>{variant.options_text} · </span>}
                          {t('admin.orders.detail.variant_search.sku_prefix')}: {variant.sku || '—'}
                        </span>
                      </div>
                    )}
                  />
                </Field>
              )}
            </div>
          ))}
          <ReasonField kind="return-reasons" value={reasonId} onChange={setReasonId} />
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
                reasonId: reasonId || undefined,
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
    memo?: string
    reasonId?: string
  }) => void
}) {
  const [reasonId, setReasonId] = useState('')
  const { defaultCurrency } = useStore()
  const { symbol: currencySymbol } = currencyParts(defaultCurrency, i18n.language)

  return (
    <SharedCreateClaimDialog
      lines={(order.items ?? []).map((item) => ({
        id: item.id,
        label: [item.name, item.options_text].filter(Boolean).join(' — ') || item.id,
        quantity: item.quantity,
        price: item.price,
      }))}
      currencySymbol={currencySymbol}
      reasonField={<ReasonField kind="claim-reasons" value={reasonId} onChange={setReasonId} />}
      onClose={onClose}
      onSubmit={({ items, memo }) => onSubmit({ items, memo, reasonId: reasonId || undefined })}
    />
  )
}

export function ResolveClaimDialog({
  claim,
  onClose,
  onSubmit,
}: {
  claim: Claim
  onClose: () => void
  onSubmit: (params: {
    resolution: ClaimResolution
    refundMethod: RefundMethod
    amount?: string
    replacementLineItemIds: string[]
  }) => void
}) {
  const lines = claim.claim_line_items ?? []
  const { defaultCurrency } = useStore()
  const { symbol: currencySymbol } = currencyParts(defaultCurrency, i18n.language)

  // A claim opened without per-item amounts has a refund_total of zero, and
  // the workflow refuses to refund nothing — offer what the customer paid for
  // the claimed items instead, which is also the ceiling it enforces.
  const recorded = Number(claim.refund_total)
  const paid = lines.reduce((sum, line) => sum + Number(line.paid_amount ?? 0), 0)
  const defaultAmount =
    Number.isFinite(recorded) && recorded > 0
      ? claim.refund_total
      : paid > 0
        ? paid.toFixed(2)
        : claim.refund_total

  return (
    <ClaimResolveDialog
      lines={lines.map((line) => ({
        id: line.id,
        label: line.variant?.product_name ?? line.variant_id ?? line.id,
        quantity: line.quantity,
        sendReplacement: line.send_replacement,
      }))}
      defaultAmount={defaultAmount}
      currencySymbol={currencySymbol}
      onClose={onClose}
      onSubmit={onSubmit}
    />
  )
}

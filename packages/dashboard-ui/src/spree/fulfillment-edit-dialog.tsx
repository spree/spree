import { useEffect, useRef, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { Button } from '../ui/button'
import {
  Dialog,
  DialogBody,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '../ui/dialog'
import { Field, FieldError, FieldLabel } from '../ui/field'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '../ui/select'

/** A shelf a parcel can ship from, already labelled by the caller. */
export type FulfillmentOriginOption = {
  value: string
  label: string
}

/** A priced service the parcel can be carried by, already labelled. */
export type FulfillmentRateOption = {
  value: string
  label: string
}

export type FulfillmentEditValues = {
  stockLocationId: string
  selectedDeliveryRateId: string
}

/**
 * Where a parcel ships from and which priced service carries it.
 *
 * The two fields are coupled: rates are quoted against an origin, so moving
 * the parcel invalidates the list on screen. Rather than offering stale
 * options, a save that changes the origin writes the location first and the
 * method field stands down until the caller re-quotes — which is why
 * `onSubmit` reports *which* fields changed and the caller decides the order
 * of writes.
 *
 * Headless: both panels label their own options (the operator marks shelves
 * that cannot cover the parcel; a seller sees only their own), and both own
 * their mutations. This holds the shape and the coupling rule so the two
 * cannot drift.
 */
export function FulfillmentEditDialog({
  open,
  onOpenChange,
  originOptions,
  rateOptions,
  currentOriginId,
  currentRateId,
  onSubmit,
  pending = false,
  errorMessage,
}: {
  open: boolean
  onOpenChange: (open: boolean) => void
  originOptions: FulfillmentOriginOption[]
  rateOptions: FulfillmentRateOption[]
  currentOriginId: string
  currentRateId: string
  /**
   * Applies the change. Returning `'requote'` keeps the dialog open and
   * re-seeds it from the caller's refreshed record — the origin moved, so the
   * rates on screen described a route the parcel has left.
   */
  onSubmit: (
    values: FulfillmentEditValues,
    changed: { origin: boolean; rate: boolean },
  ) => Promise<'requote' | 'done'>
  pending?: boolean
  errorMessage?: string
}) {
  const { t } = useTranslation()

  const [originId, setOriginId] = useState(currentOriginId)
  const [rateId, setRateId] = useState(currentRateId)

  // A re-quote lands as a changed record: the caller has moved the parcel and
  // the server has re-selected a method for the new origin. Adopt that pick,
  // so the second save confirms a rate that actually applies rather than
  // re-sending the one quoted for the origin the parcel just left.
  const seededOrigin = useRef(currentOriginId)
  useEffect(() => {
    if (seededOrigin.current === currentOriginId) return
    seededOrigin.current = currentOriginId
    setOriginId(currentOriginId)
    setRateId(currentRateId)
  }, [currentOriginId, currentRateId])

  // The rates on the record were quoted for the origin it currently has. Once
  // a different one is picked they describe a route no longer on offer, so the
  // method field stands down until the server re-quotes.
  const originMoved = originId !== currentOriginId
  const originMissing = originId.length === 0

  async function handleSubmit(event: React.FormEvent) {
    // The order page renders its cards inside their own forms — without
    // stopping the bubble the browser submits the outer one.
    event.preventDefault()
    event.stopPropagation()
    if (originMissing) return

    const outcome = await onSubmit(
      { stockLocationId: originId, selectedDeliveryRateId: rateId },
      { origin: originMoved, rate: rateId !== currentRateId },
    )

    if (outcome === 'done') onOpenChange(false)
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <form onSubmit={handleSubmit}>
          <DialogHeader>
            <DialogTitle>{t('admin.orders.detail.fulfillments.edit_title')}</DialogTitle>
            <DialogDescription>
              {t('admin.orders.detail.fulfillments.edit_description')}
            </DialogDescription>
          </DialogHeader>

          <DialogBody className="flex flex-col gap-4">
            {errorMessage && (
              <p className="text-sm text-destructive" role="alert">
                {errorMessage}
              </p>
            )}

            <Field>
              <FieldLabel htmlFor="fulfillment-location">
                {t('admin.orders.detail.fulfillments.ships_from')}
              </FieldLabel>
              <Select
                items={originOptions}
                value={originId}
                onValueChange={(value) => setOriginId((value as string) ?? '')}
              >
                <SelectTrigger id="fulfillment-location">
                  <SelectValue placeholder={t('admin.common.select_placeholder')} />
                </SelectTrigger>
                <SelectContent>
                  {originOptions.map((option) => (
                    <SelectItem key={option.value} value={option.value}>
                      {option.label}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
              {originMissing && <FieldError>{t('admin.errors.required')}</FieldError>}
            </Field>

            <Field>
              <FieldLabel htmlFor="fulfillment-rate">
                {t('admin.orders.detail.fulfillments.delivery_method')}
              </FieldLabel>
              <Select
                items={rateOptions}
                value={rateId}
                disabled={originMoved || rateOptions.length === 0}
                onValueChange={(value) => setRateId((value as string) ?? '')}
              >
                <SelectTrigger id="fulfillment-rate">
                  <SelectValue placeholder={t('admin.common.select_placeholder')} />
                </SelectTrigger>
                <SelectContent>
                  {rateOptions.map((option) => (
                    <SelectItem key={option.value} value={option.value}>
                      {option.label}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
              {originMoved && (
                <span className="text-muted-foreground text-xs">
                  {t('admin.orders.detail.fulfillments.rates_pending_origin')}
                </span>
              )}
              {!originMoved && rateOptions.length === 0 && (
                <span className="text-muted-foreground text-xs">
                  {t('admin.orders.detail.fulfillments.no_rates')}
                </span>
              )}
            </Field>
          </DialogBody>

          <DialogFooter>
            <Button
              type="button"
              variant="outline"
              onClick={() => onOpenChange(false)}
              disabled={pending}
            >
              {t('admin.actions.cancel')}
            </Button>
            <Button type="submit" disabled={pending || originMissing}>
              {pending
                ? t('admin.actions.saving')
                : originMoved
                  ? t('admin.orders.detail.fulfillments.move_and_requote')
                  : t('admin.actions.save')}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  )
}

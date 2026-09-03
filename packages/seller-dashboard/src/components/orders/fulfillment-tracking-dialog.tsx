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
  FieldLabel,
  Input,
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@spree/dashboard-ui'
import type { Fulfillment } from '@spree/seller-sdk'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { useFulfillmentActions } from '../../hooks/use-fulfillments'
import { useTrackingCarriers } from '../../hooks/use-reasons'

/**
 * Adds or corrects a parcel's tracking number after it has gone out.
 *
 * Separate from marking it shipped: a seller who mistyped a number, or who
 * only got it from the post office afterwards, is not shipping the parcel
 * again.
 */
export function FulfillmentTrackingDialog({
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
  const { update } = useFulfillmentActions(orderId)
  const { data: carriersData } = useTrackingCarriers(open)

  const [tracking, setTracking] = useState(fulfillment.tracking ?? '')
  // '' means "work it out from the number" — the server pins the carrier
  // itself when the format is recognisable.
  const [carrier, setCarrier] = useState(fulfillment.tracking_carrier ?? '')

  const carrierOptions = [
    { value: '', label: t('orders.fulfillments.carrier_auto') },
    ...(carriersData?.data ?? []).map((option) => ({ value: option.id, label: option.name })),
  ]

  async function handleSave() {
    await update
      .mutateAsync({
        fulfillmentId: fulfillment.id,
        tracking: tracking.trim(),
        tracking_carrier: carrier,
      })
      .then(() => onOpenChange(false))
      .catch(() => undefined)
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>
            {fulfillment.tracking
              ? t('orders.fulfillments.edit_tracking_title')
              : t('orders.fulfillments.add_tracking_title')}
          </DialogTitle>
          <DialogDescription>{t('orders.fulfillments.tracking_description')}</DialogDescription>
        </DialogHeader>

        <DialogBody>
          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
            <Field>
              <FieldLabel htmlFor="tracking-number">{t('orders.tracking_label')}</FieldLabel>
              <Input
                id="tracking-number"
                value={tracking}
                placeholder={t('orders.tracking_placeholder')}
                onChange={(event) => setTracking(event.target.value)}
              />
            </Field>

            <Field>
              <FieldLabel htmlFor="tracking-carrier">
                {t('orders.fulfillments.carrier_label')}
              </FieldLabel>
              <Select
                items={carrierOptions}
                value={carrier}
                onValueChange={(value) => setCarrier((value as string) ?? '')}
              >
                <SelectTrigger id="tracking-carrier">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {carrierOptions.map((option) => (
                    <SelectItem key={option.value} value={option.value}>
                      {option.label}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </Field>
          </div>
        </DialogBody>

        <DialogFooter>
          <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>
            {t('common.cancel')}
          </Button>
          <Button type="button" disabled={update.isPending} onClick={handleSave}>
            {update.isPending ? t('common.saving') : t('common.save')}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}

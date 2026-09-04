import { zodResolver } from '@hookform/resolvers/zod'
import { mapSpreeErrorsToForm } from '@spree/dashboard-core'
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
} from '@spree/dashboard-ui'
import type { Fulfillment } from '@spree/seller-sdk'
import { Controller, useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { useFulfillmentActions } from '../../hooks/use-fulfillments'
import { useTrackingCarriers } from '../../hooks/use-reasons'
import { type TrackingFormValues, trackingFormSchema } from '../../schemas/fulfillment'

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

  const carrierOptions = [
    // '' means "work it out from the number" — the server pins the carrier
    // itself when the format is recognisable.
    { value: '', label: t('orders.fulfillments.carrier_auto') },
    ...(carriersData?.data ?? []).map((option) => ({ value: option.id, label: option.name })),
  ]

  const form = useForm<TrackingFormValues>({
    resolver: zodResolver(trackingFormSchema),
    defaultValues: {
      tracking: fulfillment.tracking ?? '',
      // The carrier lives on the parcel's consignment since 6.0; `tracking`
      // on the fulfillment summarizes the first of them.
      tracking_carrier: fulfillment.deliveries?.[0]?.carrier ?? '',
    },
  })

  async function onSubmit(values: TrackingFormValues) {
    try {
      await update.mutateAsync({
        fulfillmentId: fulfillment.id,
        tracking: values.tracking.trim(),
        tracking_carrier: values.tracking_carrier,
      })
      onOpenChange(false)
    } catch (err) {
      if (!mapSpreeErrorsToForm(err, form.setError)) throw err
    }
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <form onSubmit={form.handleSubmit(onSubmit)}>
          <DialogHeader>
            <DialogTitle>
              {fulfillment.tracking
                ? t('orders.fulfillments.edit_tracking_title')
                : t('orders.fulfillments.add_tracking_title')}
            </DialogTitle>
            <DialogDescription>{t('orders.fulfillments.tracking_description')}</DialogDescription>
          </DialogHeader>

          <DialogBody>
            {form.formState.errors.root?.message && (
              <p className="text-sm text-destructive" role="alert">
                {form.formState.errors.root.message}
              </p>
            )}

            <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
              <Field>
                <FieldLabel htmlFor="tracking-number">{t('orders.tracking_label')}</FieldLabel>
                <Input
                  id="tracking-number"
                  placeholder={t('orders.tracking_placeholder')}
                  aria-invalid={!!form.formState.errors.tracking}
                  {...form.register('tracking')}
                />
                <FieldError errors={[form.formState.errors.tracking]} />
              </Field>

              <Field>
                <FieldLabel htmlFor="tracking-carrier">
                  {t('orders.fulfillments.carrier_label')}
                </FieldLabel>
                <Controller
                  control={form.control}
                  name="tracking_carrier"
                  render={({ field }) => (
                    <Select
                      items={carrierOptions}
                      value={field.value}
                      onValueChange={(value) => field.onChange(value ?? '')}
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
                  )}
                />
              </Field>
            </div>
          </DialogBody>

          <DialogFooter>
            <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>
              {t('common.cancel')}
            </Button>
            <Button type="submit" disabled={update.isPending}>
              {update.isPending ? t('common.saving') : t('common.save')}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  )
}

import { zodResolver } from '@hookform/resolvers/zod'
import type { Fulfillment } from '@spree/admin-sdk'
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
import { Controller, useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { z } from 'zod'
import { useFulfillmentActions } from '../../../hooks/use-fulfillments'
import { useTrackingCarriers } from '../../../hooks/use-tracking-carriers'

const trackingSchema = z.object({
  tracking: z.string(),
  // '' means "detect from the number" — the backend pins the carrier itself
  // when the format is recognisable.
  tracking_carrier: z.string(),
})

type TrackingFormValues = z.infer<typeof trackingSchema>

/**
 * Adds or edits a fulfillment's tracking number. Separate from the edit
 * dialog, which is about where a parcel ships from and by which service —
 * this is the one thing a merchant reaches for after a parcel has gone out.
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
    { value: '', label: t('admin.orders.detail.fulfillments.carrier_auto') },
    ...(carriersData?.data ?? []).map((carrier) => ({ value: carrier.id, label: carrier.name })),
  ]

  const form = useForm<TrackingFormValues>({
    resolver: zodResolver(trackingSchema),
    defaultValues: {
      tracking: fulfillment.tracking ?? '',
      tracking_carrier: fulfillment.tracking_carrier ?? '',
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
                ? t('admin.orders.detail.fulfillments.edit_tracking_title')
                : t('admin.orders.detail.fulfillments.add_tracking_title')}
            </DialogTitle>
            <DialogDescription>
              {t('admin.orders.detail.fulfillments.tracking_description')}
            </DialogDescription>
          </DialogHeader>

          <DialogBody>
            {form.formState.errors.root?.message && (
              <p className="text-sm text-destructive" role="alert">
                {form.formState.errors.root.message}
              </p>
            )}

            <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
              <Field>
                <FieldLabel htmlFor="fulfillment-tracking">
                  {t('admin.orders.fulfill.tracking_label')}
                </FieldLabel>
                <Input
                  id="fulfillment-tracking"
                  placeholder={t('admin.orders.fulfill.tracking_placeholder')}
                  aria-invalid={!!form.formState.errors.tracking}
                  {...form.register('tracking')}
                />
                <FieldError errors={[form.formState.errors.tracking]} />
              </Field>

              <Field>
                <FieldLabel htmlFor="fulfillment-tracking-carrier">
                  {t('admin.orders.detail.fulfillments.carrier_label')}
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
                      <SelectTrigger id="fulfillment-tracking-carrier">
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
              {t('admin.actions.cancel')}
            </Button>
            <Button type="submit" disabled={update.isPending}>
              {update.isPending ? t('admin.actions.saving') : t('admin.actions.save')}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  )
}

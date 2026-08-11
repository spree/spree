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
} from '@spree/dashboard-ui'
import { useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { z } from 'zod'
import { useFulfillmentActions } from '../../../hooks/use-fulfillments'

const trackingSchema = z.object({ tracking: z.string() })

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

  const form = useForm<TrackingFormValues>({
    resolver: zodResolver(trackingSchema),
    defaultValues: { tracking: fulfillment.tracking ?? '' },
  })

  async function onSubmit(values: TrackingFormValues) {
    try {
      await update.mutateAsync({
        fulfillmentId: fulfillment.id,
        tracking: values.tracking.trim(),
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

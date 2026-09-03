import { zodResolver } from '@hookform/resolvers/zod'
import type { Delivery } from '@spree/admin-sdk'
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
import { useTrackingCarriers } from '../../../hooks/use-tracking-carriers'

const deliverySchema = z.object({
  tracking_number: z.string().min(1),
  // Free text: a forwarder's own name is as valid as a registered carrier,
  // and an empty value asks the server to detect one from the number.
  carrier: z.string(),
  tracking_url: z.string(),
})

type DeliveryFormValues = z.infer<typeof deliverySchema>

/**
 * Records a tracked consignment on a parcel, or corrects one. A parcel can
 * carry several — three boxes, or a freight PRO number covering a pallet —
 * and each travels on its own carrier status.
 */
export function FulfillmentDeliveryDialog({
  orderId,
  fulfillmentId,
  delivery,
  open,
  onOpenChange,
}: {
  orderId: string
  fulfillmentId: string
  delivery?: Delivery
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const { createDelivery, updateDelivery } = useFulfillmentActions(orderId)
  const { data: carriersData } = useTrackingCarriers(open)

  // The datalist suggests display names, but what is stored and submitted is
  // the registry key — seeding the field with the name would rewrite a known
  // carrier to its own label on the next save.
  const carrierOptions = (carriersData?.data ?? []).map((carrier) => ({
    value: carrier.id,
    label: carrier.name,
  }))

  const form = useForm<DeliveryFormValues>({
    resolver: zodResolver(deliverySchema),
    defaultValues: {
      tracking_number: delivery?.tracking_number ?? '',
      carrier: delivery?.carrier ?? '',
      tracking_url: delivery?.tracking_url ?? '',
    },
  })

  const pending = createDelivery.isPending || updateDelivery.isPending

  async function onSubmit(values: DeliveryFormValues) {
    try {
      const tracking_number = values.tracking_number.trim()
      const carrier = values.carrier.trim()
      const tracking_url = values.tracking_url.trim()

      if (delivery) {
        // Sent even when empty: clearing the carrier is how a merchant asks
        // for it to be detected from the number again.
        await updateDelivery.mutateAsync({
          fulfillmentId,
          deliveryId: delivery.id,
          tracking_number,
          carrier,
          tracking_url,
        })
      } else {
        await createDelivery.mutateAsync({
          fulfillmentId,
          tracking_number,
          carrier: carrier || undefined,
          tracking_url: tracking_url || undefined,
        })
      }
      onOpenChange(false)
    } catch (err) {
      if (!mapSpreeErrorsToForm(err, form.setError)) throw err
    }
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <form
          onSubmit={(event) => {
            // The order page renders its cards inside their own forms — without
            // stopping the bubble the browser submits the outer one.
            form.handleSubmit(onSubmit)(event)
            event.stopPropagation()
          }}
        >
          <DialogHeader>
            <DialogTitle>
              {delivery
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
                <FieldLabel htmlFor="delivery-tracking-number">
                  {t('admin.orders.fulfill.tracking_label')}
                </FieldLabel>
                <Input
                  id="delivery-tracking-number"
                  placeholder={t('admin.orders.fulfill.tracking_placeholder')}
                  aria-invalid={!!form.formState.errors.tracking_number}
                  {...form.register('tracking_number')}
                />
                <FieldError errors={[form.formState.errors.tracking_number]} />
              </Field>

              <Field>
                <FieldLabel htmlFor="delivery-carrier">
                  {t('admin.orders.detail.fulfillments.carrier_label')}
                </FieldLabel>
                {/* Free text with the registered carriers as suggestions: a
                    forwarder's own name has to be enterable, and an empty
                    value asks the server to detect one from the number. */}
                <Input
                  id="delivery-carrier"
                  list="delivery-carrier-options"
                  placeholder={t('admin.orders.detail.fulfillments.carrier_auto')}
                  {...form.register('carrier')}
                />
                <datalist id="delivery-carrier-options">
                  {carrierOptions.map((option) => (
                    <option key={option.value} value={option.value} label={option.label} />
                  ))}
                </datalist>
              </Field>
            </div>

            <Field>
              <FieldLabel htmlFor="delivery-tracking-url">
                {t('admin.orders.detail.fulfillments.tracking_url_label')}
              </FieldLabel>
              <Input
                id="delivery-tracking-url"
                placeholder={t('admin.orders.detail.fulfillments.tracking_url_placeholder')}
                aria-invalid={!!form.formState.errors.tracking_url}
                {...form.register('tracking_url')}
              />
              <FieldError errors={[form.formState.errors.tracking_url]} />
            </Field>
          </DialogBody>

          <DialogFooter>
            <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>
              {t('admin.actions.cancel')}
            </Button>
            <Button type="submit" disabled={pending}>
              {pending ? t('admin.actions.saving') : t('admin.actions.save')}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  )
}

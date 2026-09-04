import { zodResolver } from '@hookform/resolvers/zod'
import type { Delivery } from '@spree/admin-sdk'
import { mapSpreeErrorsToForm } from '@spree/dashboard-core'
import {
  Button,
  Combobox,
  ComboboxButtonTrigger,
  ComboboxContent,
  ComboboxEmpty,
  ComboboxItem,
  ComboboxList,
  ComboboxSearch,
  ComboboxTriggerPlaceholder,
  ComboboxValue,
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
import { Controller, useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { z } from 'zod'
import { useFulfillmentActions } from '../../../hooks/use-fulfillments'
import { useTrackingCarriers } from '../../../hooks/use-tracking-carriers'

const deliverySchema = z.object({
  tracking_number: z.string().min(1),
  // Free text: a forwarder's own name is as valid as a registered carrier,
  // and an empty value asks the server to detect one from the number.
  carrier: z.string(),
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

  // The picker offers what the registry knows, but the value stored is the
  // carrier's key — seeding it with the display name would rewrite a known
  // carrier to its own label on the next save. Anything not on the list is
  // still typeable, because a forwarder's own name has to be enterable.
  const carrierOptions = (carriersData?.data ?? []).map((carrier) => ({
    value: carrier.id,
    label: carrier.name,
  }))

  const carrierLabel = (value: string) =>
    carrierOptions.find((option) => option.value === value)?.label ?? value

  const form = useForm<DeliveryFormValues>({
    resolver: zodResolver(deliverySchema),
    defaultValues: {
      tracking_number: delivery?.tracking_number ?? '',
      carrier: delivery?.carrier ?? '',
    },
  })

  const pending = createDelivery.isPending || updateDelivery.isPending

  async function onSubmit(values: DeliveryFormValues) {
    try {
      const tracking_number = values.tracking_number.trim()
      const carrier = values.carrier.trim()

      if (delivery) {
        // Carrier is sent even when empty: clearing it is how a merchant asks
        // for it to be detected from the number again.
        await updateDelivery.mutateAsync({
          fulfillmentId,
          deliveryId: delivery.id,
          tracking_number,
          carrier,
        })
      } else {
        await createDelivery.mutateAsync({
          fulfillmentId,
          tracking_number,
          carrier: carrier || undefined,
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

          <DialogBody className="flex flex-col gap-4">
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
                <Controller
                  control={form.control}
                  name="carrier"
                  render={({ field }) => (
                    <Combobox
                      items={carrierOptions.map((option) => option.value)}
                      value={field.value}
                      onValueChange={(value: string | null) => field.onChange(value ?? '')}
                      itemToStringLabel={carrierLabel}
                    >
                      <ComboboxButtonTrigger id="delivery-carrier" onBlur={field.onBlur}>
                        {field.value ? (
                          <ComboboxValue />
                        ) : (
                          <ComboboxTriggerPlaceholder>
                            {t('admin.orders.detail.fulfillments.carrier_auto')}
                          </ComboboxTriggerPlaceholder>
                        )}
                      </ComboboxButtonTrigger>
                      <ComboboxContent>
                        <ComboboxSearch
                          placeholder={t('admin.orders.detail.fulfillments.carrier_search')}
                        />
                        <ComboboxEmpty>{t('admin.common.no_results')}</ComboboxEmpty>
                        <ComboboxList>
                          {(value: string) => (
                            <ComboboxItem key={value} value={value}>
                              {carrierLabel(value)}
                            </ComboboxItem>
                          )}
                        </ComboboxList>
                      </ComboboxContent>
                    </Combobox>
                  )}
                />
              </Field>
            </div>
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

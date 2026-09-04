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
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@spree/dashboard-ui'
import type { Fulfillment } from '@spree/seller-sdk'
import { Controller, useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { z } from 'zod/v4'
import { useFulfillmentActions } from '../../hooks/use-fulfillments'
import { useStockLocations } from '../../hooks/use-stock-locations'

const originSchema = z.object({
  stock_location_id: z.string().min(1),
})

type OriginFormValues = z.infer<typeof originSchema>

/**
 * Moves a parcel to a different shelf of this seller's.
 *
 * The split picks an origin from where the stock sat; a seller who actually
 * picks from another of their warehouses needs to say so, and the rate is
 * requoted from there.
 *
 * The list comes from the seller's own endpoint, so the marketplace's
 * warehouses never appear — and the server refuses one anyway.
 */
export function FulfillmentOriginDialog({
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
  const { data: locationsData } = useStockLocations(open)

  const locationOptions = (locationsData?.data ?? []).map((location) => ({
    value: location.id,
    label: location.name,
  }))

  const form = useForm<OriginFormValues>({
    resolver: zodResolver(originSchema),
    defaultValues: { stock_location_id: fulfillment.stock_location_id ?? '' },
  })

  async function onSubmit(values: OriginFormValues) {
    try {
      await update.mutateAsync({
        fulfillmentId: fulfillment.id,
        stock_location_id: values.stock_location_id,
      })
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
            <DialogTitle>{t('orders.fulfillments.move_origin_title')}</DialogTitle>
            <DialogDescription>
              {t('orders.fulfillments.move_origin_description')}
            </DialogDescription>
          </DialogHeader>

          <DialogBody>
            {form.formState.errors.root?.message && (
              <p className="text-sm text-destructive" role="alert">
                {form.formState.errors.root.message}
              </p>
            )}

            <Field>
              <FieldLabel htmlFor="fulfillment-origin">
                {t('orders.fulfillments.ships_from_label')}
              </FieldLabel>
              <Controller
                control={form.control}
                name="stock_location_id"
                render={({ field }) => (
                  <Select
                    items={locationOptions}
                    value={field.value}
                    onValueChange={(value) => field.onChange((value as string) ?? '')}
                  >
                    <SelectTrigger id="fulfillment-origin">
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      {locationOptions.map((option) => (
                        <SelectItem key={option.value} value={option.value}>
                          {option.label}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                )}
              />
              <FieldError errors={[form.formState.errors.stock_location_id]} />
            </Field>
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

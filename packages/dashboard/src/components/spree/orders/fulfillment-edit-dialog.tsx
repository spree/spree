import { zodResolver } from '@hookform/resolvers/zod'
import type { Fulfillment, Order } from '@spree/admin-sdk'
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
import { Controller, useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { z } from 'zod'
import { useFulfillmentActions } from '../../../hooks/use-fulfillments'
import { useOrder } from '../../../hooks/use-order'
import { useStockCoverage } from '../../../hooks/use-stock-coverage'
import { useStockLocations } from '../../../hooks/use-stock-locations'

const fulfillmentEditSchema = z.object({
  stock_location_id: z.string().min(1),
  selected_delivery_rate_id: z.string(),
})

type FulfillmentEditFormValues = z.infer<typeof fulfillmentEditSchema>

/**
 * Where the fulfillment ships from and which priced service carries it.
 *
 * The two fields are coupled: rates are quoted against an origin, so moving
 * the fulfillment invalidates the list the merchant is looking at. Rather than
 * offering stale options, a save that changes the origin writes the location
 * first, waits for the server to re-quote, and only then offers the fresh
 * rates — see `handleSubmit`.
 */
export function FulfillmentEditDialog({
  order,
  fulfillment,
  open,
  onOpenChange,
}: {
  order: Order
  fulfillment: Fulfillment
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const { update } = useFulfillmentActions(order.id)
  const { data: stockLocations } = useStockLocations()
  const { refetch: refetchOrder } = useOrder(order.id)

  const form = useForm<FulfillmentEditFormValues>({
    resolver: zodResolver(fulfillmentEditSchema),
    defaultValues: {
      stock_location_id: fulfillment.stock_location_id ?? '',
      selected_delivery_rate_id: fulfillment.selected_delivery_rate_id ?? '',
    },
  })

  const demands = (fulfillment.fulfillment_items ?? []).flatMap((item) =>
    item.variant_id ? [{ variantId: item.variant_id, quantity: item.quantity }] : [],
  )
  const { data: coverage } = useStockCoverage(demands, open)

  const chosenLocationId = form.watch('stock_location_id')
  // The rates on the record were quoted for the origin it currently has. Once
  // the merchant picks a different one they describe a route that is no longer
  // on offer, so the method field stands down until the server re-quotes.
  const originMoved = chosenLocationId !== (fulfillment.stock_location_id ?? '')

  const locationOptions = (stockLocations?.data ?? [])
    .map((location) => {
      const covered = coverage?.get(location.id) ?? false
      return {
        value: location.id,
        // Uncovered locations stay selectable: moving a fulfillment to a
        // warehouse awaiting a transfer is a real workflow, and backorderable
        // stock ships from an empty shelf by design.
        label: covered
          ? location.name
          : `${location.name} — ${t('admin.orders.detail.fulfillments.out_of_stock')}`,
        covered,
      }
    })
    .sort((left, right) => Number(right.covered) - Number(left.covered))

  const rateOptions = (fulfillment.delivery_rates ?? []).map((rate) => ({
    value: rate.id,
    label: `${rate.name} — ${
      Number.parseFloat(rate.cost) === 0
        ? t('admin.orders.detail.fulfillments.free')
        : rate.display_cost
    }`,
  }))

  async function onSubmit(values: FulfillmentEditFormValues) {
    const locationChanged = values.stock_location_id !== (fulfillment.stock_location_id ?? '')
    const rateChanged =
      values.selected_delivery_rate_id !== (fulfillment.selected_delivery_rate_id ?? '')

    try {
      if (locationChanged) {
        await update.mutateAsync({
          fulfillmentId: fulfillment.id,
          stock_location_id: values.stock_location_id,
        })

        // The server re-quotes on the move and re-selects an equivalent method
        // where the new origin offers one. Pull the fresh fulfillment back and
        // show that pick, rather than writing a rate id quoted for the origin
        // the fulfillment just left. The merchant confirms or changes it in a
        // second save, against rates that actually apply.
        const { data: refreshed } = await refetchOrder()
        const requoted = refreshed?.fulfillments?.find(
          (candidate) => candidate.id === fulfillment.id,
        )

        form.reset({
          stock_location_id: values.stock_location_id,
          selected_delivery_rate_id: requoted?.selected_delivery_rate_id ?? '',
        })
        return
      }

      if (rateChanged) {
        await update.mutateAsync({
          fulfillmentId: fulfillment.id,
          selected_delivery_rate_id: values.selected_delivery_rate_id,
        })
      }

      onOpenChange(false)
    } catch (err) {
      if (!mapSpreeErrorsToForm(err, form.setError)) throw err
    }
  }

  const { errors, isSubmitting } = form.formState

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
            <DialogTitle>{t('admin.orders.detail.fulfillments.edit_title')}</DialogTitle>
            <DialogDescription>
              {t('admin.orders.detail.fulfillments.edit_description')}
            </DialogDescription>
          </DialogHeader>

          <DialogBody className="flex flex-col gap-4">
            {errors.root?.message && (
              <p className="text-sm text-destructive" role="alert">
                {errors.root.message}
              </p>
            )}

            <Field>
              <FieldLabel htmlFor="fulfillment-location">
                {t('admin.orders.detail.fulfillments.ships_from')}
              </FieldLabel>
              <Controller
                name="stock_location_id"
                control={form.control}
                render={({ field }) => (
                  <Select
                    items={locationOptions}
                    value={field.value}
                    onValueChange={(value) => field.onChange(value as string)}
                  >
                    <SelectTrigger id="fulfillment-location">
                      <SelectValue placeholder={t('admin.common.select_placeholder')} />
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
              <FieldError errors={[errors.stock_location_id]} />
            </Field>

            <Field>
              <FieldLabel htmlFor="fulfillment-rate">
                {t('admin.orders.detail.fulfillments.delivery_method')}
              </FieldLabel>
              <Controller
                name="selected_delivery_rate_id"
                control={form.control}
                render={({ field }) => (
                  <Select
                    items={rateOptions}
                    value={field.value}
                    disabled={originMoved || rateOptions.length === 0}
                    onValueChange={(value) => field.onChange(value as string)}
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
                )}
              />
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
              disabled={isSubmitting}
            >
              {t('admin.actions.cancel')}
            </Button>
            <Button type="submit" disabled={isSubmitting}>
              {isSubmitting
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

import { zodResolver } from '@hookform/resolvers/zod'
import type { Delivery } from '@spree/admin-sdk'
import {
  type DeliveryFormValues,
  deliveryFormSchema,
  mapSpreeErrorsToForm,
} from '@spree/dashboard-core'
import { DeliveryFormDialog } from '@spree/dashboard-ui'
import { useForm } from 'react-hook-form'
import { useFulfillmentActions } from '../../../hooks/use-fulfillments'
import { useTrackingCarriers } from '../../../hooks/use-tracking-carriers'

/** What the operator records against one consignment of a parcel. */
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
  const { createDelivery, updateDelivery } = useFulfillmentActions(orderId)
  const { data: carriersData } = useTrackingCarriers(open)

  const carriers = carriersData?.data ?? []
  const carrierKeys = carriers.map((carrier) => carrier.id)
  const carrierLabel = (value: string) =>
    carriers.find((carrier) => carrier.id === value)?.name ?? value

  const form = useForm<DeliveryFormValues>({
    resolver: zodResolver(deliveryFormSchema),
    defaultValues: {
      tracking_number: delivery?.tracking_number ?? '',
      carrier: delivery?.carrier ?? '',
    },
  })

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
    <DeliveryFormDialog
      form={form}
      open={open}
      onOpenChange={onOpenChange}
      editing={!!delivery}
      carrierKeys={carrierKeys}
      carrierLabel={carrierLabel}
      onSubmit={onSubmit}
      pending={createDelivery.isPending || updateDelivery.isPending}
    />
  )
}

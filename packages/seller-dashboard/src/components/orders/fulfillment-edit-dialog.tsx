import { FulfillmentEditDialog as SharedFulfillmentEditDialog } from '@spree/dashboard-ui'
import { type Fulfillment, SpreeError } from '@spree/seller-sdk'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { useFulfillmentActions } from '../../hooks/use-fulfillments'
import { useOrder } from '../../hooks/use-order'
import { useStockLocations } from '../../hooks/use-stock-locations'

/**
 * Where the parcel ships from and which quoted service carries it.
 *
 * The dialog is shared with the operator's order page; this supplies the
 * seller's view of it. The shelves come from the seller's own endpoint, so the
 * marketplace's warehouses never appear — and the server refuses one anyway.
 */
export function FulfillmentEditDialog({
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
  const { refetch: refetchOrder } = useOrder(orderId)
  const [errorMessage, setErrorMessage] = useState<string>()

  const originOptions = (locationsData?.data ?? []).map((location) => ({
    value: location.id,
    label: location.name,
  }))

  const rateOptions = (fulfillment.delivery_rates ?? []).map((rate) => ({
    value: rate.id,
    label: `${rate.name} — ${
      Number.parseFloat(rate.cost) === 0 ? t('orders.fulfillments.free') : rate.display_cost
    }`,
  }))

  async function handleSubmit(
    values: { stockLocationId: string; selectedDeliveryRateId: string },
    changed: { origin: boolean; rate: boolean },
  ): Promise<'requote' | 'done'> {
    setErrorMessage(undefined)

    try {
      if (changed.origin) {
        await update.mutateAsync({
          fulfillmentId: fulfillment.id,
          stock_location_id: values.stockLocationId,
        })

        // Moving the parcel re-quotes it: the rates on screen were priced from
        // the shelf it just left. Pull the fresh parcel back so the seller
        // confirms a service that actually applies.
        await refetchOrder()
        return 'requote'
      }

      if (changed.rate) {
        await update.mutateAsync({
          fulfillmentId: fulfillment.id,
          selected_delivery_rate_id: values.selectedDeliveryRateId,
        })
      }

      return 'done'
    } catch (err) {
      // A refused save keeps the dialog open with the server's reason on it;
      // anything else is a real fault and belongs to the caller's toast.
      if (!(err instanceof SpreeError)) throw err
      setErrorMessage(err.message)
      return 'requote'
    }
  }

  return (
    <SharedFulfillmentEditDialog
      open={open}
      onOpenChange={onOpenChange}
      originOptions={originOptions}
      rateOptions={rateOptions}
      currentOriginId={fulfillment.stock_location_id ?? ''}
      currentRateId={fulfillment.selected_delivery_rate_id ?? ''}
      onSubmit={handleSubmit}
      pending={update.isPending}
      errorMessage={errorMessage}
    />
  )
}

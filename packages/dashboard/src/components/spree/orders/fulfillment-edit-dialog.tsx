import { type Fulfillment, type Order, SpreeError } from '@spree/admin-sdk'
import { currencyParts, useStockLocations } from '@spree/dashboard-core'
import {
  type FulfillmentEditValues,
  FulfillmentEditDialog as SharedFulfillmentEditDialog,
} from '@spree/dashboard-ui'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { useFulfillmentActions } from '../../../hooks/use-fulfillments'
import { useOrder } from '../../../hooks/use-order'
import { useStockCoverage } from '../../../hooks/use-stock-coverage'

/**
 * Where the fulfillment ships from, which priced service carries it, and what
 * the customer is charged for it.
 *
 * The dialog itself is shared with the seller panel; this supplies the
 * operator's view of it — every warehouse in the store, marked for whether it
 * can actually cover the parcel, and the delivery cost the seller cannot set —
 * and owns the writes.
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
  const { t, i18n } = useTranslation()
  const { update } = useFulfillmentActions(order.id)
  const { data: stockLocations } = useStockLocations()
  const { refetch: refetchOrder } = useOrder(order.id)
  const [errorMessage, setErrorMessage] = useState<string>()

  const demands = (fulfillment.fulfillment_items ?? []).flatMap((item) =>
    item.variant_id ? [{ variantId: item.variant_id, quantity: item.quantity }] : [],
  )
  const { data: coverage } = useStockCoverage(demands, open)

  const originOptions = (stockLocations?.data ?? [])
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

  // An unpriced freight rate also costs zero, and calling it "Free" over a
  // container of goods is the one thing this must never say — so the server's
  // own wording wins wherever it has already decided the price is pending.
  const rateOptions = (fulfillment.delivery_rates ?? []).map((rate) => ({
    value: rate.id,
    label: `${rate.name} — ${
      !rate.unpriced && Number.parseFloat(rate.cost) === 0
        ? t('admin.orders.detail.fulfillments.free')
        : rate.display_cost
    }`,
  }))

  const currentOriginId = fulfillment.stock_location_id ?? ''
  const currentRateId = fulfillment.selected_delivery_rate_id ?? ''

  const cost = {
    current: fulfillment.cost,
    overridden: fulfillment.cost_source === 'manual',
    currencySymbol: currencyParts(order.currency, i18n.language).symbol,
  }

  async function handleSubmit(
    values: FulfillmentEditValues,
    changed: { origin: boolean; rate: boolean; cost: boolean },
  ): Promise<'requote' | 'done'> {
    setErrorMessage(undefined)

    // A cost set by hand survives the re-quote a move triggers, so it rides
    // with whichever write goes first.
    const costParams = changed.cost ? { cost: values.cost } : {}

    try {
      if (changed.origin) {
        await update.mutateAsync({
          fulfillmentId: fulfillment.id,
          stock_location_id: values.stockLocationId,
          ...costParams,
        })

        // The server re-quotes on the move and re-selects an equivalent method
        // where the new origin offers one. Pull the fresh fulfillment back so
        // the merchant confirms that pick against rates that actually apply,
        // rather than writing a rate id quoted for the origin it just left.
        await refetchOrder()
        return 'requote'
      }

      if (changed.rate || changed.cost) {
        await update.mutateAsync({
          fulfillmentId: fulfillment.id,
          ...(changed.rate ? { selected_delivery_rate_id: values.selectedDeliveryRateId } : {}),
          ...costParams,
        })
      }

      return 'done'
    } catch (err) {
      // A rejected save keeps the dialog open with the server's reason on it;
      // anything that is not a validation failure is a real fault and toasts.
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
      currentOriginId={currentOriginId}
      currentRateId={currentRateId}
      cost={cost}
      onSubmit={handleSubmit}
      pending={update.isPending}
      errorMessage={errorMessage}
    />
  )
}

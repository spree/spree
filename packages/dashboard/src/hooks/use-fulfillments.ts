import {
  type FulfillmentCreateParams,
  type FulfillmentFulfillParams,
  type FulfillmentSplitParams,
  SpreeError,
} from '@spree/admin-sdk'
import { adminClient, useResourceKeyBuilder } from '@spree/dashboard-core'
import { toastManager } from '@spree/dashboard-ui'
import { useMutation, useQueryClient } from '@tanstack/react-query'

/**
 * A fulfillment mutation refreshes the order itself — every one of these moves
 * units, re-prices the fulfillment, or both, and the order totals and
 * fulfillment status are derived from that.
 *
 * A 422 is left untoasted: the caller is a form that renders the same message
 * next to the offending input, so toasting it too would say it twice.
 */
function useFulfillmentMutation<TParams>(
  orderId: string,
  mutationFn: (params: TParams) => Promise<unknown>,
) {
  const queryClient = useQueryClient()
  const buildKey = useResourceKeyBuilder()

  return useMutation({
    mutationFn,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: buildKey('orders', orderId) })
    },
    onError: (error) => {
      if (error instanceof SpreeError && error.status === 422) return
      toastManager.add({
        type: 'error',
        title: error instanceof Error ? error.message : String(error),
      })
    },
  })
}

/**
 * Every write the fulfillments card offers. The status transitions are
 * separate endpoints rather than a writable status field, because the server
 * decides which ones a fulfillment can currently make.
 */
export function useFulfillmentActions(orderId: string) {
  const create = useFulfillmentMutation(orderId, (params: FulfillmentCreateParams) =>
    adminClient.orders.fulfillments.create(orderId, params),
  )

  const update = useFulfillmentMutation(
    orderId,
    ({
      fulfillmentId,
      ...params
    }: {
      fulfillmentId: string
      tracking?: string
      tracking_carrier?: string
      selected_delivery_rate_id?: string
      stock_location_id?: string
    }) => adminClient.orders.fulfillments.update(orderId, fulfillmentId, params),
  )

  const split = useFulfillmentMutation(
    orderId,
    ({ fulfillmentId, ...params }: { fulfillmentId: string } & FulfillmentSplitParams) =>
      adminClient.orders.fulfillments.split(orderId, fulfillmentId, params),
  )

  // Accepts a bare id (ship everything) or an id plus the quantities to ship,
  // the tracking number and whether the customer is notified. Passing items
  // splits them off into a new fulfillment which is the one that ships, so the
  // response's id is not the one that was addressed.
  const fulfill = useFulfillmentMutation(
    orderId,
    (params: string | ({ fulfillmentId: string } & FulfillmentFulfillParams)) => {
      if (typeof params === 'string') {
        return adminClient.orders.fulfillments.fulfill(orderId, params)
      }
      const { fulfillmentId, ...rest } = params
      return adminClient.orders.fulfillments.fulfill(orderId, fulfillmentId, rest)
    },
  )

  const cancel = useFulfillmentMutation(orderId, (fulfillmentId: string) =>
    adminClient.orders.fulfillments.cancel(orderId, fulfillmentId),
  )

  const markDelivered = useFulfillmentMutation(orderId, (fulfillmentId: string) =>
    adminClient.orders.fulfillments.markDelivered(orderId, fulfillmentId),
  )

  const purchaseLabel = useFulfillmentMutation(orderId, (fulfillmentId: string) =>
    adminClient.orders.fulfillments.purchaseLabel(orderId, fulfillmentId),
  )

  return { create, update, split, fulfill, cancel, markDelivered, purchaseLabel }
}

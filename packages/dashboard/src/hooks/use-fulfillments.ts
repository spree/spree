import type { FulfillmentCreateParams, FulfillmentSplitParams } from '@spree/admin-sdk'
import { adminClient, useResourceKeyBuilder } from '@spree/dashboard-core'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import { toast } from 'sonner'

/**
 * A fulfillment mutation refreshes the order itself — every one of these moves
 * units, re-prices the fulfillment, or both, and the order totals and
 * fulfillment status are derived from that.
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
      toast.error(error instanceof Error ? error.message : String(error))
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
      selected_delivery_rate_id?: string
      stock_location_id?: string
    }) => adminClient.orders.fulfillments.update(orderId, fulfillmentId, params),
  )

  const split = useFulfillmentMutation(
    orderId,
    ({ fulfillmentId, ...params }: { fulfillmentId: string } & FulfillmentSplitParams) =>
      adminClient.orders.fulfillments.split(orderId, fulfillmentId, params),
  )

  const fulfill = useFulfillmentMutation(orderId, (fulfillmentId: string) =>
    adminClient.orders.fulfillments.fulfill(orderId, fulfillmentId),
  )

  const cancel = useFulfillmentMutation(orderId, (fulfillmentId: string) =>
    adminClient.orders.fulfillments.cancel(orderId, fulfillmentId),
  )

  const resume = useFulfillmentMutation(orderId, (fulfillmentId: string) =>
    adminClient.orders.fulfillments.resume(orderId, fulfillmentId),
  )

  return { create, update, split, fulfill, cancel, resume }
}

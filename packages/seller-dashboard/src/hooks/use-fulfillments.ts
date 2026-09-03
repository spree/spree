import { useResourceKeyBuilder } from '@spree/dashboard-core'
import { toastManager } from '@spree/dashboard-ui'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import { sellerClient } from '../api-client'

/**
 * Everything a seller does to a parcel.
 *
 * Each verb is its own endpoint because each carries different arguments —
 * shipping takes a tracking number and which units went, splitting takes a
 * variant and a quantity.
 */
export function useFulfillmentActions(orderId: string) {
  const queryClient = useQueryClient()
  const buildKey = useResourceKeyBuilder()

  function useFulfillmentMutation<TParams>(mutationFn: (params: TParams) => Promise<unknown>) {
    return useMutation({
      mutationFn,
      onSuccess: () => {
        queryClient.invalidateQueries({ queryKey: buildKey('seller-order', orderId) })
        queryClient.invalidateQueries({ queryKey: buildKey('seller-orders') })
      },
      onError: (error) => {
        // A rejected workflow — a parcel that cannot be resumed, a split that
        // would empty its source — otherwise looks like a dead button.
        toastManager.add({
          type: 'error',
          title: error instanceof Error ? error.message : String(error),
        })
      },
    })
  }

  const fulfill = useFulfillmentMutation(
    ({
      fulfillmentId,
      ...params
    }: {
      fulfillmentId: string
      tracking?: string
      tracking_carrier?: string
      notify_customer?: boolean
      items?: Array<{ item_id: string; quantity: number }>
    }) => sellerClient().orders.fulfillments.fulfill(orderId, fulfillmentId, params),
  )

  const update = useFulfillmentMutation(
    ({
      fulfillmentId,
      ...params
    }: {
      fulfillmentId: string
      tracking?: string
      tracking_carrier?: string
    }) => sellerClient().orders.fulfillments.update(orderId, fulfillmentId, params),
  )

  const cancel = useFulfillmentMutation((fulfillmentId: string) =>
    sellerClient().orders.fulfillments.cancel(orderId, fulfillmentId),
  )

  const resume = useFulfillmentMutation((fulfillmentId: string) =>
    sellerClient().orders.fulfillments.resume(orderId, fulfillmentId),
  )

  const markDelivered = useFulfillmentMutation((fulfillmentId: string) =>
    sellerClient().orders.fulfillments.markDelivered(orderId, fulfillmentId),
  )

  const split = useFulfillmentMutation(
    ({
      fulfillmentId,
      ...params
    }: {
      fulfillmentId: string
      variant_id: string
      quantity: number
      stock_location_id?: string
    }) => sellerClient().orders.fulfillments.split(orderId, fulfillmentId, params),
  )

  return { fulfill, update, cancel, resume, markDelivered, split }
}

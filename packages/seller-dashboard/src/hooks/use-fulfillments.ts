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
        // A rejected workflow — a parcel that cannot ship, a split that would
        // empty its source — otherwise looks like a dead button.
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

  // A parcel's consignments. One parcel usually travels as one, but three
  // boxes or a pallet under a freight PRO number are the same shape, and each
  // carries its own tracking number and carrier status.
  const createDelivery = useFulfillmentMutation(
    ({
      fulfillmentId,
      ...params
    }: {
      fulfillmentId: string
      tracking_number: string
      carrier?: string
      service?: string
      tracking_url?: string
    }) => sellerClient().orders.fulfillments.deliveries.create(orderId, fulfillmentId, params),
  )

  const updateDelivery = useFulfillmentMutation(
    ({
      fulfillmentId,
      deliveryId,
      ...params
    }: {
      fulfillmentId: string
      deliveryId: string
      tracking_number?: string
      carrier?: string
      service?: string
      tracking_url?: string
    }) =>
      sellerClient().orders.fulfillments.deliveries.update(
        orderId,
        fulfillmentId,
        deliveryId,
        params,
      ),
  )

  const deleteDelivery = useFulfillmentMutation(
    ({ fulfillmentId, deliveryId }: { fulfillmentId: string; deliveryId: string }) =>
      sellerClient().orders.fulfillments.deliveries.delete(orderId, fulfillmentId, deliveryId),
  )

  // Postage the seller bought elsewhere and is recording here. Buying and
  // refunding run through the operator's carrier account, so neither is
  // offered — the endpoint refuses both.
  const uploadLabel = useFulfillmentMutation(
    ({
      fulfillmentId,
      ...params
    }: {
      fulfillmentId: string
      file: string
      // Required: a label with no tracking number is refused server-side,
      // since nothing could then follow the parcel it prints.
      tracking_number: string
      carrier?: string
      service?: string
      cost?: string
      currency?: string
    }) => sellerClient().orders.fulfillments.labels.create(orderId, fulfillmentId, params),
  )

  const deleteLabel = useFulfillmentMutation(
    ({ fulfillmentId, labelId }: { fulfillmentId: string; labelId: string }) =>
      sellerClient().orders.fulfillments.labels.delete(orderId, fulfillmentId, labelId),
  )

  return {
    fulfill,
    update,
    cancel,
    split,
    createDelivery,
    updateDelivery,
    deleteDelivery,
    uploadLabel,
    deleteLabel,
  }
}

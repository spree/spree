import type { ShippingLabelCreateParams } from '@spree/admin-sdk'
import { adminClient, useResourceKey, useResourceKeyBuilder } from '@spree/dashboard-core'
import { toastManager } from '@spree/dashboard-ui'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'

/**
 * Returns on an order. Fetched separately from the order itself so the order
 * payload stays lean — most orders have none.
 */
export function useOrderReturns(orderId: string) {
  return useQuery({
    queryKey: useResourceKey('order-returns', orderId),
    queryFn: () =>
      adminClient.orders.returns.list(orderId, {
        expand: ['return_line_items', 'return_line_items.variant', 'stock_location'],
      }),
    enabled: !!orderId,
  })
}

/**
 * A return mutation refreshes both the returns list and the order itself —
 * refunding changes the order's payment totals.
 */
function useReturnMutation<TParams>(
  orderId: string,
  mutationFn: (params: TParams) => Promise<unknown>,
) {
  const queryClient = useQueryClient()
  const buildKey = useResourceKeyBuilder()

  return useMutation({
    mutationFn,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: buildKey('order-returns', orderId) })
      queryClient.invalidateQueries({ queryKey: buildKey('orders', orderId) })
      // Keyed separately from the per-order list, so the sidebar count would
      // otherwise stay stale until a page reload.
      queryClient.invalidateQueries({ queryKey: buildKey('returns-pending') })
    },
    onError: (error) => {
      // Without this a rejected workflow — a claim with nothing to refund, a
      // return that cannot be cancelled — looked like a dead button.
      toastManager.add({
        type: 'error',
        title: error instanceof Error ? error.message : String(error),
      })
    },
  })
}

/**
 * The four status transitions. Each is its own endpoint because each carries
 * different arguments — receiving takes the quantities that actually arrived,
 * refunding takes a method and an amount.
 */
export function useReturnActions(orderId: string) {
  // Opens as 'requested' — identical to how a customer-filed return starts,
  // so staff-created and self-service returns share one path.
  const create = useReturnMutation(
    orderId,
    ({
      reasonId,
      stockLocationId,
      ...params
    }: {
      items: Array<{ fulfillment_item_id: string; quantity: number }>
      memo?: string
      reasonId?: string
      stockLocationId?: string
    }) =>
      adminClient.orders.returns.create(orderId, {
        ...params,
        reason_id: reasonId,
        stock_location_id: stockLocationId,
      }),
  )

  const approve = useReturnMutation(orderId, (returnId: string) =>
    adminClient.orders.returns.approve(orderId, returnId),
  )

  const receive = useReturnMutation(
    orderId,
    ({
      returnId,
      items,
    }: {
      returnId: string
      items?: Array<{ return_line_item_id: string; quantity: number; resellable?: boolean }>
    }) => adminClient.orders.returns.receive(orderId, returnId, items ? { items } : undefined),
  )

  const refund = useReturnMutation(
    orderId,
    ({
      returnId,
      refundMethod,
      amount,
    }: {
      returnId: string
      refundMethod?: 'original_payment' | 'store_credit'
      amount?: string
    }) =>
      adminClient.orders.returns.refund(orderId, returnId, {
        refund_method: refundMethod,
        amount,
      }),
  )

  const cancel = useReturnMutation(
    orderId,
    ({ returnId, reason }: { returnId: string; reason?: string }) =>
      adminClient.orders.returns.cancel(orderId, returnId, { reason }),
  )

  // The prepaid label for the parcel coming back. Buying takes no body; a
  // `file` records postage the merchant bought elsewhere instead.
  const buyLabel = useReturnMutation(
    orderId,
    ({ returnId, ...params }: { returnId: string } & ShippingLabelCreateParams) =>
      adminClient.orders.returns.labels.create(orderId, returnId, params),
  )

  const refundLabel = useReturnMutation(
    orderId,
    ({ returnId, labelId }: { returnId: string; labelId: string }) =>
      adminClient.orders.returns.labels.refund(orderId, returnId, labelId),
  )

  const deleteLabel = useReturnMutation(
    orderId,
    ({ returnId, labelId }: { returnId: string; labelId: string }) =>
      adminClient.orders.returns.labels.delete(orderId, returnId, labelId),
  )

  return { create, approve, receive, refund, cancel, buyLabel, refundLabel, deleteLabel }
}

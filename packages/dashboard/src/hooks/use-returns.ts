import { adminClient, useResourceKey, useResourceKeyBuilder } from '@spree/dashboard-core'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { toast } from 'sonner'

/**
 * Returns on an order. Fetched separately from the order itself so the order
 * payload stays lean — most orders have none.
 */
export function useOrderReturns(orderId: string) {
  return useQuery({
    queryKey: useResourceKey('order-returns', orderId),
    queryFn: () =>
      adminClient.orders.returns.list(orderId, {
        expand: ['return_line_items', 'return_line_items.variant'],
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
    },
    onError: (error) => {
      // Without this a rejected workflow — a claim with nothing to refund, a
      // return that cannot be cancelled — looked like a dead button.
      toast.error(error instanceof Error ? error.message : String(error))
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
    (params: { items: Array<{ fulfillment_item_id: string; quantity: number }>; memo?: string }) =>
      adminClient.orders.returns.create(orderId, params),
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

  return { create, approve, receive, refund, cancel }
}

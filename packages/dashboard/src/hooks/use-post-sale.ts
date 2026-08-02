import { adminClient, useResourceKey, useResourceKeyBuilder } from '@spree/dashboard-core'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'

/**
 * Exchanges and claims on an order. Fetched separately from the order for the
 * same reason returns are — most orders have neither.
 */
export function useOrderExchanges(orderId: string) {
  return useQuery({
    queryKey: useResourceKey('order-exchanges', orderId),
    queryFn: () =>
      adminClient.orders.exchanges.list(orderId, {
        expand: [
          'exchange_line_items',
          'exchange_line_items.original_variant',
          'exchange_line_items.new_variant',
        ],
      }),
    enabled: !!orderId,
  })
}

export function useOrderClaims(orderId: string) {
  return useQuery({
    queryKey: useResourceKey('order-claims', orderId),
    queryFn: () =>
      adminClient.orders.claims.list(orderId, {
        expand: ['claim_line_items', 'claim_line_items.variant'],
      }),
    enabled: !!orderId,
  })
}

/**
 * Post-sale mutations refresh their own list and the order, since fulfilling
 * an exchange or resolving a claim moves the order's totals and fulfillments.
 */
function usePostSaleMutation<TParams>(
  orderId: string,
  resourceKey: string,
  mutationFn: (params: TParams) => Promise<unknown>,
) {
  const queryClient = useQueryClient()
  const buildKey = useResourceKeyBuilder()

  return useMutation({
    mutationFn,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: buildKey(resourceKey, orderId) })
      queryClient.invalidateQueries({ queryKey: buildKey('orders', orderId) })
    },
  })
}

export function useExchangeActions(orderId: string) {
  const approve = usePostSaleMutation(orderId, 'order-exchanges', (exchangeId: string) =>
    adminClient.orders.exchanges.approve(orderId, exchangeId),
  )

  const receive = usePostSaleMutation(
    orderId,
    'order-exchanges',
    ({
      exchangeId,
      items,
    }: {
      exchangeId: string
      items?: Array<{ exchange_line_item_id: string; quantity: number; resellable?: boolean }>
    }) => adminClient.orders.exchanges.receive(orderId, exchangeId, items ? { items } : undefined),
  )

  const fulfill = usePostSaleMutation(
    orderId,
    'order-exchanges',
    ({
      exchangeId,
      refundMethod,
    }: {
      exchangeId: string
      refundMethod?: 'original_payment' | 'store_credit'
    }) =>
      adminClient.orders.exchanges.fulfill(orderId, exchangeId, { refund_method: refundMethod }),
  )

  const cancel = usePostSaleMutation(
    orderId,
    'order-exchanges',
    ({ exchangeId, reason }: { exchangeId: string; reason?: string }) =>
      adminClient.orders.exchanges.cancel(orderId, exchangeId, { reason }),
  )

  return { approve, receive, fulfill, cancel }
}

export function useClaimActions(orderId: string) {
  const approve = usePostSaleMutation(orderId, 'order-claims', (claimId: string) =>
    adminClient.orders.claims.approve(orderId, claimId),
  )

  const resolve = usePostSaleMutation(
    orderId,
    'order-claims',
    ({
      claimId,
      resolution,
      refundMethod,
      amount,
    }: {
      claimId: string
      resolution: 'refund' | 'replacement' | 'refund_and_replacement'
      refundMethod?: 'original_payment' | 'store_credit'
      amount?: string
    }) =>
      adminClient.orders.claims.resolve(orderId, claimId, {
        resolution,
        refund_method: refundMethod,
        amount,
      }),
  )

  const deny = usePostSaleMutation(
    orderId,
    'order-claims',
    ({ claimId, reason }: { claimId: string; reason?: string }) =>
      adminClient.orders.claims.deny(orderId, claimId, { reason }),
  )

  const cancel = usePostSaleMutation(
    orderId,
    'order-claims',
    ({ claimId, reason }: { claimId: string; reason?: string }) =>
      adminClient.orders.claims.cancel(orderId, claimId, { reason }),
  )

  return { approve, resolve, deny, cancel }
}

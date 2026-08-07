import { adminClient, useResourceKey, useResourceKeyBuilder } from '@spree/dashboard-core'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { toast } from 'sonner'

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
  countKey: string,
  mutationFn: (params: TParams) => Promise<unknown>,
) {
  const queryClient = useQueryClient()
  const buildKey = useResourceKeyBuilder()

  return useMutation({
    mutationFn,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: buildKey(resourceKey, orderId) })
      queryClient.invalidateQueries({ queryKey: buildKey('orders', orderId) })
      // The sidebar count is keyed separately and would otherwise keep a
      // stale figure until a page reload — resolving a claim is exactly what
      // takes it out of the count.
      queryClient.invalidateQueries({ queryKey: buildKey(`${countKey}-pending`) })
    },
    onError: (error) => {
      // Without this a rejected workflow — a claim with nothing to refund, a
      // return that cannot be cancelled — looked like a dead button.
      toast.error(error instanceof Error ? error.message : String(error))
    },
  })
}

export function useExchangeActions(orderId: string) {
  const create = usePostSaleMutation(
    orderId,
    'order-exchanges',
    'exchanges',
    ({
      reasonId,
      ...params
    }: {
      items: Array<{ fulfillment_item_id: string; new_variant_id: string; quantity: number }>
      memo?: string
      reasonId?: string
    }) => adminClient.orders.exchanges.create(orderId, { ...params, reason_id: reasonId }),
  )

  const approve = usePostSaleMutation(
    orderId,
    'order-exchanges',
    'exchanges',
    (exchangeId: string) => adminClient.orders.exchanges.approve(orderId, exchangeId),
  )

  const receive = usePostSaleMutation(
    orderId,
    'order-exchanges',
    'exchanges',
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
    'exchanges',
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
    'exchanges',
    ({ exchangeId, reason }: { exchangeId: string; reason?: string }) =>
      adminClient.orders.exchanges.cancel(orderId, exchangeId, { reason }),
  )

  return { create, approve, receive, fulfill, cancel }
}

export function useClaimActions(orderId: string) {
  const create = usePostSaleMutation(
    orderId,
    'order-claims',
    'claims',
    (params: {
      items: Array<{
        line_item_id: string
        quantity: number
        description?: string
        refund_amount?: string
      }>
      memo?: string
      reasonId?: string
    }) => {
      const { reasonId, ...rest } = params
      return adminClient.orders.claims.create(orderId, { ...rest, reason_id: reasonId })
    },
  )

  const approve = usePostSaleMutation(orderId, 'order-claims', 'claims', (claimId: string) =>
    adminClient.orders.claims.approve(orderId, claimId),
  )

  const resolve = usePostSaleMutation(
    orderId,
    'order-claims',
    'claims',
    ({
      claimId,
      resolution,
      refundMethod,
      amount,
      replacementLineItemIds,
    }: {
      claimId: string
      resolution: 'refund' | 'replacement' | 'refund_and_replacement'
      refundMethod?: 'original_payment' | 'store_credit'
      amount?: string
      replacementLineItemIds?: string[]
    }) =>
      adminClient.orders.claims.resolve(orderId, claimId, {
        resolution,
        refund_method: refundMethod,
        amount,
        replacement_line_item_ids: replacementLineItemIds,
      }),
  )

  const deny = usePostSaleMutation(
    orderId,
    'order-claims',
    'claims',
    ({ claimId, reason }: { claimId: string; reason?: string }) =>
      adminClient.orders.claims.deny(orderId, claimId, { reason }),
  )

  const cancel = usePostSaleMutation(
    orderId,
    'order-claims',
    'claims',
    ({ claimId, reason }: { claimId: string; reason?: string }) =>
      adminClient.orders.claims.cancel(orderId, claimId, { reason }),
  )

  return { create, approve, resolve, deny, cancel }
}

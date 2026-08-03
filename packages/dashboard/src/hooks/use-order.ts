import { adminClient, useResourceKey, useResourceKeyBuilder } from '@spree/dashboard-core'
import { type QueryKey, useMutation, useQuery, useQueryClient } from '@tanstack/react-query'

export function useOrder(orderId: string) {
  return useQuery({
    queryKey: useResourceKey('orders', orderId),
    queryFn: () =>
      adminClient.orders.get(orderId, {
        expand: [
          'items',
          'fulfillments',
          'fulfillments.fulfillment_items',
          'fulfillments.delivery_method',
          'fulfillments.stock_location',
          'payments',
          'payments.payment_method',
          'billing_address',
          'shipping_address',
          'customer',
          'created_by',
          'canceler',
          'approver',
          'market',
          'channel',
        ],
      }),
    enabled: !!orderId,
  })
}

/**
 * Generic factory for an order mutation that invalidates the order detail
 * query on success. Use this for operations that don't fit the toast-bundled
 * `useResourceMutation` (e.g., chained updates, custom error handling).
 */
export function useOrderMutation<TParams>(
  orderId: string,
  mutationFn: (params: TParams) => Promise<unknown>,
) {
  const queryClient = useQueryClient()
  const buildKey = useResourceKeyBuilder()
  return useMutation({
    mutationFn,
    onSuccess: () => queryClient.invalidateQueries({ queryKey: buildKey('orders', orderId) }),
  })
}

/**
 * Bare logical key for an order — pass to `useResourceMutation`'s
 * `invalidate:` and the storeId will be auto-injected at position 1.
 */
export function orderQueryKey(orderId: string): QueryKey {
  return ['orders', orderId]
}

export function useOrderTaxLines(orderId: string) {
  return useQuery({
    queryKey: useResourceKey('orders', orderId, 'tax_lines'),
    queryFn: () => adminClient.orders.taxLines.list(orderId),
    enabled: !!orderId,
  })
}

export function useOrderDiscounts(orderId: string) {
  return useQuery({
    queryKey: useResourceKey('orders', orderId, 'discounts'),
    queryFn: () => adminClient.orders.discounts.list(orderId),
    enabled: !!orderId,
  })
}

export function useOrderFees(orderId: string) {
  return useQuery({
    queryKey: useResourceKey('orders', orderId, 'fees'),
    queryFn: () => adminClient.orders.fees.list(orderId),
    enabled: !!orderId,
  })
}

/**
 * Mutation for typed adjustment rows: invalidates the order detail AND the
 * nested tax_lines/discounts/fees lists (totals change server-side on every
 * row mutation).
 */
export function useOrderAdjustmentLinesMutation<TParams>(
  orderId: string,
  mutationFn: (params: TParams) => Promise<unknown>,
) {
  const queryClient = useQueryClient()
  const buildKey = useResourceKeyBuilder()
  return useMutation({
    mutationFn,
    onSuccess: () => queryClient.invalidateQueries({ queryKey: buildKey('orders', orderId) }),
  })
}

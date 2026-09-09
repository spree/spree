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
          'fulfillments.delivery_rates',
          'fulfillments.delivery_rates.delivery_method',
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

async function listAllCommissionLines(orderId: string) {
  const params = {
    q: { order_id_eq: orderId },
    limit: 100,
    expand: ['commission_rate'],
  }
  const first = await adminClient.commissionLines.list({ ...params, page: 1 })
  const rest = await Promise.all(
    Array.from({ length: (first.meta?.pages ?? 1) - 1 }, (_, index) =>
      adminClient.commissionLines.list({ ...params, page: index + 2 }),
    ),
  )

  return {
    ...first,
    data: [...first.data, ...rest.flatMap((page) => page.data)],
  }
}

export function useOrderCommissionLines(orderId: string, options?: { enabled?: boolean }) {
  return useQuery({
    queryKey: useResourceKey('orders', orderId, 'commission_lines'),
    queryFn: () => listAllCommissionLines(orderId),
    enabled: !!orderId && (options?.enabled ?? true),
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

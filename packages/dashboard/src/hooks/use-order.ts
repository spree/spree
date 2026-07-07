import { adminClient, i18n, useResourceKey, useResourceKeyBuilder } from '@spree/dashboard-core'
import { type QueryKey, useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { toast } from 'sonner'

export function useOrder(orderId: string) {
  return useQuery({
    queryKey: useResourceKey('orders', orderId),
    queryFn: () =>
      adminClient.orders.get(orderId, {
        expand: [
          'items',
          'fulfillments',
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
 * `useResourceMutation` (e.g., chained updates like create-then-capture
 * payment). Errors always toast — none of these call sites render field-level
 * errors, so there's nothing else to surface a failure to the merchant.
 */
export function useOrderMutation<TParams>(
  orderId: string,
  mutationFn: (params: TParams) => Promise<unknown>,
  errorMessage: string = i18n.t('admin.errors.generic'),
) {
  const queryClient = useQueryClient()
  const buildKey = useResourceKeyBuilder()
  return useMutation({
    mutationFn,
    onSuccess: () => queryClient.invalidateQueries({ queryKey: buildKey('orders', orderId) }),
    onError: () => toast.error(errorMessage),
  })
}

/**
 * Bare logical key for an order — pass to `useResourceMutation`'s
 * `invalidate:` and the storeId will be auto-injected at position 1.
 */
export function orderQueryKey(orderId: string): QueryKey {
  return ['orders', orderId]
}

import { useResourceKey, useResourceKeyBuilder } from '@spree/dashboard-core'
import { toastManager } from '@spree/dashboard-ui'
import type { Order } from '@spree/seller-sdk'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { sellerClient } from '../api-client'

/** One order, with everything the page renders about it. */
export function useOrder(orderId: string) {
  return useQuery({
    queryKey: useResourceKey('seller-order', orderId),
    queryFn: () => sellerClient().orders.get(orderId),
    enabled: !!orderId,
  })
}

/** The key a mutation elsewhere invalidates to refresh this order. */
export function useOrderKeyBuilder() {
  return useResourceKeyBuilder()
}

/**
 * A write against the order itself. Refreshes the order and the list behind
 * it — a canceled order reads differently in both places.
 */
export function useOrderMutation<TParams, TResult = Order>(
  orderId: string,
  mutationFn: (params: TParams) => Promise<TResult>,
) {
  const queryClient = useQueryClient()
  const buildKey = useResourceKeyBuilder()

  return useMutation({
    mutationFn,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: buildKey('seller-order', orderId) })
      queryClient.invalidateQueries({ queryKey: buildKey('seller-orders') })
    },
    onError: (error) => {
      toastManager.add({
        type: 'error',
        title: error instanceof Error ? error.message : String(error),
      })
    },
  })
}

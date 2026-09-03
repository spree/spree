import { useResourceKey } from '@spree/dashboard-core'
import { useQuery } from '@tanstack/react-query'
import { sellerClient } from '../api-client'

export type ReasonKind = 'return-reasons' | 'claim-reasons' | 'order-cancellation-reasons'

/**
 * The marketplace's vocabulary for why goods came back, what went wrong, or
 * why an order was called off. Operator-owned and slow-moving, so one fetch
 * serves every dialog.
 */
export function useReasons(kind: ReasonKind, enabled = true) {
  return useQuery({
    queryKey: useResourceKey(kind),
    queryFn: () => {
      const client = sellerClient()
      if (kind === 'return-reasons') return client.returnReasons.list()
      if (kind === 'claim-reasons') return client.claimReasons.list()
      return client.orderCancellationReasons.list()
    },
    staleTime: 5 * 60 * 1000,
    enabled,
  })
}

/** Registry data — it only changes on deploy. */
export function useTrackingCarriers(enabled = true) {
  return useQuery({
    queryKey: useResourceKey('seller-tracking-carriers'),
    queryFn: () => sellerClient().trackingCarriers.list(),
    staleTime: Number.POSITIVE_INFINITY,
    enabled,
  })
}

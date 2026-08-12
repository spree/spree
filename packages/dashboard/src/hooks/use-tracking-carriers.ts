import { adminClient, useResourceKey } from '@spree/dashboard-core'
import { useQuery } from '@tanstack/react-query'

/**
 * The registered tracking carriers a number can be pinned to. Registry data —
 * it only changes on deploy, so one long-lived fetch serves every dialog.
 */
export function useTrackingCarriers(enabled = true) {
  return useQuery({
    queryKey: useResourceKey('tracking-carriers'),
    queryFn: () => adminClient.trackingCarriers.list(),
    staleTime: Number.POSITIVE_INFINITY,
    enabled,
  })
}

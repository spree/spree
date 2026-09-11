import type { DashboardCounter } from '@spree/admin-sdk'
import { adminClient, useResourceKey } from '@spree/dashboard-core'
import { useQuery } from '@tanstack/react-query'

/**
 * The point-in-time counts registered on `Spree.reporting`: what needs the
 * merchant's attention right now.
 *
 * One request serves the home screen's card and every sidebar badge — the
 * key is the channel, so the unscoped call the sidebar makes is shared with
 * the home screen whenever no channel is selected. Counters the caller may
 * not read are absent from the response rather than zero, so a badge for one
 * simply never renders.
 *
 * @param channelId prefixed channel id, or undefined for all channels
 */
export function useDashboardCounters(channelId?: string) {
  return useQuery({
    queryKey: useResourceKey('dashboard', 'counters', channelId),
    queryFn: () => adminClient.dashboard.counters({ channel_id: channelId }),
    // No `placeholderData`: it would belong to the channel selected before,
    // and showing another channel's counts under this one's name is worse
    // than showing the skeleton for a moment.
    staleTime: 5 * 60 * 1000,
  })
}

/**
 * One counter by key, or undefined when it is still loading, absent, or the
 * caller cannot read it.
 */
export function useDashboardCounter(key: string): DashboardCounter | undefined {
  const { data } = useDashboardCounters()

  return data?.counters.find((counter) => counter.key === key)
}

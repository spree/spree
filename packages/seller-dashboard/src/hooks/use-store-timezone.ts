import { useQuery } from '@tanstack/react-query'
import { useParams } from '@tanstack/react-router'
import { sellerClient } from '../api-client'

/**
 * The marketplace's timezone, as every date in this panel is read in.
 *
 * A seller keeps no clock of their own — a settlement period is decided by
 * the marketplace's day, so a timestamp rendered in whichever zone the
 * seller's browser sits in would put an earning on the wrong date for
 * anyone trading away from the marketplace.
 *
 * Falls back to the browser's zone only until the profile arrives, matching
 * what the operator dashboard's `useStore` does.
 */
export function useStoreTimezone(): string {
  const { sellerId } = useParams({ from: '/_authenticated/$sellerId' })

  const { data: profile } = useQuery({
    queryKey: ['seller', sellerId, 'profile'],
    queryFn: () => sellerClient().profile.get(),
    enabled: Boolean(sellerId),
  })

  return profile?.preferred_timezone ?? Intl.DateTimeFormat().resolvedOptions().timeZone ?? 'UTC'
}

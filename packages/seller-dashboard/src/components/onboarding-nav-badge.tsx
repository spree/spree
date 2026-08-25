import { Badge } from '@spree/dashboard-ui'
import { useQuery } from '@tanstack/react-query'
import { useParams } from '@tanstack/react-router'
import { sellerClient } from '../api-client'

/**
 * Progress counter beside the onboarding nav entry, mirroring the operator's
 * Getting Started badge — a seller can see how far along they are without
 * opening the page.
 *
 * Shares the onboarding query key with the page itself, so the two read one
 * cache entry: the badge updates the moment a task completes, and visiting
 * the page costs no extra request.
 *
 * Hidden once everything is done, like its operator twin — a badge that
 * always reads `4/4` is noise.
 */
export function OnboardingNavBadge() {
  // `strict: false`: the badge renders inside the sidebar, which the seller
  // picker also mounts — there is no `$sellerId` in scope there.
  const { sellerId } = useParams({ strict: false }) as { sellerId?: string }

  const { data } = useQuery({
    queryKey: ['seller', sellerId, 'onboarding'],
    queryFn: () => sellerClient().onboarding.get(),
    enabled: Boolean(sellerId),
  })

  const progress = data?.progress
  if (!progress || progress.total === 0 || progress.done === progress.total) return null

  return (
    <Badge variant="outline" className="mr-1 flex items-center gap-0 rounded-lg">
      <span>{progress.done}</span>
      <span className="opacity-50">/{progress.total}</span>
    </Badge>
  )
}

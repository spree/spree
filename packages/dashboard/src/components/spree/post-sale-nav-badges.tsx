import { adminClient, useResourceKey } from '@spree/dashboard-core'
import { Badge } from '@spree/dashboard-ui'
import { useQuery } from '@tanstack/react-query'

/**
 * How many records still need the merchant to do something. Asks for a single
 * row and reads the total off the pagination meta, so the sidebar never pulls
 * a full page it does not render.
 *
 * Ransack predicates go at the top level — `transformListParams` wraps every
 * key it does not recognise in `q[...]`, so nesting them under `q` produces
 * `q[q]` and the filter is silently ignored.
 */
function usePendingCount(
  resourceKey: string,
  statuses: string[],
  list: (params: Record<string, unknown>) => Promise<{ meta?: { count?: number } }>,
) {
  const { data } = useQuery({
    queryKey: useResourceKey(`${resourceKey}-pending`),
    queryFn: () => list({ limit: 1, status_in: statuses }),
    // The sidebar is always mounted; without this it would refetch on every
    // navigation.
    staleTime: 60_000,
  })

  return data?.meta?.count ?? 0
}

function CountBadge({ count }: { count: number }) {
  if (count === 0) return null

  return (
    <Badge variant="outline" className="rounded-lg mr-1">
      {count}
    </Badge>
  )
}

// Everything still in flight, not just the first step: an approved return
// still needs receiving and refunding, so it is as much outstanding work as
// one nobody has looked at. Terminal statuses — refunded, fulfilled,
// resolved, denied, canceled — are done and drop out of the count.
const RETURNS_IN_PROGRESS = ['requested', 'approved', 'received']
const EXCHANGES_IN_PROGRESS = ['requested', 'approved', 'received']
const CLAIMS_IN_PROGRESS = ['open', 'approved']

export function ReturnsNavBadge() {
  return (
    <CountBadge count={usePendingCount('returns', RETURNS_IN_PROGRESS, adminClient.returns.list)} />
  )
}

export function ExchangesNavBadge() {
  return (
    <CountBadge
      count={usePendingCount('exchanges', EXCHANGES_IN_PROGRESS, adminClient.exchanges.list)}
    />
  )
}

export function ClaimsNavBadge() {
  return (
    <CountBadge count={usePendingCount('claims', CLAIMS_IN_PROGRESS, adminClient.claims.list)} />
  )
}

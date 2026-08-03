import { adminClient, useResourceKey } from '@spree/dashboard-core'
import { Badge } from '@spree/dashboard-ui'
import { useQuery } from '@tanstack/react-query'

/**
 * How many records are waiting on the merchant. Asks for a single row and
 * reads the total off the pagination meta, so the sidebar never pulls a full
 * page it does not render.
 */
function usePendingCount(
  resourceKey: string,
  status: string,
  list: (params: Record<string, unknown>) => Promise<{ meta?: { count?: number } }>,
) {
  const { data } = useQuery({
    queryKey: useResourceKey(`${resourceKey}-pending`),
    queryFn: () => list({ limit: 1, q: { status_eq: status } }),
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

/** Returns a customer has opened and nobody has approved yet. */
export function ReturnsNavBadge() {
  return <CountBadge count={usePendingCount('returns', 'requested', adminClient.returns.list)} />
}

export function ExchangesNavBadge() {
  return (
    <CountBadge count={usePendingCount('exchanges', 'requested', adminClient.exchanges.list)} />
  )
}

/** Claims start as `open` rather than `requested`. */
export function ClaimsNavBadge() {
  return <CountBadge count={usePendingCount('claims', 'open', adminClient.claims.list)} />
}

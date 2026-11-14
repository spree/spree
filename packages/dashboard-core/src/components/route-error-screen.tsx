import { ErrorState } from '@spree/dashboard-ui'
import { type ErrorComponentProps, useRouter } from '@tanstack/react-router'
import { queryClient } from '../lib/query-client'

/**
 * The panels' router error screen. "Try again" drops the data cached for the
 * page that failed and reloads the route, so a request that failed once or
 * returned bad data is fetched again instead of failing the same way.
 */
export function RouteErrorScreen({ error, reset }: ErrorComponentProps) {
  const router = useRouter()
  const retry = async () => {
    // The failed page has unmounted: its own queries are dropped and fetched
    // on remount, and those the panel chrome still shows (which the page may
    // share) are fetched again now.
    queryClient.removeQueries({ type: 'inactive' })
    await Promise.all([queryClient.refetchQueries({ type: 'active' }), router.invalidate()])
    reset()
  }
  return <ErrorState error={error} onRetry={retry} />
}

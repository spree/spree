import { adminClient, Subject, usePermissions, useResourceKey } from '@spree/dashboard-core'
import { useQuery } from '@tanstack/react-query'

// The server can't see which dashboard was deployed, so the build tells it.
const packages =
  typeof __SPREE_PACKAGES__ === 'undefined'
    ? []
    : Object.entries(__SPREE_PACKAGES__).map(([name, version]) => `${name}@${version}`)

/**
 * The anonymised diagnostics report for bug reports. Only fetched for staff
 * who can manage the store: the endpoint refuses everyone else.
 */
export function useDiagnostics() {
  const { permissions } = usePermissions()

  return useQuery({
    queryKey: useResourceKey('diagnostics'),
    queryFn: () => adminClient.diagnostics.get({ packages }),
    enabled: permissions.can('manage', Subject.Store),
    refetchOnWindowFocus: false,
    retry: false,
  })
}

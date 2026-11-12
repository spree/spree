import { adminClient, Subject, usePermissions, useResourceKey } from '@spree/dashboard-core'
import { useQuery } from '@tanstack/react-query'

const HOUR = 60 * 60 * 1000

/**
 * Whether a newer Spree release exists. Only fetched for staff who can manage
 * the store: the endpoint refuses everyone else, and the running version is
 * not theirs to see.
 */
export function useUpdateStatus() {
  const { permissions } = usePermissions()

  return useQuery({
    queryKey: useResourceKey('update-status'),
    queryFn: () => adminClient.updates.get(),
    enabled: permissions.can('manage', Subject.Store),
    staleTime: HOUR,
    refetchOnWindowFocus: false,
    retry: false,
  })
}

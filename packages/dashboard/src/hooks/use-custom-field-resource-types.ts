import { adminClient, useResourceKey } from '@spree/dashboard-core'
import { useQuery } from '@tanstack/react-query'

/**
 * What a custom field definition can be attached to.
 *
 * Read from the server's registry rather than a list in the dashboard: an
 * extension that registers a resource is then offered without a dashboard
 * release, and a merchant is never shown a type the API would refuse.
 */
export function useCustomFieldResourceTypes() {
  return useQuery({
    queryKey: useResourceKey('custom-field-definitions', 'resource-types'),
    queryFn: () => adminClient.customFieldDefinitions.resourceTypes(),
    staleTime: Infinity,
  })
}

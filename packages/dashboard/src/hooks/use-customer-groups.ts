import type {
  CustomerGroup,
  CustomerGroupCreateParams,
  CustomerGroupUpdateParams,
} from '@spree/admin-sdk'
import {
  adminClient,
  useResourceKey,
  useResourceKeyBuilder,
  useResourceMutation,
} from '@spree/dashboard-core'
import { useQuery, useQueryClient } from '@tanstack/react-query'

/**
 * Shared config for any `<ResourceMultiAutocomplete>` picking customer
 * groups (table filter, bulk-action sheet, promotion-rule editor). Pass
 * a unique `queryKey` per instance so independent caches don't collide.
 */
export function customerGroupAutocompleteProps(queryKey: string) {
  return {
    queryKey,
    search: (q: string) =>
      adminClient.customerGroups.list({ name_cont: q, limit: 20, sort: 'name' }),
    hydrate: (ids: string[]) => adminClient.customerGroups.list({ id_in: ids, limit: ids.length }),
    getOptionLabel: (g: CustomerGroup) => g.name ?? g.id,
    placeholder: 'Search customer groups…',
    emptyText: 'No customer groups match',
  }
}

export function useCustomerGroup(id: string | undefined, expand?: string[]) {
  const base = useResourceKey('customer-groups', id ?? 'noop')
  return useQuery({
    queryKey: expand?.length ? [...base, { expand }] : base,
    queryFn: () => adminClient.customerGroups.get(id as string, { expand }),
    enabled: !!id,
  })
}

export function useCreateCustomerGroup() {
  return useResourceMutation<CustomerGroup, Error, CustomerGroupCreateParams>({
    mutationFn: (params) => adminClient.customerGroups.create(params),
    invalidate: [['customer-groups']],
    successMessage: 'Customer group created',
    errorMessage: 'Failed to create customer group',
  })
}

export function useUpdateCustomerGroup(id: string) {
  return useResourceMutation<CustomerGroup, Error, CustomerGroupUpdateParams>({
    mutationFn: (params) => adminClient.customerGroups.update(id, params),
    invalidate: [['customer-groups'], ['customer-groups', id]],
    successMessage: 'Customer group updated',
    errorMessage: 'Failed to update customer group',
  })
}

export function useDeleteCustomerGroup() {
  const queryClient = useQueryClient()
  const buildKey = useResourceKeyBuilder()

  return useResourceMutation<void, Error, string>({
    mutationFn: (id) => adminClient.customerGroups.delete(id),
    invalidate: [['customer-groups']],
    successMessage: 'Customer group deleted',
    errorMessage: 'Failed to delete customer group',
    onSuccess: (_data, id) => {
      queryClient.removeQueries({ queryKey: buildKey('customer-groups', id) })
    },
  })
}

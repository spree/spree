import type {
  CustomerGroup,
  CustomerGroupCreateParams,
  CustomerGroupUpdateParams,
} from '@spree/admin-sdk'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import { adminClient } from '@/client'
import { useResourceMutation } from '@/hooks/use-resource-mutation'

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

export const customerGroupsQueryKey = ['customer-groups'] as const

export function customerGroupQueryKey(id: string, expand?: string[]) {
  return expand?.length
    ? (['customer-groups', id, { expand }] as const)
    : (['customer-groups', id] as const)
}

export function useCustomerGroup(id: string | undefined, expand?: string[]) {
  return useQuery({
    queryKey: id ? customerGroupQueryKey(id, expand) : ['customer-groups', 'noop'],
    queryFn: () => adminClient.customerGroups.get(id as string, { expand }),
    enabled: !!id,
  })
}

export function useCreateCustomerGroup() {
  return useResourceMutation<CustomerGroup, Error, CustomerGroupCreateParams>({
    mutationFn: (params) => adminClient.customerGroups.create(params),
    invalidate: [customerGroupsQueryKey],
    successMessage: 'Customer group created',
    errorMessage: 'Failed to create customer group',
  })
}

export function useUpdateCustomerGroup(id: string) {
  return useResourceMutation<CustomerGroup, Error, CustomerGroupUpdateParams>({
    mutationFn: (params) => adminClient.customerGroups.update(id, params),
    invalidate: [customerGroupsQueryKey, customerGroupQueryKey(id)],
    successMessage: 'Customer group updated',
    errorMessage: 'Failed to update customer group',
  })
}

export function useDeleteCustomerGroup() {
  const queryClient = useQueryClient()

  return useResourceMutation<void, Error, string>({
    mutationFn: (id) => adminClient.customerGroups.delete(id),
    invalidate: [customerGroupsQueryKey],
    successMessage: 'Customer group deleted',
    errorMessage: 'Failed to delete customer group',
    onSuccess: (_data, id) => {
      queryClient.removeQueries({ queryKey: customerGroupQueryKey(id) })
    },
  })
}

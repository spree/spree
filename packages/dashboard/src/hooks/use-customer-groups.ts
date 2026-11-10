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
import i18n from 'i18next'

export function useCustomerGroups() {
  return useQuery({
    queryKey: useResourceKey('customer-groups'),
    queryFn: () => adminClient.customerGroups.list({ limit: 100, sort: 'name' }),
    staleTime: 1000 * 60 * 5,
  })
}

/**
 * Shared config for any `<ResourceMultiAutocomplete>` picking customer
 * groups (table filter, bulk-action sheet, promotion-rule editor). Pass
 * a unique `queryKey` per instance so independent caches don't collide.
 */
export function customerGroupAutocompleteProps(queryKey: string) {
  return {
    queryKey,
    search: (q: string) =>
      adminClient.customerGroups.list({ search: q, limit: 100, sort: 'name', fields: ['name'] }),
    hydrate: (ids: string[]) => adminClient.customerGroups.list({ id_in: ids, limit: ids.length }),
    getOptionLabel: (g: CustomerGroup) => g.name ?? g.id,
    placeholder: i18n.t('admin.customer_groups.autocomplete.placeholder'),
    emptyText: i18n.t('admin.customer_groups.autocomplete.empty'),
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
    successMessage: i18n.t('admin.customer_groups.messages.created'),
    errorMessage: i18n.t('admin.customer_groups.messages.create_failed'),
  })
}

export function useUpdateCustomerGroup(id: string) {
  return useResourceMutation<CustomerGroup, Error, CustomerGroupUpdateParams>({
    mutationFn: (params) => adminClient.customerGroups.update(id, params),
    invalidate: [['customer-groups'], ['customer-groups', id]],
    successMessage: i18n.t('admin.customer_groups.messages.updated'),
    errorMessage: i18n.t('admin.customer_groups.messages.update_failed'),
  })
}

export function useDeleteCustomerGroup() {
  const queryClient = useQueryClient()
  const buildKey = useResourceKeyBuilder()

  return useResourceMutation<void, Error, string>({
    mutationFn: (id) => adminClient.customerGroups.delete(id),
    invalidate: [['customer-groups']],
    successMessage: i18n.t('admin.customer_groups.messages.deleted'),
    errorMessage: i18n.t('admin.customer_groups.messages.delete_failed'),
    onSuccess: (_data, id) => {
      queryClient.removeQueries({ queryKey: buildKey('customer-groups', id) })
    },
  })
}

/** The customers in a group, a page at a time. */
export function useCustomerGroupMembers(groupId: string | undefined, page = 1, limit = 25) {
  return useQuery({
    queryKey: useResourceKey('customer-groups', groupId ?? 'noop', 'members', `${page}:${limit}`),
    queryFn: () =>
      adminClient.customers.list({ customer_groups_id_in: [groupId as string], page, limit }),
    enabled: !!groupId,
    placeholderData: (previous) => previous,
  })
}

/** Adds one customer to the group, through the bulk endpoint the list uses. */
export function useAddCustomerGroupMember(groupId: string) {
  return useResourceMutation({
    mutationFn: (customerId: string) =>
      adminClient.customers.bulkAddToGroups({ ids: [customerId], customer_group_ids: [groupId] }),
    invalidate: [['customer-groups'], ['customers']],
    successMessage: i18n.t('admin.customers.groups.detail.messages.member_added'),
    errorMessage: i18n.t('admin.customers.groups.detail.messages.member_change_failed'),
  })
}

/** Takes one customer out of the group; they stay a customer. */
export function useRemoveCustomerGroupMember(groupId: string) {
  return useResourceMutation({
    mutationFn: (customerId: string) =>
      adminClient.customers.bulkRemoveFromGroups({
        ids: [customerId],
        customer_group_ids: [groupId],
      }),
    invalidate: [['customer-groups'], ['customers']],
    successMessage: i18n.t('admin.customers.groups.detail.messages.member_removed'),
    errorMessage: i18n.t('admin.customers.groups.detail.messages.member_change_failed'),
  })
}

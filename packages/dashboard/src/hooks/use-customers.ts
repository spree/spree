import type { Customer } from '@spree/admin-sdk'
import {
  adminClient,
  i18n,
  useAuth,
  useResourceKey,
  useResourceMutation,
} from '@spree/dashboard-core'
import { useQuery } from '@tanstack/react-query'

/**
 * Shared config for any `<ResourceCombobox>` / `<ResourceMultiAutocomplete>`
 * picking customers (filter chips, gift-card recipient picker, order
 * creation, …). Pass a unique `queryKey` per instance so independent caches
 * don't collide.
 *
 * `Customer.search` is a Ransack alias the admin controller resolves into
 * `email_cont OR first_name_cont OR last_name_cont` — so a single query
 * narrows by either the email or the name.
 */
export function customerAutocompleteProps(queryKey: string) {
  return {
    queryKey,
    search: (q: string) => adminClient.customers.list({ search: q, limit: 10 }),
    hydrate: (ids: string[]) => adminClient.customers.list({ id_in: ids, limit: ids.length }),
    getOptionLabel: (c: Customer) => c.email ?? c.id,
    placeholder: 'Search customers…',
    emptyText: 'No customers match',
  }
}

export function useCustomer(customerId: string) {
  const { isAuthenticated } = useAuth()
  return useQuery({
    queryKey: useResourceKey('customers', customerId),
    queryFn: () =>
      adminClient.customers.get(customerId, { expand: ['addresses', 'store_credits'] }),
    enabled: isAuthenticated,
  })
}

type CustomerUpdateParams = Parameters<typeof adminClient.customers.update>[1]

export function useUpdateCustomer(customerId: string) {
  return useResourceMutation({
    mutationFn: (params: CustomerUpdateParams) => adminClient.customers.update(customerId, params),
    invalidate: [['customers', customerId]],
    successMessage: i18n.t('admin.messages.customer_saved'),
  })
}

export function useDeleteCustomer(customerId: string) {
  return useResourceMutation({
    mutationFn: () => adminClient.customers.delete(customerId),
    invalidate: [['customers'], ['customers', customerId]],
    successMessage: i18n.t('admin.messages.customer_deleted'),
  })
}

// `params` is spread into the queryKey so callers passing a fresh `{}` each
// render don't force a JSON-equality rehash on every paint.
export function useCustomerOrders(customerId: string, params: { limit: number; status?: string }) {
  const { isAuthenticated } = useAuth()
  return useQuery({
    queryKey: useResourceKey(
      'customers',
      customerId,
      'orders',
      params.limit,
      params.status ?? null,
    ),
    queryFn: () =>
      adminClient.orders.list({
        user_id_eq: customerId,
        ...(params.status ? { status_eq: params.status } : {}),
        limit: params.limit,
        sort: '-completed_at',
        expand: ['items'],
      }),
    enabled: isAuthenticated,
  })
}

// ---------------------------------------------------------------------------
// Addresses
// ---------------------------------------------------------------------------

type AddressCreateParams = Parameters<typeof adminClient.customers.addresses.create>[1]
type AddressUpdateParams = Parameters<typeof adminClient.customers.addresses.update>[2]

export function useCreateCustomerAddress(customerId: string) {
  return useResourceMutation({
    mutationFn: (params: AddressCreateParams) =>
      adminClient.customers.addresses.create(customerId, params),
    invalidate: [['customers', customerId]],
    successMessage: i18n.t('admin.messages.address_saved'),
  })
}

export function useUpdateCustomerAddress(customerId: string) {
  return useResourceMutation({
    mutationFn: ({ id, params }: { id: string; params: AddressUpdateParams }) =>
      adminClient.customers.addresses.update(customerId, id, params),
    invalidate: [['customers', customerId]],
    successMessage: i18n.t('admin.messages.address_saved'),
  })
}

export function useDeleteCustomerAddress(customerId: string) {
  return useResourceMutation({
    mutationFn: (id: string) => adminClient.customers.addresses.delete(customerId, id),
    invalidate: [['customers', customerId]],
    successMessage: i18n.t('admin.messages.address_removed'),
  })
}

// ---------------------------------------------------------------------------
// Bulk operations — index page bulk-action bar consumes these via its `run`
// hook. No success toast because BulkActionBar renders its own with the count.
// ---------------------------------------------------------------------------

type BulkGroupsParams = Parameters<typeof adminClient.customers.bulkAddToGroups>[0]

export function useBulkAddCustomersToGroups() {
  return useResourceMutation({
    mutationFn: (params: BulkGroupsParams) => adminClient.customers.bulkAddToGroups(params),
    successMessage: false,
    errorMessage: false,
  })
}

export function useBulkRemoveCustomersFromGroups() {
  return useResourceMutation({
    mutationFn: (params: BulkGroupsParams) => adminClient.customers.bulkRemoveFromGroups(params),
    successMessage: false,
    errorMessage: false,
  })
}

type BulkCustomerTagsParams = Parameters<typeof adminClient.customers.bulkAddTags>[0]

export function useBulkAddCustomerTags() {
  return useResourceMutation({
    mutationFn: (params: BulkCustomerTagsParams) => adminClient.customers.bulkAddTags(params),
    successMessage: false,
    errorMessage: false,
  })
}

export function useBulkRemoveCustomerTags() {
  return useResourceMutation({
    mutationFn: (params: BulkCustomerTagsParams) => adminClient.customers.bulkRemoveTags(params),
    successMessage: false,
    errorMessage: false,
  })
}

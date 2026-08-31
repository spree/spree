import type { Customer, TaxIdentifier, TaxIdentifierParams } from '@spree/admin-sdk'
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
/**
 * Customer picker wiring. Pass `companyId` to narrow the list to people who
 * may buy for that company — members of the node itself or of any ancestor,
 * since standing covers a node and everything below it. The query key carries
 * the company so switching it refetches rather than serving the previous
 * company's people from cache.
 */
export function customerAutocompleteProps(queryKey: string, companyId?: string | null) {
  const scope = companyId ? { with_standing_for_company: companyId } : {}
  return {
    queryKey: companyId ? `${queryKey}:${companyId}` : queryKey,
    search: (q: string) => adminClient.customers.list({ search: q, limit: 10, ...scope }),
    hydrate: (ids: string[]) => adminClient.customers.list({ id_in: ids, limit: ids.length }),
    getOptionLabel: (c: Customer) => c.email ?? c.id,
    placeholder: i18n.t('admin.customers.autocomplete.placeholder'),
    emptyText: companyId
      ? i18n.t('admin.customers.autocomplete.empty_for_company')
      : i18n.t('admin.customers.autocomplete.empty'),
  }
}

export function useCustomer(customerId: string) {
  const { isAuthenticated } = useAuth()
  return useQuery({
    queryKey: useResourceKey('customers', customerId),
    queryFn: () =>
      adminClient.customers.get(customerId, {
        expand: ['addresses', 'store_credits', 'customer_groups'],
      }),
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

// Group membership edits shift each affected group's `customers_count`, so this
// also invalidates the customer-groups list (and the customers index, whose
// rows render group chips) — unlike the plain `useUpdateCustomer` used for
// profile/note edits that don't touch membership.
export function useUpdateCustomerGroups(customerId: string) {
  return useResourceMutation({
    mutationFn: (customer_group_ids: string[]) =>
      adminClient.customers.update(customerId, { customer_group_ids }),
    invalidate: [['customers', customerId], ['customers'], ['customer-groups']],
    successMessage: i18n.t('admin.messages.customer_saved'),
    errorMessage: i18n.t('admin.customers.detail.groups.save_failed'),
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

// ---------------------------------------------------------------------------
// Tax identifiers — the customer's own registration, kept on their profile
// ---------------------------------------------------------------------------

export function useCustomerTaxIdentifiers(customerId: string | undefined) {
  return useQuery({
    queryKey: useResourceKey('customers', customerId ?? 'noop', 'tax-identifiers'),
    queryFn: () => adminClient.customers.taxIdentifiers.list(customerId as string),
    enabled: !!customerId,
  })
}

export function useCreateCustomerTaxIdentifier(customerId: string) {
  return useResourceMutation<TaxIdentifier, Error, TaxIdentifierParams>({
    mutationFn: (params) => adminClient.customers.taxIdentifiers.create(customerId, params),
    invalidate: [['customers', customerId, 'tax-identifiers']],
    successMessage: i18n.t('admin.tax_identifiers.messages.created'),
    errorMessage: i18n.t('admin.errors.failed_to_create'),
  })
}

/** The id travels with the variables so one hook serves every row. */
export function useUpdateCustomerTaxIdentifier(customerId: string) {
  return useResourceMutation<TaxIdentifier, Error, { id: string; params: TaxIdentifierParams }>({
    mutationFn: ({ id, params }) =>
      adminClient.customers.taxIdentifiers.update(customerId, id, params),
    invalidate: [['customers', customerId, 'tax-identifiers']],
    successMessage: i18n.t('admin.tax_identifiers.messages.updated'),
    errorMessage: i18n.t('admin.errors.failed_to_update'),
  })
}

export function useDeleteCustomerTaxIdentifier(customerId: string) {
  return useResourceMutation<void, Error, string>({
    mutationFn: (id) => adminClient.customers.taxIdentifiers.delete(customerId, id),
    invalidate: [['customers', customerId, 'tax-identifiers']],
    successMessage: i18n.t('admin.tax_identifiers.messages.deleted'),
    errorMessage: i18n.t('admin.errors.failed_to_delete'),
  })
}

export function useValidateCustomerTaxIdentifier(customerId: string) {
  return useResourceMutation<TaxIdentifier, Error, string>({
    mutationFn: (id) => adminClient.customers.taxIdentifiers.validate(customerId, id),
    invalidate: [['customers', customerId, 'tax-identifiers']],
    successMessage: i18n.t('admin.tax_identifiers.messages.validation_requested'),
    errorMessage: i18n.t('admin.tax_identifiers.messages.validation_failed'),
  })
}

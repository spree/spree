import type { Customer } from '@spree/admin-sdk'
import { adminClient } from '@/client'

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

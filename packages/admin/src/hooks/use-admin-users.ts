import type { AdminUser } from '@spree/admin-sdk'
import { adminClient } from '@/client'

/**
 * Shared config for any `<ResourceCombobox>` / `<ResourceMultiAutocomplete>`
 * picking admin users / staff (filter chips, "created by" lookups, …).
 * Falls back to filtering by email substring — the admin controller doesn't
 * expose a `search` alias, so we hit `email_cont` directly.
 */
export function adminUserAutocompleteProps(queryKey: string) {
  return {
    queryKey,
    search: (q: string) => adminClient.adminUsers.list({ email_cont: q, limit: 10 }),
    hydrate: (ids: string[]) => adminClient.adminUsers.list({ id_in: ids, limit: ids.length }),
    getOptionLabel: (a: AdminUser) => a.email ?? a.id,
    placeholder: 'Search staff…',
    emptyText: 'No staff match',
  }
}

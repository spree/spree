import type { Category } from '@spree/admin-sdk'
import { adminClient, useResourceKey } from '@spree/dashboard-core'
import { useQuery } from '@tanstack/react-query'
import i18n from 'i18next'

export function useCategories() {
  return useQuery({
    queryKey: useResourceKey('categories'),
    queryFn: () => adminClient.categories.list({ limit: 100 }),
    staleTime: 1000 * 60 * 5,
  })
}

/**
 * Shared config for any `<ResourceMultiAutocomplete>` picking categories
 * (product edit page, bulk-action dialog, promotion-rule editor). Pass a
 * unique `queryKey` per instance so independent caches don't collide.
 */
export function categoryAutocompleteProps(queryKey: string) {
  return {
    queryKey,
    search: (q: string) =>
      adminClient.categories.list({ name_cont: q, limit: 20, sort: 'pretty_name' }),
    hydrate: (ids: string[]) => adminClient.categories.list({ id_in: ids, limit: ids.length }),
    getOptionLabel: (c: Category) => c.pretty_name ?? c.name ?? c.id,
    placeholder: i18n.t('admin.products.category_search_placeholder'),
    emptyText: i18n.t('admin.products.no_categories_found'),
  }
}

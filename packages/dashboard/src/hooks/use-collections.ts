import type { Collection, CollectionCreateParams, CollectionUpdateParams } from '@spree/admin-sdk'
import {
  adminClient,
  useResourceKey,
  useResourceKeyBuilder,
  useResourceMutation,
} from '@spree/dashboard-core'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import i18n from 'i18next'

export function useCollections() {
  return useQuery({
    queryKey: useResourceKey('collections'),
    queryFn: () => adminClient.collections.list({ limit: 100, sort: 'position' }),
    staleTime: 1000 * 60 * 5,
  })
}

// The rule-kind registry is static at runtime — cache forever, not store-scoped.
export function useCollectionRuleTypes() {
  return useQuery({
    queryKey: ['collection-rules', 'types'],
    queryFn: () => adminClient.collectionRules.types(),
    staleTime: Number.POSITIVE_INFINITY,
  })
}

export function useCollection(id: string | undefined) {
  return useQuery({
    queryKey: useResourceKey('collections', id ?? 'noop'),
    // `rules` is expand-gated server-side; the edit form hydrates its rule
    // editor from it, so the detail read has to ask for it explicitly.
    queryFn: () =>
      adminClient.collections.get(id as string, { expand: ['rules', 'custom_fields'] }),
    enabled: !!id,
  })
}

export function useCreateCollection() {
  return useResourceMutation<Collection, Error, CollectionCreateParams>({
    mutationFn: (params) => adminClient.collections.create(params),
    invalidate: [['collections']],
    successMessage: i18n.t('admin.collections.messages.created'),
    errorMessage: i18n.t('admin.errors.failed_to_create'),
  })
}

export function useUpdateCollection(id: string) {
  return useResourceMutation<Collection, Error, CollectionUpdateParams>({
    mutationFn: (params) => adminClient.collections.update(id, params),
    // The nested products list is held back: it prefix-matches
    // `['collections', id]`, and this update runs before the membership flush
    // inside the page's Save — refreshing it there paints the pre-save rows
    // for a frame. The flush refreshes it once, at the end.
    invalidate: [['collections'], ['collections', id]],
    doNotInvalidate: ['products'],
    successMessage: i18n.t('admin.collections.messages.updated'),
    errorMessage: i18n.t('admin.errors.failed_to_update'),
  })
}

/**
 * Reorder a collection among its siblings. Collections are a flat
 * `acts_as_list`, so this is a plain `position` update rather than a
 * dedicated reposition endpoint.
 */
export function useRepositionCollection() {
  return useResourceMutation<Collection, Error, { id: string; position: number }>({
    mutationFn: ({ id, position }) => adminClient.collections.update(id, { position }),
    invalidate: [['collections']],
    errorMessage: i18n.t('admin.collections.messages.move_failed'),
  })
}

export function useDeleteCollection() {
  const queryClient = useQueryClient()
  const buildKey = useResourceKeyBuilder()

  return useResourceMutation<void, Error, string>({
    mutationFn: (id) => adminClient.collections.delete(id),
    invalidate: [['collections']],
    successMessage: i18n.t('admin.collections.messages.deleted'),
    errorMessage: i18n.t('admin.errors.failed_to_delete'),
    onSuccess: (_data, id) => {
      queryClient.removeQueries({ queryKey: buildKey('collections', id) })
    },
  })
}

// ---------------------------------------------------------------------------
// Products within a collection (manual membership + ordering)
// ---------------------------------------------------------------------------

const collectionProductsKey = (collectionId: string) =>
  ['collections', collectionId, 'products'] as const

/**
 * One page of a collection's products, ordered by membership position. Works
 * for automatic collections too — there the list is materialized from the
 * rules and is read-only.
 *
 * Paginated rather than capped: a collection can hold thousands of products,
 * and a single truncated fetch would hide the rest with no way to reach them.
 */
export function useCollectionProducts(collectionId: string | undefined, page = 1, limit = 25) {
  return useQuery({
    queryKey: useResourceKey('collections', collectionId ?? 'noop', 'products', `${page}:${limit}`),
    queryFn: () => listCollectionProductsPage(collectionId as string, page, limit),
    enabled: !!collectionId,
    // Keep the current page visible while the next one loads, so the table
    // doesn't blank out between pages.
    placeholderData: (previous) => previous,
  })
}

/** Paginated collection membership fetch for picker exclusion. */
export function listCollectionProductsPage(collectionId: string, page: number, limit = 100) {
  return adminClient.collections.products.list(collectionId, { page, limit })
}

/** Add one or many products to a manual collection in a single request. */
export function useAddCollectionProducts(collectionId: string) {
  return useResourceMutation<unknown, Error, string[]>({
    mutationFn: (productIds) => adminClient.collections.products.create(collectionId, productIds),
    // No invalidate: this runs inside the page's Save, and the parent's own
    // update mutation already invalidates `['collections']`, which prefix-matches
    // the products list. Invalidating here too refetches mid-flush — once
    // before the membership is written — which renders the pre-save list for a
    // frame before the final state lands.
    // Silent: this runs inside the page's Save, whose own mutation reports
    // the outcome — a second toast per flush would stack on it.
    successMessage: false,
    errorMessage: i18n.t('admin.errors.failed_to_update'),
  })
}

/** Remove many products from a collection in one request. */
export function useRemoveCollectionProducts(collectionId: string) {
  return useResourceMutation<unknown, Error, string[]>({
    mutationFn: (productIds) => adminClient.collections.products.delete(collectionId, productIds),
    // No invalidate: this runs inside the page's Save, and the parent's own
    // update mutation already invalidates `['collections']`, which prefix-matches
    // the products list. Invalidating here too refetches mid-flush — once
    // before the membership is written — which renders the pre-save list for a
    // frame before the final state lands.
    // Silent: this runs inside the page's Save, whose own mutation reports
    // the outcome — a second toast per flush would stack on it.
    successMessage: false,
    errorMessage: i18n.t('admin.errors.failed_to_update'),
  })
}

export function useRepositionCollectionProduct(collectionId: string) {
  return useResourceMutation<void, Error, { productId: string; new_position: number }>({
    mutationFn: ({ productId, new_position }) =>
      adminClient.collections.products.reposition(collectionId, productId, { new_position }),
    invalidate: [collectionProductsKey(collectionId)],
    errorMessage: i18n.t('admin.collections.messages.move_failed'),
  })
}

/**
 * Shared config for any `<ResourceMultiAutocomplete>` picking collections
 * (product edit page, bulk-action dialog). Pass a unique `queryKey` per
 * instance so independent caches don't collide.
 *
 * Only manual collections are offered: automatic membership is rebuilt from
 * rules, so a hand-picked add would be dropped on the next regeneration.
 */
export function collectionAutocompleteProps(queryKey: string) {
  return {
    queryKey,
    search: (q: string) =>
      adminClient.collections.list({
        name_cont: q,
        automatic_eq: false,
        limit: 100,
        sort: 'name',
        fields: ['name'],
      }),
    hydrate: (ids: string[]) => adminClient.collections.list({ id_in: ids, limit: ids.length }),
    getOptionLabel: (c: Collection) => c.name ?? c.id,
    placeholder: i18n.t('admin.products.collection_search_placeholder'),
    emptyText: i18n.t('admin.products.no_collections_found'),
  }
}

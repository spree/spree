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
    queryFn: () => adminClient.collections.get(id as string, { expand: ['custom_fields'] }),
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
    invalidate: [['collections'], ['collections', id]],
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
 * Products in a collection, ordered by membership position. Works for
 * automatic collections too — there the list is materialized from the rules
 * and is read-only.
 */
export function useCollectionProducts(collectionId: string | undefined) {
  return useQuery({
    queryKey: useResourceKey('collections', collectionId ?? 'noop', 'products'),
    queryFn: () => adminClient.collections.products.list(collectionId as string, { limit: 100 }),
    enabled: !!collectionId,
  })
}

/** Add one or many products to a manual collection in a single request. */
export function useAddCollectionProducts(collectionId: string) {
  return useResourceMutation<unknown, Error, string[]>({
    mutationFn: (productIds) =>
      adminClient.products.bulkAddToCollections({
        ids: productIds,
        collection_ids: [collectionId],
      }),
    invalidate: [collectionProductsKey(collectionId), ['collections']],
    errorMessage: i18n.t('admin.errors.failed_to_update'),
  })
}

export function useRemoveCollectionProduct(collectionId: string) {
  return useResourceMutation<void, Error, string>({
    mutationFn: (productId) => adminClient.collections.products.remove(collectionId, productId),
    invalidate: [collectionProductsKey(collectionId), ['collections']],
    errorMessage: i18n.t('admin.errors.failed_to_update'),
  })
}

/** Remove many products from a collection in one request. */
export function useRemoveCollectionProducts(collectionId: string) {
  return useResourceMutation<unknown, Error, string[]>({
    mutationFn: (productIds) =>
      adminClient.products.bulkRemoveFromCollections({
        ids: productIds,
        collection_ids: [collectionId],
      }),
    invalidate: [collectionProductsKey(collectionId), ['collections']],
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
        limit: 20,
        sort: 'name',
      }),
    hydrate: (ids: string[]) => adminClient.collections.list({ id_in: ids, limit: ids.length }),
    getOptionLabel: (c: Collection) => c.name ?? c.id,
    placeholder: i18n.t('admin.products.collection_search_placeholder'),
    emptyText: i18n.t('admin.products.no_collections_found'),
  }
}

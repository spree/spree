import { zodResolver } from '@hookform/resolvers/zod'
import type { Collection, CollectionCreateParams, CollectionUpdateParams } from '@spree/admin-sdk'
import {
  adminClient,
  useResourceKey,
  useResourceKeyBuilder,
  useResourceMutation,
} from '@spree/dashboard-core'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import i18n from 'i18next'
import { useCallback, useRef } from 'react'
import type { Resolver } from 'react-hook-form'
import { type CollectionFormValues, collectionFormSchema } from '../schemas/collection'
import { TRANSLATIONS_QUERY_RESOURCE, useInvalidateTranslations } from './use-translations'

export function useCollections() {
  return useQuery({
    queryKey: useResourceKey('collections'),
    queryFn: () => adminClient.collections.list({ limit: 100, sort: 'position' }),
    staleTime: 1000 * 60 * 5,
  })
}

/**
 * The collection form's resolver. Which rule types take no value is a fact
 * of the types endpoint, read at validation time so a resolver created before
 * the types load still sees them.
 */
export function useCollectionFormResolver(): Resolver<CollectionFormValues> {
  const { data } = useCollectionRuleTypes()
  const valuelessTypes = useRef<string[]>([])
  valuelessTypes.current = (data?.data ?? [])
    .filter((ruleType) => (ruleType as { value_required?: boolean }).value_required === false)
    .map((ruleType) => ruleType.type)

  return useCallback<Resolver<CollectionFormValues>>(
    (values, context, options) =>
      zodResolver(collectionFormSchema(valuelessTypes.current))(values, context, options),
    [],
  )
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
    // `rules` and `publications` are expand-gated server-side; the edit form
    // hydrates its rule editor and Publishing card from them.
    queryFn: () =>
      adminClient.collections.get(id as string, {
        expand: ['rules', 'publications', 'custom_fields'],
      }),
    enabled: !!id,
  })
}

export function useCreateCollection() {
  const invalidateTranslations = useInvalidateTranslations()

  return useResourceMutation<Collection, Error, CollectionCreateParams>({
    mutationFn: (params) => adminClient.collections.create(params),
    invalidate: [['collections'], [TRANSLATIONS_QUERY_RESOURCE]],
    successMessage: i18n.t('admin.collections.messages.created'),
    errorMessage: i18n.t('admin.errors.failed_to_create'),
    onSuccess: () => invalidateTranslations(),
  })
}

export function useUpdateCollection(id: string) {
  const invalidateTranslations = useInvalidateTranslations()

  return useResourceMutation<Collection, Error, CollectionUpdateParams>({
    mutationFn: (params) => adminClient.collections.update(id, params),
    // The nested products list is held back: it prefix-matches
    // `['collections', id]`, and this update runs before the membership flush
    // inside the page's Save — refreshing it there paints the pre-save rows
    // for a frame. The flush refreshes it once, at the end.
    invalidate: [['collections'], ['collections', id], [TRANSLATIONS_QUERY_RESOURCE]],
    doNotInvalidate: ['products'],
    successMessage: i18n.t('admin.collections.messages.updated'),
    errorMessage: i18n.t('admin.errors.failed_to_update'),
    onSuccess: () => invalidateTranslations(),
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
  const invalidateTranslations = useInvalidateTranslations()

  return useResourceMutation<void, Error, string>({
    mutationFn: (id) => adminClient.collections.delete(id),
    invalidate: [['collections'], [TRANSLATIONS_QUERY_RESOURCE]],
    successMessage: i18n.t('admin.collections.messages.deleted'),
    errorMessage: i18n.t('admin.errors.failed_to_delete'),
    onSuccess: (_data, id) => {
      queryClient.removeQueries({ queryKey: buildKey('collections', id) })
      invalidateTranslations()
    },
  })
}

// ---------------------------------------------------------------------------
// Products within a collection (manual membership + ordering)
// ---------------------------------------------------------------------------

const collectionProductsKey = (collectionId: string) =>
  ['collections', collectionId, 'products'] as const

/**
 * One page of a collection's products, ordered by membership position:
 * rule-matched and hand-picked members alike.
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

/** Hand-pick one or many products into a collection in a single request. */
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
 * Every collection is offered: hand-picked membership survives regeneration
 * whether or not the collection also has rules.
 */
export function collectionAutocompleteProps(queryKey: string) {
  return {
    queryKey,
    search: (q: string) =>
      adminClient.collections.list({
        search: q,
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

// ---------------------------------------------------------------------------
// Exclusions — products kept out whatever the rules match
// ---------------------------------------------------------------------------

export function useCollectionExclusions(collectionId: string, page = 1, limit = 25) {
  return useQuery({
    queryKey: useResourceKey('collections', collectionId, 'exclusions', `${page}:${limit}`),
    queryFn: () =>
      adminClient.collections.exclusions.list(collectionId, { page, limit, expand: ['product'] }),
    placeholderData: (previous) => previous,
  })
}

/** Exclude a product: it leaves the collection now and stays out. */
export function useExcludeCollectionProduct(collectionId: string) {
  return useResourceMutation<unknown, Error, string>({
    mutationFn: (productId) =>
      adminClient.collections.exclusions.create(collectionId, { product_id: productId }),
    invalidate: [['collections', collectionId]],
    successMessage: i18n.t('admin.collections.exclusions.messages.excluded'),
    errorMessage: i18n.t('admin.errors.failed_to_update'),
  })
}

/** Lift an exclusion: the product comes back if the rules match it. */
export function useRemoveCollectionExclusion(collectionId: string) {
  return useResourceMutation<void, Error, string>({
    mutationFn: (exclusionId) =>
      adminClient.collections.exclusions.delete(collectionId, exclusionId),
    invalidate: [['collections', collectionId]],
    successMessage: i18n.t('admin.collections.exclusions.messages.removed'),
    errorMessage: i18n.t('admin.errors.failed_to_update'),
  })
}

import type {
  Category,
  CategoryCreateParams,
  CategoryRepositionParams,
  CategoryUpdateParams,
} from '@spree/admin-sdk'
import {
  adminClient,
  useResourceKey,
  useResourceKeyBuilder,
  useResourceMutation,
} from '@spree/dashboard-core'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import i18n from 'i18next'

export function useCategories() {
  return useQuery({
    queryKey: useResourceKey('categories'),
    queryFn: () => adminClient.categories.list({ limit: 100 }),
    staleTime: 1000 * 60 * 5,
  })
}

/** Flat name search — used by the search mode of the categories page. */
export function useCategorySearch(query: string) {
  const trimmed = query.trim()
  return useQuery({
    queryKey: useResourceKey('categories', 'search', trimmed),
    queryFn: () =>
      adminClient.categories.list({ name_cont: trimmed, limit: 50, sort: 'pretty_name' }),
    enabled: trimmed.length > 0,
    staleTime: 1000 * 60,
  })
}

export function useCategory(id: string | undefined) {
  return useQuery({
    queryKey: useResourceKey('categories', id ?? 'noop'),
    queryFn: () => adminClient.categories.get(id as string),
    enabled: !!id,
  })
}

export function useCreateCategory() {
  return useResourceMutation<Category, Error, CategoryCreateParams>({
    mutationFn: (params) => adminClient.categories.create(params),
    invalidate: [['categories']],
    successMessage: i18n.t('admin.categories.messages.created'),
    errorMessage: i18n.t('admin.errors.failed_to_create'),
  })
}

export function useUpdateCategory(id: string) {
  return useResourceMutation<Category, Error, CategoryUpdateParams>({
    mutationFn: (params) => adminClient.categories.update(id, params),
    invalidate: [['categories'], ['categories', id]],
    successMessage: i18n.t('admin.categories.messages.updated'),
    errorMessage: i18n.t('admin.errors.failed_to_update'),
  })
}

export function useRepositionCategory() {
  return useResourceMutation<Category, Error, { id: string } & CategoryRepositionParams>({
    mutationFn: ({ id, ...params }) => adminClient.categories.reposition(id, params),
    invalidate: [['categories']],
    errorMessage: i18n.t('admin.categories.messages.move_failed'),
  })
}

export function useDeleteCategory() {
  const queryClient = useQueryClient()
  const buildKey = useResourceKeyBuilder()

  return useResourceMutation<void, Error, string>({
    mutationFn: (id) => adminClient.categories.delete(id),
    invalidate: [['categories']],
    successMessage: i18n.t('admin.categories.messages.deleted'),
    errorMessage: i18n.t('admin.errors.failed_to_delete'),
    onSuccess: (_data, id) => {
      queryClient.removeQueries({ queryKey: buildKey('categories', id) })
    },
  })
}

// ---------------------------------------------------------------------------
// Products within a category (manual membership + ordering)
// ---------------------------------------------------------------------------

const categoryProductsKey = (categoryId: string) => ['categories', categoryId, 'products'] as const

/** Products classified under a category, ordered by classification position. */
export function useCategoryProducts(categoryId: string | undefined) {
  return useQuery({
    queryKey: useResourceKey('categories', categoryId ?? 'noop', 'products'),
    queryFn: () => adminClient.categories.products.list(categoryId as string, { limit: 100 }),
    enabled: !!categoryId,
  })
}

/** Add one or many products to a category in a single request. */
export function useAddCategoryProducts(categoryId: string) {
  return useResourceMutation<unknown, Error, string[]>({
    mutationFn: (productIds) =>
      adminClient.products.bulkAddToCategories({ ids: productIds, category_ids: [categoryId] }),
    invalidate: [categoryProductsKey(categoryId), ['categories']],
    errorMessage: i18n.t('admin.errors.failed_to_update'),
  })
}

export function useRemoveCategoryProduct(categoryId: string) {
  return useResourceMutation<void, Error, string>({
    mutationFn: (productId) => adminClient.categories.products.remove(categoryId, productId),
    invalidate: [categoryProductsKey(categoryId), ['categories']],
    errorMessage: i18n.t('admin.errors.failed_to_update'),
  })
}

/**
 * Remove many products from a category in one request. Reuses the existing
 * products bulk endpoint (the same one the product-list bulk actions use) —
 * no category-specific bulk route needed.
 */
export function useRemoveCategoryProducts(categoryId: string) {
  return useResourceMutation<unknown, Error, string[]>({
    mutationFn: (productIds) =>
      adminClient.products.bulkRemoveFromCategories({
        ids: productIds,
        category_ids: [categoryId],
      }),
    invalidate: [categoryProductsKey(categoryId), ['categories']],
    errorMessage: i18n.t('admin.errors.failed_to_update'),
  })
}

export function useRepositionCategoryProduct(categoryId: string) {
  return useResourceMutation<void, Error, { productId: string; new_position: number }>({
    mutationFn: ({ productId, new_position }) =>
      adminClient.categories.products.reposition(categoryId, productId, { new_position }),
    invalidate: [categoryProductsKey(categoryId)],
    errorMessage: i18n.t('admin.categories.messages.move_failed'),
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
      adminClient.categories.list({ pretty_name_cont: q, limit: 20, sort: 'pretty_name' }),
    hydrate: (ids: string[]) => adminClient.categories.list({ id_in: ids, limit: ids.length }),
    getOptionLabel: (c: Category) => c.pretty_name ?? c.name ?? c.id,
    placeholder: i18n.t('admin.products.category_search_placeholder'),
    emptyText: i18n.t('admin.products.no_categories_found'),
  }
}

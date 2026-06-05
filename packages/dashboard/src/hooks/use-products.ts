import type { FilterRule } from '@spree/dashboard-core'
import { adminClient, useResourceKey, useResourceMutation } from '@spree/dashboard-core'
import { useQuery } from '@tanstack/react-query'
import i18n from 'i18next'

interface UseProductsParams {
  page?: number
  limit?: number
  sort?: string
  search?: string
  filters?: FilterRule[]
}

export function useProducts({
  page = 1,
  limit = 25,
  sort = '-updated_at',
  search,
  filters = [],
}: UseProductsParams = {}) {
  return useQuery({
    queryKey: useResourceKey('products', { page, limit, sort, search, filters }),
    queryFn: async () => {
      const params: Record<string, unknown> = { page, limit, sort }

      if (search) {
        params.name_cont = search
      }

      // Convert FilterRule[] to Ransack params
      for (const filter of filters) {
        const key = `${filter.field}_${filter.operator}`
        params[key] = filter.value
      }

      return adminClient.products.list(params)
    },
  })
}

// BulkActionBar renders its own count-aware toasts via `successMessage`/
// `errorMessage` on each action, so these hooks opt out of the wrapper's
// default toast. The shared `useBulkProductMutation` keeps the opt-out in
// one place.

type BulkStatusParams = Parameters<typeof adminClient.products.bulkStatusUpdate>[0]
type BulkCategoriesParams = Parameters<typeof adminClient.products.bulkAddToCategories>[0]
type BulkChannelsParams = Parameters<typeof adminClient.products.bulkAddToChannels>[0]
type BulkTagsParams = Parameters<typeof adminClient.products.bulkAddTags>[0]
type BulkDestroyParams = Parameters<typeof adminClient.products.bulkDestroy>[0]

function useBulkProductMutation<TData, TVariables>(
  mutationFn: (params: TVariables) => Promise<TData>,
) {
  return useResourceMutation<TData, Error, TVariables>({
    mutationFn,
    successMessage: false,
    errorMessage: false,
  })
}

export function useBulkProductStatusUpdate() {
  return useBulkProductMutation((p: BulkStatusParams) => adminClient.products.bulkStatusUpdate(p))
}

export function useBulkAddProductsToCategories() {
  return useBulkProductMutation((p: BulkCategoriesParams) =>
    adminClient.products.bulkAddToCategories(p),
  )
}

export function useBulkRemoveProductsFromCategories() {
  return useBulkProductMutation((p: BulkCategoriesParams) =>
    adminClient.products.bulkRemoveFromCategories(p),
  )
}

export function useBulkAddProductsToChannels() {
  return useBulkProductMutation((p: BulkChannelsParams) =>
    adminClient.products.bulkAddToChannels(p),
  )
}

export function useBulkRemoveProductsFromChannels() {
  return useBulkProductMutation((p: BulkChannelsParams) =>
    adminClient.products.bulkRemoveFromChannels(p),
  )
}

export function useBulkAddProductTags() {
  return useBulkProductMutation((p: BulkTagsParams) => adminClient.products.bulkAddTags(p))
}

export function useBulkRemoveProductTags() {
  return useBulkProductMutation((p: BulkTagsParams) => adminClient.products.bulkRemoveTags(p))
}

export function useBulkDestroyProducts() {
  return useBulkProductMutation((p: BulkDestroyParams) => adminClient.products.bulkDestroy(p))
}

// Single-row clone — drives the row-action menu's "Duplicate" item. The
// wrapper toasts on success and on non-422 failures, so the call site only
// needs the resulting product to navigate to.
export function useCloneProduct() {
  return useResourceMutation({
    mutationFn: (id: string) => adminClient.products.clone(id),
    invalidate: [['products']],
    successMessage: i18n.t('admin.pages.products.clone_succeeded'),
    errorMessage: i18n.t('admin.pages.products.clone_failed'),
  })
}

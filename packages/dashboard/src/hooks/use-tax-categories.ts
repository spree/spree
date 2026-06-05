import type {
  TaxCategory,
  TaxCategoryCreateParams,
  TaxCategoryUpdateParams,
} from '@spree/admin-sdk'
import {
  adminClient,
  useResourceKey,
  useResourceKeyBuilder,
  useResourceMutation,
} from '@spree/dashboard-core'
import { useQuery, useQueryClient } from '@tanstack/react-query'

interface UseTaxCategoriesParams {
  page?: number
  limit?: number
}

export function useTaxCategories({ page = 1, limit = 100 }: UseTaxCategoriesParams = {}) {
  return useQuery({
    queryKey: useResourceKey('tax-categories', { page, limit }),
    queryFn: () => adminClient.taxCategories.list({ page, limit }),
    staleTime: 1000 * 60 * 5,
  })
}

export function useTaxCategory(id: string | undefined) {
  return useQuery({
    queryKey: useResourceKey('tax-categories', id ?? 'noop'),
    queryFn: () => adminClient.taxCategories.get(id as string),
    enabled: !!id,
  })
}

export function useCreateTaxCategory() {
  return useResourceMutation<TaxCategory, Error, TaxCategoryCreateParams>({
    mutationFn: (params) => adminClient.taxCategories.create(params),
    invalidate: [['tax-categories']],
    successMessage: 'Tax category created',
    errorMessage: 'Failed to create tax category',
  })
}

export function useUpdateTaxCategory(id: string) {
  return useResourceMutation<TaxCategory, Error, TaxCategoryUpdateParams>({
    mutationFn: (params) => adminClient.taxCategories.update(id, params),
    invalidate: [['tax-categories'], ['tax-categories', id]],
    successMessage: 'Tax category updated',
    errorMessage: 'Failed to update tax category',
  })
}

export function useDeleteTaxCategory() {
  const queryClient = useQueryClient()
  const buildKey = useResourceKeyBuilder()

  return useResourceMutation<void, Error, string>({
    mutationFn: (id) => adminClient.taxCategories.delete(id),
    invalidate: [['tax-categories']],
    successMessage: 'Tax category deleted',
    errorMessage: 'Failed to delete tax category',
    onSuccess: (_data, id) => {
      queryClient.removeQueries({ queryKey: buildKey('tax-categories', id) })
    },
  })
}
